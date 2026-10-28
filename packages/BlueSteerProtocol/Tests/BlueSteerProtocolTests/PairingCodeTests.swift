import XCTest
@testable import BlueSteerProtocol

final class PairingCodeTests: XCTestCase {
    private struct Vectors: Decodable { struct V: Decodable { let handshake_hash: String; let code: String }; let vectors: [V] }

    func testCodesMatchVectors() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("protocol/testvectors/pairing-code.json")
        let vectors = try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url)).vectors
        XCTAssertFalse(vectors.isEmpty)
        for v in vectors {
            var h = Data(); var i = v.handshake_hash.startIndex
            while i < v.handshake_hash.endIndex { let j = v.handshake_hash.index(i, offsetBy: 2); h.append(UInt8(v.handshake_hash[i..<j], radix: 16)!); i = j }
            XCTAssertEqual(SecureChannel.pairingCode(handshakeHash: h), v.code)
        }
    }

    func testBothEndsDeriveTheSameCodeAndUnknownRemoteIsAcceptedWhenAsked() throws {
        let hostKey = NoiseKeyPair(), remoteKey = NoiseKeyPair()
        let host = try SecureChannel(role: .host(pairedKeys: [], pairingPSK: nil, acceptUnknownRemote: true), staticKey: hostKey)
        let remote = try SecureChannel(role: .remote(pinnedHostKey: nil, pairingPSK: nil), staticKey: remoteKey)
        var toHost = try remote.start()
        var toRemote = Data()
        for _ in 0..<3 {
            for e in try host.receive(toHost) { if case .send(let d) = e { toRemote.append(d) } }
            toHost = Data()
            for e in try remote.receive(toRemote) { if case .send(let d) = e { toHost.append(d) } }
            toRemote = Data()
        }
        XCTAssertTrue(host.isEstablished && remote.isEstablished)
        let h = try XCTUnwrap(host.handshakeHash)
        XCTAssertEqual(h, remote.handshakeHash)
        let code = SecureChannel.pairingCode(handshakeHash: h)
        XCTAssertEqual(code.count, 6)
        XCTAssertEqual(code, SecureChannel.pairingCode(handshakeHash: try XCTUnwrap(remote.handshakeHash)))
    }
}
