import Foundation

/// Directories the user recently ran Claude Code in, from `~/.claude/history.jsonl`
/// (documented: one JSON object per prompt with a `project` path), newest first.
enum RecentProjects {
    static func load(limit: Int = 12) -> [String] {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/history.jsonl")
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return [NSHomeDirectory()]
        }
        var seen: [String] = []
        for line in text.split(separator: "\n").reversed() {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let project = obj["project"] as? String, !seen.contains(project),
                  FileManager.default.fileExists(atPath: project) else { continue }
            seen.append(project)
            if seen.count >= limit { break }
        }
        return seen.isEmpty ? [NSHomeDirectory()] : seen
    }
}
