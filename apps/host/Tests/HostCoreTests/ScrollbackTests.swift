import BlueSteerProtocol
import XCTest
@testable import HostCore

final class ScrollbackTests: XCTestCase {
    /// A subscription asking for history gets it in its first snapshot only (SPEC.md §4.4).
    func testFirstSnapshotCarriesHistory() throws {
        let hub = SessionHub()
        let link = UUID()
        var received: [BSEnvelope] = []
        hub.send = { env, _ in received.append(env) }
        hub.pendingBytes = { _ in 0 }

        let session = try hub.start(command: ["/bin/sh", "-c", "i=1; while [ $i -le 30 ]; do echo line-$i; i=$((i+1)); done; sleep 0.3"], cwd: "/tmp", rows: 5, cols: 40)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5)) // let the output land in the emulator
        hub.subscribe(link: link, session: session.id, rows: 5, cols: 40, scrollbackLines: 10)
        guard case .termSnapshot(let snap)? = received.first?.body else { return XCTFail("expected a snapshot") }
        let vt = String(decoding: try inflate(snap.vt), as: UTF8.self)
        XCTAssertTrue(vt.contains("\u{1b}[3J"), "erases the remote's history")
        XCTAssertTrue(vt.contains("line-20\u{1b}[0m\r\n"), vt)   // 10 lines above the 5-row screen: 16..25
        XCTAssertFalse(vt.contains("line-15"), "only the requested number of lines")
        XCTAssertTrue(vt.contains("line-30"), "the screen itself")

        // A later snapshot (e.g. after backpressure) carries the screen only.
        received.removeAll()
        hub.subscribe(link: link, session: session.id, rows: 5, cols: 40)
        guard case .termSnapshot(let again)? = received.first?.body else { return XCTFail("expected a snapshot") }
        let vt2 = String(decoding: try inflate(again.vt), as: UTF8.self)
        XCTAssertFalse(vt2.contains("\u{1b}[3J"))
        XCTAssertFalse(vt2.contains("line-20"))
        session.stop(signal: SIGKILL)
    }

    func testScreenOnlyWhenNoHistoryRequested() throws {
        let session = try PtySession(command: ["/bin/sh", "-c", "echo only; sleep 0.3"], cwd: "/tmp", rows: 5, cols: 20)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let vt = String(decoding: session.snapshot(scrollbackLines: 0), as: UTF8.self)
        XCTAssertTrue(vt.hasPrefix("\u{1b}[0m\u{1b}[H\u{1b}[2J"))
        XCTAssertTrue(vt.contains("only"))
        session.stop(signal: SIGKILL)
    }

    private func inflate(_ data: Data) throws -> Data {
        var strm = z_stream()
        inflateInit2_(&strm, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        defer { inflateEnd(&strm) }
        var input = [UInt8](data)
        var out = Data()
        var buf = [UInt8](repeating: 0, count: 1 << 16)
        input.withUnsafeMutableBufferPointer { inPtr in
            strm.next_in = inPtr.baseAddress
            strm.avail_in = UInt32(inPtr.count)
            repeat {
                buf.withUnsafeMutableBufferPointer { outPtr in
                    strm.next_out = outPtr.baseAddress
                    strm.avail_out = UInt32(outPtr.count)
                    zlib.inflate(&strm, Z_SYNC_FLUSH)
                    out.append(contentsOf: outPtr[0..<(outPtr.count - Int(strm.avail_out))])
                }
            } while strm.avail_out == 0
        }
        return out
    }
}

import zlib
