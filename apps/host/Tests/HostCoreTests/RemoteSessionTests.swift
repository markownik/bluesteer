import BlueSteerProtocol
import XCTest
@testable import HostCore
@testable import RemoteCore

/// Drives `RemoteSession` against the host's SecureChannel and SessionHub over
/// an in-memory pipe: what `bluesteer connect` does, without Bluetooth.
final class RemoteSessionTests: XCTestCase {
    /// One end of a pipe; deliveries hop through the main queue like BLE callbacks.
    final class PipeTransport: RemoteTransport {
        var onData: ((Data) -> Void)?
        var onClosed: (() -> Void)?
        var peer: ((Data) -> Void)?
        func write(_ data: Data) { DispatchQueue.main.async { self.peer?(data) } }
        func close() { DispatchQueue.main.async { self.onClosed?() } }
    }

    /// A minimal host: selector byte, SecureChannel, hub wiring for the messages the remote uses.
    final class MiniHost {
        let hub: SessionHub
        let link = UUID()
        var channel: SecureChannel?
        let key: NoiseKeyPair
        let store: Set<Data>
        let acceptUnknown: Bool
        var toRemote: ((Data) -> Void)?
        var pairingCode: String?
        var paired = false

        /// With its own hub by default; soak tests share one hub across many hosts.
        init(pairedKeys: Set<Data>, acceptUnknown: Bool, hub: SessionHub? = nil, key: NoiseKeyPair = NoiseKeyPair()) {
            store = pairedKeys
            self.acceptUnknown = acceptUnknown
            self.key = key
            self.hub = hub ?? SessionHub()
            if hub == nil {
                self.hub.pendingBytes = { _ in 0 }
                self.hub.send = { [weak self] env, _ in self?.send(env) }
            }
        }

        /// The central went away: the hub forgets this link's subscriptions.
        func close() {
            hub.linkClosed(link)
            channel = nil
            toRemote = nil
        }

        func receive(_ bytes: Data) throws {
            var bytes = bytes
            if channel == nil {
                let selector = bytes.removeFirst()
                let psk: Data? = nil
                channel = try SecureChannel(role: .host(pairedKeys: store, pairingPSK: psk, acceptUnknownRemote: selector == 0x03 && acceptUnknown), staticKey: key)
                if bytes.isEmpty { return }
            }
            for event in try channel!.receive(bytes) {
                switch event {
                case .send(let d): toRemote?(d)
                case .established:
                    if acceptUnknown, let h = channel!.handshakeHash { pairingCode = SecureChannel.pairingCode(handshakeHash: h) } else { hello() }
                case .message(let plain):
                    let env = try BSEnvelope(serializedBytes: plain)
                    switch env.body {
                    case .pairConfirm: paired = true; hello()
                    case .listSessions: send(BSEnvelope.with { $0.sessionList = hub.sessionList })
                    case .subscribe(let s): hub.subscribe(link: link, session: SessionID(rawValue: s.sessionID), rows: Int(s.rows), cols: Int(s.cols), scrollbackLines: Int(s.scrollbackLines))
                    case .termInput(let i): hub.input(i.data, session: SessionID(rawValue: i.sessionID))
                    default: break
                    }
                }
            }
        }

        func hello() { send(BSEnvelope.with { $0.hostHello = BSHostHello.with { $0.hostName = "mini"; $0.protocolVersion = protocolVersion } }) }
        func send(_ env: BSEnvelope) { if let c = channel, let d = try? c.encrypt(try env.serializedData()) { toRemote?(d) } }
    }

    private func pump(_ seconds: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
    private func waitUntil(_ timeout: TimeInterval = 5, _ cond: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end { if cond() { return true }; pump(0.05) }
        return cond()
    }

    func testPairedAttachSeesSnapshotAndEcho() throws {
        let remoteKey = NoiseKeyPair()
        let host = MiniHost(pairedKeys: [remoteKey.publicKey], acceptUnknown: false)
        let transport = PipeTransport()
        transport.peer = { try? host.receive($0) }
        host.toRemote = { d in transport.onData?(d) }
        let session = try RemoteSession(transport: transport, identity: remoteKey, deviceName: "test-mac", mode: .paired(hostKey: host.key.publicKey), queue: .main)
        var ready = false
        session.onReady = { ready = true }
        try session.start()
        XCTAssertTrue(waitUntil { ready }, "HostHello arrives after the paired handshake")
        XCTAssertEqual(session.hostHello?.hostName, "mini")

        // A shell-like session: prints a marker, then echoes what we type.
        let pty = try host.hub.start(command: ["/bin/sh", "-c", "echo marker-line; cat"], cwd: "/tmp", rows: 6, cols: 40)
        pump(0.3)
        var snapshot = Data()
        var output = Data()
        let inflater = InflateStream()
        session.onEnvelope = { e in
            switch e.body {
            case .termSnapshot(let s): snapshot = InflateStream.inflateAll(s.vt)
            case .termOutput(let o): output.append(inflater.push(o.data))
            default: break
            }
        }
        try session.send(BSEnvelope.with {
            $0.subscribe = BSSubscribe.with { $0.cmdID = 1; $0.sessionID = pty.id.rawValue; $0.rows = 6; $0.cols = 40; $0.scrollbackLines = 10 }
        })
        XCTAssertTrue(waitUntil { !snapshot.isEmpty })
        let screen = String(decoding: snapshot, as: UTF8.self)
        XCTAssertTrue(screen.contains("marker-line"), screen)

        try session.send(BSEnvelope.with { $0.termInput = BSTermInput.with { $0.sessionID = pty.id.rawValue; $0.data = Data("typed-here\n".utf8) } })
        XCTAssertTrue(waitUntil { String(decoding: output, as: UTF8.self).contains("typed-here") }, String(decoding: output, as: UTF8.self))
        pty.stop(signal: SIGKILL)
    }

    func testPairingByCodeMatchesAndCompletesOnConfirm() throws {
        let remoteKey = NoiseKeyPair()
        let host = MiniHost(pairedKeys: [], acceptUnknown: true)
        let transport = PipeTransport()
        transport.peer = { try? host.receive($0) }
        host.toRemote = { d in transport.onData?(d) }
        let session = try RemoteSession(transport: transport, identity: remoteKey, deviceName: "test-mac", mode: .code, queue: .main)
        var code: String?
        var ready = false
        session.onPairingCode = { code = $0 }
        session.onReady = { ready = true }
        try session.start()
        XCTAssertTrue(waitUntil { code != nil })
        XCTAssertEqual(code, host.pairingCode)
        XCTAssertFalse(ready, "no HostHello before both sides confirm")
        try session.confirmPairing()
        XCTAssertTrue(waitUntil { ready })
        XCTAssertTrue(host.paired)
        XCTAssertEqual(session.hostKey, host.key.publicKey)
    }

    func testUnknownRemoteIsRejectedWhenNotPairing() throws {
        let host = MiniHost(pairedKeys: [], acceptUnknown: false)
        let transport = PipeTransport()
        var hostError: Error?
        transport.peer = { do { try host.receive($0) } catch { if hostError == nil { hostError = error } } }
        host.toRemote = { d in transport.onData?(d) }
        let session = try RemoteSession(transport: transport, identity: NoiseKeyPair(), deviceName: "x", mode: .paired(hostKey: host.key.publicKey), queue: .main)
        try session.start()
        XCTAssertTrue(waitUntil { hostError != nil })
        XCTAssertEqual(hostError as? SecureChannel.Error, .unknownRemote, "\(String(describing: hostError))")
    }
}
