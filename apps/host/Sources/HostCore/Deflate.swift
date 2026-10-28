import Foundation
import zlib

/// Raw-deflate stream with a sync flush per `push`, so each output piece can
/// be inflated by the receiver as it arrives (SPEC.md §4.3).
final class DeflateStream {
    private var strm = z_stream()
    private var out = [UInt8](repeating: 0, count: 1 << 15)

    init() {
        deflateInit2_(&strm, 6, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    }

    deinit { deflateEnd(&strm) }

    func push(_ input: Data) -> Data {
        var result = Data()
        var inBytes = [UInt8](input)
        inBytes.withUnsafeMutableBufferPointer { inPtr in
            strm.next_in = inPtr.baseAddress
            strm.avail_in = UInt32(inPtr.count)
            repeat {
                out.withUnsafeMutableBufferPointer { outPtr in
                    strm.next_out = outPtr.baseAddress
                    strm.avail_out = UInt32(outPtr.count)
                    deflate(&strm, Z_SYNC_FLUSH)
                    result.append(contentsOf: outPtr[0..<(outPtr.count - Int(strm.avail_out))])
                }
            } while strm.avail_out == 0
        }
        return result
    }

    static func compress(_ input: Data) -> Data { DeflateStream().push(input) }
}
