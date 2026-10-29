import Foundation

/// Framing between the `bluesteer run` wrapper and the host app over the
/// local Unix socket: `[u8 type][u32 big-endian length][payload]`.
public enum WrapperFrame {
    public static let hello: UInt8 = 0x01      // wrapper → host, JSON WrapperHello
    public static let output: UInt8 = 0x02     // wrapper → host, raw PTY output
    public static let resize: UInt8 = 0x03     // wrapper → host, JSON {"rows":..,"cols":..}
    public static let hook: UInt8 = 0x04       // `bluesteer hook` → host, JSON HookEvent; no hello
    public static let input: UInt8 = 0x10      // host → wrapper, bytes for the PTY

    public static func encode(_ type: UInt8, _ payload: Data) -> Data {
        var d = Data([type])
        var len = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &len) { d.append(contentsOf: $0) }
        d.append(payload)
        return d
    }
}

public struct WrapperHello: Codable {
    public var command: [String]
    public var cwd: String
    public var rows: Int
    public var cols: Int
    public var pid: Int32
    /// The `BLUESTEER_SESSION` value the wrapper exported, so hook events match the session.
    public var sessionId: String?
    public init(command: [String], cwd: String, rows: Int, cols: Int, pid: Int32, sessionId: String? = nil) {
        self.command = command; self.cwd = cwd; self.rows = rows; self.cols = cols; self.pid = pid; self.sessionId = sessionId
    }
}

/// A Claude Code hook event relayed by `bluesteer hook <Event>` (docs/architecture.md).
public struct HookEvent: Codable {
    public var event: String
    /// `BLUESTEER_SESSION` from the hook's environment.
    public var session: String
    /// `notification_type` from the hook's JSON for `Notification` events.
    public var notificationType: String?
    public init(event: String, session: String, notificationType: String? = nil) {
        self.event = event; self.session = session; self.notificationType = notificationType
    }
}

/// Reassembles wrapper frames from a byte stream.
public struct WrapperFrameParser {
    private var buffer = Data()
    public init() {}

    public mutating func receive(_ data: Data) -> [(type: UInt8, payload: Data)] {
        buffer.append(data)
        var frames: [(UInt8, Data)] = []
        while buffer.count >= 5 {
            let type = buffer[buffer.startIndex]
            let len = Int(buffer[buffer.startIndex + 1]) << 24 | Int(buffer[buffer.startIndex + 2]) << 16
                | Int(buffer[buffer.startIndex + 3]) << 8 | Int(buffer[buffer.startIndex + 4])
            guard buffer.count >= 5 + len else { break }
            let start = buffer.startIndex + 5
            frames.append((type, Data(buffer[start..<(start + len)])))
            buffer.removeSubrange(buffer.startIndex..<(start + len))
        }
        return frames
    }
}

public enum WrapperSocket {
    public static var path: String { HostInfo.supportDirectory.appendingPathComponent("bluesteer.sock").path }
}

public enum LocalSocket {
    /// Keeps a socket out of child processes and makes a vanished peer an
    /// `EPIPE` error instead of a `SIGPIPE`.
    public static func harden(_ fd: Int32) {
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        var on: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }
}
