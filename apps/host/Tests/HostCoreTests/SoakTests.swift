import BlueSteerProtocol
import XCTest
@testable import HostCore
@testable import RemoteCore

/// Many connect → handshake → subscribe → type → disconnect cycles against one
/// hub and one shell, in memory: sequence numbers stay consecutive, forced
/// backpressure snapshots resync cleanly, and nothing leaks per cycle.
/// `SOAK_CYCLES` in the environment raises the count (default 50).
final class SoakTests: XCTestCase {
    private func pump(_ seconds: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
    private func waitUntil(_ timeout: TimeInterval = 5, _ cond: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end { if cond() { return true }; pump(0.02) }
        return cond()
    }

    func testConnectCycles() throws {
        let cycles = Int(ProcessInfo.processInfo.environment["SOAK_CYCLES"] ?? "") ?? 50
        let hub = SessionHub()
        let remoteKey = NoiseKeyPair()
        let hostKey = NoiseKeyPair()
        let pty = try hub.start(command: ["/bin/sh", "-c", "cat"], cwd: "/tmp", rows: 6, cols: 40)
        defer { pty.stop(signal: SIGKILL) }
        var queued = 0
        hub.pendingBytes = { _ in queued }
        var hosts: [UUID: RemoteSessionTests.MiniHost] = [:]
        hub.send = { env, link in hosts[link]?.send(env) }

        for cycle in 0..<cycles {
            weak var weakHost: RemoteSessionTests.MiniHost?
            weak var weakSession: RemoteSession?
            try autoreleasepool {
                let host = RemoteSessionTests.MiniHost(pairedKeys: [remoteKey.publicKey], acceptUnknown: false, hub: hub, key: hostKey)
                hosts[host.link] = host
                let transport = RemoteSessionTests.PipeTransport()
                transport.peer = { try? host.receive($0) }
                host.toRemote = { d in transport.onData?(d) }
                let session = try RemoteSession(transport: transport, identity: remoteKey, deviceName: "soak", mode: .paired(hostKey: hostKey.publicKey), queue: .main)
                weakHost = host
                weakSession = session
                var ready = false
                session.onReady = { ready = true }
                try session.start()
                XCTAssertTrue(waitUntil { ready }, "cycle \(cycle): handshake")

                var snapshots: [BSTermSnapshot] = []
                var outputs: [BSTermOutput] = []
                session.onEnvelope = { e in
                    switch e.body {
                    case .termSnapshot(let s): snapshots.append(s)
                    case .termOutput(let o): outputs.append(o)
                    default: break
                    }
                }
                try session.send(BSEnvelope.with {
                    $0.subscribe = BSSubscribe.with { $0.cmdID = 1; $0.sessionID = pty.id.rawValue; $0.rows = 6; $0.cols = 40; $0.scrollbackLines = 10 }
                })
                XCTAssertTrue(waitUntil { snapshots.count == 1 }, "cycle \(cycle): snapshot")
                let marker = "cycle-\(cycle)\n"
                try session.send(BSEnvelope.with { $0.termInput = BSTermInput.with { $0.sessionID = pty.id.rawValue; $0.data = Data(marker.utf8) } })
                XCTAssertTrue(waitUntil { !outputs.isEmpty }, "cycle \(cycle): output")
                pump(0.1)

                if cycle % 10 == 9 {
                    // The link falls behind: the backlog is dropped and a fresh snapshot follows once it drains.
                    queued = SessionHub.backpressureLimit
                    try session.send(BSEnvelope.with { $0.termInput = BSTermInput.with { $0.sessionID = pty.id.rawValue; $0.data = Data("behind\n".utf8) } })
                    pump(0.15)
                    queued = 0
                    XCTAssertTrue(waitUntil { snapshots.count == 2 }, "cycle \(cycle): backpressure snapshot")
                    try session.send(BSEnvelope.with { $0.termInput = BSTermInput.with { $0.sessionID = pty.id.rawValue; $0.data = Data("after\n".utf8) } })
                    XCTAssertTrue(waitUntil { outputs.last.map { $0.seq > snapshots[1].seq } ?? false }, "cycle \(cycle): output after the snapshot")
                }

                // Sequence numbers: consecutive within each snapshot's stream.
                var expected = snapshots[0].seq
                var streamIndex = 0
                for o in outputs {
                    if streamIndex + 1 < snapshots.count, o.seq > snapshots[streamIndex + 1].seq {
                        streamIndex += 1
                        expected = snapshots[streamIndex].seq
                    }
                    XCTAssertEqual(o.seq, expected + 1, "cycle \(cycle): seq")
                    expected = o.seq
                }
                let inflater = InflateStream()
                let lastStreamStart = snapshots.last!.seq
                let text = String(decoding: outputs.filter { $0.seq > lastStreamStart }.reduce(Data()) { $0 + inflater.push($1.data) }, as: UTF8.self)
                XCTAssertTrue(text.contains(cycle % 10 == 9 ? "after" : "cycle-\(cycle)"), "cycle \(cycle): \(text)")

                session.close()
                host.close()
                hosts[host.link] = nil
                transport.peer = nil // the test's own host ↔ transport cycle
                XCTAssertTrue(waitUntil { hub.activeSubscriptions == 0 }, "cycle \(cycle): subscription released")
            }
            pump(0.05)
            XCTAssertNil(weakHost, "cycle \(cycle): host released")
            XCTAssertNil(weakSession, "cycle \(cycle): session released")
        }
    }
}
