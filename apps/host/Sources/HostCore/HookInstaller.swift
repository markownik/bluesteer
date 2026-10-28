import Foundation

/// Installs `bluesteer hook <Event>` command hooks in Claude Code's user
/// settings so the host learns when a bridged session is busy, waiting for
/// input or waiting for permission (SPEC.md §4.1). Idempotent and reversible.
public enum HookInstaller {
    public static let events = ["Notification", "Stop", "UserPromptSubmit", "SessionStart", "SessionEnd"]

    public static var settingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")
    public static var backupURL: URL { settingsURL.deletingLastPathComponent().appendingPathComponent("settings.json.bluesteer-backup") }

    /// Stable path for the hook commands: a symlink in the support directory
    /// that `refreshCLILink` points at the `bluesteer` binary next to the host.
    public static var cliLink: URL { HostInfo.supportDirectory.appendingPathComponent("bluesteer") }

    /// Points `cliLink` at the CLI shipped next to this executable. Call at launch.
    public static func refreshCLILink() {
        guard let exe = Bundle.main.executableURL else { return }
        let cli = exe.deletingLastPathComponent().appendingPathComponent("bluesteer")
        guard FileManager.default.isExecutableFile(atPath: cli.path) else { return }
        try? FileManager.default.createDirectory(at: cliLink.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: cliLink.path)) == cli.path { return }
        try? FileManager.default.removeItem(at: cliLink)
        try? FileManager.default.createSymbolicLink(at: cliLink, withDestinationURL: cli)
    }

    public enum Error: Swift.Error, LocalizedError {
        case notAnObject
        public var errorDescription: String? { "\(settingsURL.path) is not a JSON object" }
    }

    public static func isInstalled() -> Bool {
        guard let settings = try? load(), let hooks = settings["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { hooks[$0].map { isOurs($0) } ?? false }
    }

    /// Adds our entries (replacing earlier ones) and backs the file up first.
    public static func install() throws {
        var settings = try load()
        if !isInstalled(), FileManager.default.fileExists(atPath: settingsURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: settingsURL, to: backupURL)
        }
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var entries = (hooks[event] as? [Any] ?? []).filter { !isOurs($0) }
            entries.append(["hooks": [["type": "command", "command": command(for: event)]]])
            hooks[event] = entries
        }
        settings["hooks"] = hooks
        try save(settings)
    }

    /// Removes our entries and leaves everything else as it was.
    public static func uninstall() throws {
        var settings = try load()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }
        for (event, value) in hooks {
            let entries = (value as? [Any] ?? []).filter { !isOurs($0) }
            hooks[event] = entries.isEmpty ? nil : entries
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        try save(settings)
    }

    public static func command(for event: String) -> String { "\"\(cliLink.path)\" hook \(event)" }

    /// True for a matcher entry (or an event's whole array) that contains one of our commands.
    static func isOurs(_ value: Any) -> Bool {
        if let array = value as? [Any] { return array.contains { isOurs($0) } }
        guard let entry = value as? [String: Any], let hooks = entry["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { isOurCommand($0["command"] as? String ?? "") }
    }

    /// `"<…>/bluesteer" hook <Event>` in any install location.
    static func isOurCommand(_ command: String) -> Bool {
        command.contains("bluesteer\" hook ") || command.contains("bluesteer hook ")
    }

    private static func load() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL), !data.isEmpty else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Error.notAnObject }
        return object
    }

    private static func save(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: settingsURL, options: .atomic)
    }
}
