import XCTest
@testable import BlueSteerProtocol

final class SecureChannelTests: XCTestCase {
    /// Runs a full handshake between two channels, delivering bytes in `chunk`-sized pieces.
    private func connect(_ remote: SecureChannel, _ host: SecureChannel, chunk: Int = 7) throws -> (Data, Data) {
        var toHost = try remote.start()
        var toRemote = Data()
        var remoteKey: Data?, hostKey: Data?
        for _ in 0..<4 {
            for e in try deliver(toHost, to: host, chunk: chunk) {
                if case .send(let d) = e { toRemote.append(d) }
                if case .established(let k) = e { remoteKey = k }
            }
            toHost = Data()
            for e in try deliver(toRemote, to: remote, chunk: chunk) {
                if case .send(let d) = e { toHost.append(d) }
                if case .established(let k) = e { hostKey = k }
            }
            toRemote = Data()
            if remoteKey != nil && hostKey != nil { break }
        }
        return (try XCTUnwrap(remoteKey), try XCTUnwrap(hostKey))
    }

    private func deliver(_ data: Data, to channel: SecureChannel, chunk: Int) throws -> [SecureChannel.Event] {
        var events: [SecureChannel.Event] = []
        var i = 0
        while i < data.count {
            events += try channel.receive(data[i..<min(i + chunk, data.count)])
            i += chunk
        }
        return events
    }

    func testPairingThenReconnect() throws {
        let hostKey = NoiseKeyPair(), remoteKey = NoiseKeyPair()
        let psk = Data((0..<32).map { _ in UInt8.random(in: 0...255) })

        // Pairing with the PSK from the QR code.
        let host = try SecureChannel(role: .host(pairedKeys: [], pairingPSK: psk), staticKey: hostKey)
        let remote = try SecureChannel(role: .remote(pinnedHostKey: nil, pairingPSK: psk), staticKey: remoteKey)
        let (seenRemote, seenHost) = try connect(remote, host)
        XCTAssertEqual(seenRemote, remoteKey.publicKey)
        XCTAssertEqual(seenHost, hostKey.publicKey)

        // Application traffic both ways, chunked.
        let c1 = try remote.encrypt(Data("ping".utf8))
        XCTAssertEqual(try deliver(c1, to: host, chunk: 3), [.message(Data("ping".utf8))])
        let c2 = try host.encrypt(Data("pong".utf8))
        XCTAssertEqual(try deliver(c2, to: remote, chunk: 5), [.message(Data("pong".utf8))])

        // Reconnect with pinned keys and no PSK.
        let host2 = try SecureChannel(role: .host(pairedKeys: [remoteKey.publicKey], pairingPSK: nil), staticKey: hostKey)
        let remote2 = try SecureChannel(role: .remote(pinnedHostKey: hostKey.publicKey, pairingPSK: nil), staticKey: remoteKey)
        _ = try connect(remote2, host2, chunk: 64)
        XCTAssertTrue(host2.isEstablished && remote2.isEstablished)
    }

    func testUnknownRemoteIsRejected() throws {
        let host = try SecureChannel(role: .host(pairedKeys: [NoiseKeyPair().publicKey], pairingPSK: nil), staticKey: NoiseKeyPair())
        let remote = try SecureChannel(role: .remote(pinnedHostKey: nil, pairingPSK: nil), staticKey: NoiseKeyPair())
        XCTAssertThrowsError(try connect(remote, host)) { XCTAssertEqual($0 as? SecureChannel.Error, .unknownRemote) }
    }

    func testHostKeyMismatchIsRejected() throws {
        let host = try SecureChannel(role: .host(pairedKeys: [], pairingPSK: nil), staticKey: NoiseKeyPair())
        let remote = try SecureChannel(role: .remote(pinnedHostKey: NoiseKeyPair().publicKey, pairingPSK: nil), staticKey: NoiseKeyPair())
        XCTAssertThrowsError(try connect(remote, host)) { XCTAssertEqual($0 as? SecureChannel.Error, .hostKeyMismatch) }
    }

    func testWrongPairingPSKFails() throws {
        let host = try SecureChannel(role: .host(pairedKeys: [], pairingPSK: Data(repeating: 1, count: 32)), staticKey: NoiseKeyPair())
        let remote = try SecureChannel(role: .remote(pinnedHostKey: nil, pairingPSK: Data(repeating: 2, count: 32)), staticKey: NoiseKeyPair())
        XCTAssertThrowsError(try connect(remote, host))
    }

    func testOversizedMessageLeavesTheNonceUnchanged() throws {
        let hostKey = NoiseKeyPair(), remoteKey = NoiseKeyPair()
        let host = try SecureChannel(role: .host(pairedKeys: [remoteKey.publicKey], pairingPSK: nil), staticKey: hostKey)
        let remote = try SecureChannel(role: .remote(pinnedHostKey: hostKey.publicKey, pairingPSK: nil), staticKey: remoteKey)
        _ = try connect(remote, host)

        let tooBig = Data(count: SecureChannel.maxPlaintextLength + 1)
        XCTAssertThrowsError(try remote.encrypt(tooBig)) {
            XCTAssertEqual($0 as? SecureChannel.Error, .messageTooLarge(tooBig.count))
        }
        // The largest allowed message and a small one after it still decrypt in order.
        let largest = Data(repeating: 7, count: SecureChannel.maxPlaintextLength)
        XCTAssertEqual(try deliver(try remote.encrypt(largest), to: host, chunk: 512), [.message(largest)])
        XCTAssertEqual(try deliver(try remote.encrypt(Data("after".utf8)), to: host, chunk: 3), [.message(Data("after".utf8))])
    }

    func testEncryptBeforeEstablishedFails() throws {
        let remote = try SecureChannel(role: .remote(pinnedHostKey: nil, pairingPSK: nil), staticKey: NoiseKeyPair())
        XCTAssertThrowsError(try remote.encrypt(Data())) { XCTAssertEqual($0 as? SecureChannel.Error, .notEstablished) }
    }
}
