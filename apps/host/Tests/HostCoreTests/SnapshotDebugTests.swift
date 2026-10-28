import XCTest
@testable import HostCore

final class SnapshotDebugTests: XCTestCase {
    func testInteractiveShellSnapshotShowsPrompt() throws {
        let session = try PtySession(command: [ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"], cwd: NSHomeDirectory(), rows: 10, cols: 51)
        var raw = Data()
        session.onOutput = { raw.append($0) }
        RunLoop.main.run(until: Date().addingTimeInterval(2.0))
        let vt = String(decoding: session.snapshot(scrollbackLines: 0), as: UTF8.self)
        let visible = vt.replacingOccurrences(of: "\u{1b}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
        print("RAW BYTES: \(raw.count)")
        print("RAW HEAD: \(String(decoding: raw.prefix(300), as: UTF8.self).debugDescription)")
        print("SNAPSHOT VT HEAD: \(vt.prefix(400).debugDescription)")
        print("VISIBLE: \(visible.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200).debugDescription)")
        session.stop(signal: SIGKILL)
        XCTAssertFalse(visible.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
