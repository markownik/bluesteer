import Foundation
import zlib

/// Streaming raw inflate (no zlib header), the mirror of the host's
/// `DeflateStream`: feed the `TermOutput` pieces of one subscription in order.
public final class InflateStream {
    private var stream = z_stream()
    private var buffer = [UInt8](repeating: 0, count: 1 << 16)

    public init() {
        inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    }

    deinit { inflateEnd(&stream) }

    /// Inflates what can be inflated from `data` so far.
    public func push(_ data: Data) -> Data {
        var out = Data()
        var input = [UInt8](data)
        input.withUnsafeMutableBufferPointer { inPtr in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = UInt32(inPtr.count)
            repeat {
                buffer.withUnsafeMutableBufferPointer { outPtr in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = UInt32(outPtr.count)
                    _ = zlib.inflate(&stream, Z_SYNC_FLUSH)
                    out.append(contentsOf: outPtr[0..<(outPtr.count - Int(stream.avail_out))])
                }
            } while stream.avail_out == 0
        }
        return out
    }

    /// One-shot inflate of a complete raw-deflate buffer (snapshots).
    public static func inflateAll(_ data: Data) -> Data { InflateStream().push(data) }
}
