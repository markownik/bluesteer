import BlueSteerProtocol
import XCTest
@testable import HostCore

/// The session helper's client against the host's socket server: attach with
/// a screen, follow resizes, survive the server going away and re-attach.
final class WrapperClientTests: XCTestCase {
    private func pump(until deadline: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(deadline)
        while !condition() && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        return condition()
    }

    private func screen(of session: WrappedSession) -> String {
        String(decoding: session.snapshot(scrollbackLines: 0), as: UTF8.self)
    }

    func testHelperAttachesFollowsResizesAndReattaches() throws {
        let path = NSTemporaryDirectory() + "bluesteer-test-\(UUID().uuidString.prefix(8)).sock"
        var sessions: [WrappedSession] = []
        let server = WrapperSocketServer(path: path)
        server.onSession = { sessions.append($0) }
        try server.start()

        let id = SessionID()
        var resizes: [(Int, Int)] = []
        var screens = 0
        let client = WrapperClient(path: path, hello: {
            WrapperHello(command: ["/bin/zsh"], cwd: "/tmp", rows: 5, cols: 20, pid: 4242, sessionId: id.rawValue,
                         source: WrapperHello.hostSpawned, title: "zsh")
        }, screen: {
            screens += 1
            return Data("\u{1b}[H\u{1b}[2Jhello-from-helper\r\n".utf8)
        })
        client.onResize = { r, c in resizes.append((r, c)) }
        client.start()

        XCTAssertTrue(pump { sessions.count == 1 }, "the helper attaches")
        let first = sessions[0]
        XCTAssertEqual(first.id, id)
        XCTAssertEqual(first.state.source, .hostSpawned)
        XCTAssertEqual(first.state.title, "zsh")
        XCTAssertTrue(screen(of: first).contains("hello-from-helper"), "the screen was replayed")

        first.resize(rows: 7, cols: 30)
        XCTAssertTrue(pump { !resizes.isEmpty }, "resizes reach the helper")
        XCTAssertEqual(resizes[0].0, 7)
        XCTAssertEqual(resizes[0].1, 30)
        XCTAssertEqual(first.rows, 7)

        client.send(output: Data("live-output\r\n".utf8))
        XCTAssertTrue(pump { screen(of: first).contains("live-output") })

        // The host goes away: the session ends there, the helper keeps running and retries.
        server.stop()
        XCTAssertTrue(pump { first.status == .exited })

        let server2 = WrapperSocketServer(path: path)
        server2.onSession = { sessions.append($0) }
        try server2.start()
        XCTAssertTrue(pump(until: 4) { sessions.count == 2 }, "the helper re-attaches to the relaunched host")
        let second = sessions[1]
        XCTAssertEqual(second.id, id)
        XCTAssertEqual(screens, 2, "a fresh screen at every attach")
        XCTAssertTrue(screen(of: second).contains("hello-from-helper"))

        client.stop()
        XCTAssertTrue(pump { second.status == .exited })
        server2.stop()
    }
}
