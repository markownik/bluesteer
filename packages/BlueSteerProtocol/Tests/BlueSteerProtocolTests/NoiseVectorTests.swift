import XCTest
@testable import BlueSteerProtocol

/// Runs the cacophony vectors in protocol/testvectors/noise through both an
/// initiator and a responder and checks every ciphertext and the handshake hash.
final class NoiseVectorTests: XCTestCase {
    struct Vector: Decodable {
        struct Message: Decodable { let payload: String; let ciphertext: String }
        let protocol_name: String
        let init_prologue: String
        let init_static: String
        let init_ephemeral: String
        let init_psks: [String]?
        let resp_prologue: String
        let resp_static: String
        let resp_ephemeral: String
        let resp_psks: [String]?
        let handshake_hash: String
        let messages: [Message]
    }

    private func load(_ name: String) throws -> Vector {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("protocol/testvectors/noise/\(name).json")
        return try JSONDecoder().decode(Vector.self, from: Data(contentsOf: url))
    }

    private func hex(_ s: String) -> Data {
        var d = Data(); var i = s.startIndex
        while i < s.endIndex { let j = s.index(i, offsetBy: 2); d.append(UInt8(s[i..<j], radix: 16)!); i = j }
        return d
    }

    private func run(_ pattern: NoisePattern) throws {
        let v = try load(pattern.rawValue)
        var initiator = try NoiseHandshake(pattern: pattern, initiator: true, prologue: hex(v.init_prologue),
                                           staticKey: NoiseKeyPair(privateKey: hex(v.init_static)),
                                           psk: v.init_psks?.first.map(hex),
                                           ephemeral: NoiseKeyPair(privateKey: hex(v.init_ephemeral)))
        var responder = try NoiseHandshake(pattern: pattern, initiator: false, prologue: hex(v.resp_prologue),
                                           staticKey: NoiseKeyPair(privateKey: hex(v.resp_static)),
                                           psk: v.resp_psks?.first.map(hex),
                                           ephemeral: NoiseKeyPair(privateKey: hex(v.resp_ephemeral)))
        let handshakeCount = pattern.messages.count
        for (i, m) in v.messages.prefix(handshakeCount).enumerated() {
            let payload = hex(m.payload)
            let (ciphertext, received): (Data, Data) = i % 2 == 0
                ? (try initiator.writeMessage(payload: payload), try responder.readMessage(hex(m.ciphertext)))
                : (try responder.writeMessage(payload: payload), try initiator.readMessage(hex(m.ciphertext)))
            XCTAssertEqual(ciphertext, hex(m.ciphertext), "\(pattern) handshake message \(i)")
            XCTAssertEqual(received, payload, "\(pattern) payload \(i)")
        }
        XCTAssertTrue(initiator.isComplete && responder.isComplete)
        XCTAssertEqual(initiator.handshakeHash, hex(v.handshake_hash))
        XCTAssertEqual(responder.handshakeHash, hex(v.handshake_hash))
        XCTAssertEqual(initiator.remoteStatic, try NoiseKeyPair(privateKey: hex(v.resp_static)).publicKey)
        XCTAssertEqual(responder.remoteStatic, try NoiseKeyPair(privateKey: hex(v.init_static)).publicKey)

        var (iSend, iRecv) = try initiator.split()
        var (rSend, rRecv) = try responder.split()
        // Senders keep alternating after the handshake, so parity uses the overall index.
        for (i, m) in v.messages.dropFirst(handshakeCount).enumerated() {
            let payload = hex(m.payload)
            if (handshakeCount + i) % 2 == 0 {
                XCTAssertEqual(try iSend.encrypt(plaintext: payload), hex(m.ciphertext), "\(pattern) transport \(i)")
                XCTAssertEqual(try rRecv.decrypt(ciphertext: hex(m.ciphertext)), payload)
            } else {
                XCTAssertEqual(try rSend.encrypt(plaintext: payload), hex(m.ciphertext), "\(pattern) transport \(i)")
                XCTAssertEqual(try iRecv.decrypt(ciphertext: hex(m.ciphertext)), payload)
            }
        }
    }

    func testXX() throws { try run(.xx) }
    func testXXpsk3() throws { try run(.xxpsk3) }

    func testWrongPSKFails() throws {
        let prologue = Data("bluesteer/1".utf8)
        let psk = Data(repeating: 7, count: 32)
        var badPSK = psk; badPSK[0] = 8
        var i = try NoiseHandshake(pattern: .xxpsk3, initiator: true, prologue: prologue, staticKey: NoiseKeyPair(), psk: psk)
        var r = try NoiseHandshake(pattern: .xxpsk3, initiator: false, prologue: prologue, staticKey: NoiseKeyPair(), psk: badPSK)
        _ = try r.readMessage(try i.writeMessage())
        _ = try i.readMessage(try r.writeMessage())
        XCTAssertThrowsError(try r.readMessage(try i.writeMessage())) { XCTAssertEqual($0 as? NoiseError, .decryptionFailed) }
    }

    func testTamperedTransportMessageFails() throws {
        var i = try NoiseHandshake(pattern: .xx, initiator: true, prologue: Data(), staticKey: NoiseKeyPair())
        var r = try NoiseHandshake(pattern: .xx, initiator: false, prologue: Data(), staticKey: NoiseKeyPair())
        _ = try r.readMessage(try i.writeMessage())
        _ = try i.readMessage(try r.writeMessage())
        _ = try r.readMessage(try i.writeMessage())
        var (send, _) = try i.split()
        var (_, recv) = try r.split()
        var c = try send.encrypt(plaintext: Data("hi".utf8))
        c[0] ^= 1
        XCTAssertThrowsError(try recv.decrypt(ciphertext: c))
    }
}
