import Foundation

/// Append-only record of security-relevant events (remote connects, pairing,
/// session starts) in `~/Library/Application Support/BlueSteer/audit.log`, 0600.
public final class AuditLog {
    public static let shared = AuditLog()
    static let rotateAbove = 5 * 1024 * 1024

    public let url: URL
    private let queue = DispatchQueue(label: "dev.bluesteer.audit")
    private let formatter = ISO8601DateFormatter()

    public init(directory: URL = HostInfo.supportDirectory) {
        url = directory.appendingPathComponent("audit.log")
    }

    public func record(_ event: String) {
        let line = "\(formatter.string(from: Date())) \(event)\n"
        queue.async { [self] in
            let fm = FileManager.default
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
            if let size = try? fm.attributesOfItem(atPath: url.path)[.size] as? Int, size > Self.rotateAbove {
                let old = url.deletingPathExtension().appendingPathExtension("log.1")
                try? fm.removeItem(at: old)
                try? fm.moveItem(at: url, to: old)
            }
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile()
                h.write(Data(line.utf8))
                try? h.close()
            }
        }
    }
}
