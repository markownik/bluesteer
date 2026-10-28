import BlueSteerProtocol
import XCTest
@testable import HostCore

final class HookTests: XCTestCase {
    func testInstallerMergesAndRemovesWithoutTouchingOtherKeys() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bluesteer-hooks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = HookInstaller.settingsURL
        defer { HookInstaller.settingsURL = original }
        HookInstaller.settingsURL = dir.appendingPathComponent("settings.json")
        let existing = """
        {"model": "opus", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "say done"}]}]}}
        """
        try Data(existing.utf8).write(to: HookInstaller.settingsURL)

        XCTAssertFalse(HookInstaller.isInstalled())
        try HookInstaller.install()
        XCTAssertTrue(HookInstaller.isInstalled())
        XCTAssertTrue(FileManager.default.fileExists(atPath: HookInstaller.backupURL.path))
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: HookInstaller.settingsURL)) as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "opus")
        var hooks = json["hooks"] as! [String: Any]
        XCTAssertEqual((hooks["Stop"] as! [Any]).count, 2, "the user's Stop hook is kept")
        XCTAssertEqual(Set(hooks.keys), Set(HookInstaller.events))

        try HookInstaller.install() // idempotent
        json = try JSONSerialization.jsonObject(with: Data(contentsOf: HookInstaller.settingsURL)) as! [String: Any]
        hooks = json["hooks"] as! [String: Any]
        XCTAssertEqual((hooks["Stop"] as! [Any]).count, 2)

        try HookInstaller.uninstall()
        XCTAssertFalse(HookInstaller.isInstalled())
        json = try JSONSerialization.jsonObject(with: Data(contentsOf: HookInstaller.settingsURL)) as! [String: Any]
        hooks = json["hooks"] as! [String: Any]
        XCTAssertEqual(Array(hooks.keys), ["Stop"])
        XCTAssertEqual((hooks["Stop"] as! [Any]).count, 1)
        XCTAssertEqual(json["model"] as? String, "opus")
    }

    func testHookEventsDriveSessionStatus() throws {
        let hub = SessionHub()
        var changes: [BSSessionStatus] = []
        hub.onSessionChanged = { changes.append($0.status) }
        let session = try hub.start(command: ["/bin/sh", "-c", "sleep 2"], cwd: "/tmp", rows: 5, cols: 20)
        let id = session.id.rawValue
        changes.removeAll()
        hub.hook(HookEvent(event: "SessionStart", session: id))
        hub.hook(HookEvent(event: "UserPromptSubmit", session: id))
        hub.hook(HookEvent(event: "Notification", session: id, notificationType: "permission_prompt"))
        hub.hook(HookEvent(event: "Notification", session: id, notificationType: "other"))  // ignored
        hub.hook(HookEvent(event: "Stop", session: id))
        hub.hook(HookEvent(event: "SessionEnd", session: id))
        hub.hook(HookEvent(event: "Stop", session: "no-such-session"))
        XCTAssertEqual(changes, [.waitingInput, .busy, .waitingPermission, .waitingInput, .idle])
        session.stop(signal: SIGKILL)
    }
}
