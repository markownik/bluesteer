import Foundation

/// Length-prefixed framing for Noise transport messages (SPEC.md §3).
///
/// The BLE link delivers an ordered byte stream in arbitrary chunks. `Framer`
/// turns those chunks back into whole messages, and `frame(_:)` produces the
/// bytes to send for one message.
public enum Framing {
    /// Largest ciphertext a single frame may carry (Noise's 65535 limit).
    public static let maxFrameLength = 65535

    public enum Error: Swift.Error, Equatable {
        case messageTooLong(Int)
    }

    /// Prefixes `message` with its 16-bit big-endian length.
    public static func frame(_ message: Data) throws -> Data {
        guard message.count <= maxFrameLength else { throw Error.messageTooLong(message.count) }
        var out = Data(capacity: message.count + 2)
        out.append(UInt8(message.count >> 8))
        out.append(UInt8(message.count & 0xff))
        out.append(message)
        return out
    }
}

/// Reassembles complete frames from an incoming byte stream.
public struct Framer {
    private var buffer = Data()

    public init() {}

    /// Appends received bytes and returns every message completed by them, in order.
    public mutating func receive(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var messages: [Data] = []
        while buffer.count >= 2 {
            let length = Int(buffer[buffer.startIndex]) << 8 | Int(buffer[buffer.startIndex + 1])
            guard buffer.count >= 2 + length else { break }
            let start = buffer.startIndex + 2
            messages.append(Data(buffer[start..<(start + length)]))
            buffer.removeSubrange(buffer.startIndex..<(start + length))
        }
        return messages
    }

    /// Bytes received so far that do not yet form a complete frame.
    public var pendingByteCount: Int { buffer.count }
}
