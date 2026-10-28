import Foundation

/// Framing between the `bluesteer run` wrapper and the host app over the
/// local Unix socket: `[u8 type][u32 big-endian length][payload]`.
public enum WrapperFrame {
    public static let hello: UInt8 = 0x01      // wrapper → host, JSON WrapperHello
    public static let output: UInt8 = 0x02     // wrapper → host, raw PTY output
    public static let resize: UInt8 = 0x03     // wrapper → host, JSON {"rows":..,"cols":..}
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
    public init(command: [String], cwd: String, rows: Int, cols: Int, pid: Int32) {
        self.command = command; self.cwd = cwd; self.rows = rows; self.cols = cols; self.pid = pid
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
