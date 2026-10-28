import BlueSteerProtocol
import XCTest
@testable import HostCore

final class SessionHubTests: XCTestCase {
    /// Starts a shell command, subscribes a fake link, and checks the snapshot
    /// and output stream carry the command's output.
    func testSnapshotAndOutputReachSubscriber() throws {
        let hub = SessionHub()
        let link = UUID()
        var received: [BSEnvelope] = []
        hub.send = { env, _ in received.append(env) }
        hub.pendingBytes = { _ in 0 }

        let session = try hub.start(command: ["/bin/sh", "-c", "echo hello-bluesteer; sleep 0.3; echo second-line; sleep 0.2"], cwd: "/tmp", rows: 10, cols: 40)
        hub.subscribe(link: link, session: session.id, rows: 10, cols: 40)
        XCTAssertEqual(received.count, 1)
        guard case .termSnapshot(let snap)? = received.first?.body else { return XCTFail("expected a snapshot first") }
        XCTAssertEqual(Int(snap.rows), 10)
        XCTAssertTrue(snap.compressed)

        let exited = expectation(description: "exit")
        session.onExit = { exited.fulfill() }
        wait(for: [exited], timeout: 5)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2)) // let the flush timer run

        let outputs = received.compactMap { env -> BSTermOutput? in
            if case .termOutput(let o) = env.body { return o } else { return nil }
        }
        XCTAssertFalse(outputs.isEmpty)
        let seqs = outputs.map(\.seq)
        XCTAssertEqual(seqs, Array(seqs.sorted()), "sequence numbers increase")
        let inflated = try inflate(outputs.map(\.data).reduce(Data(), +))
        let text = String(decoding: inflated, as: UTF8.self)
        XCTAssertTrue(text.contains("hello-bluesteer"), text)
        XCTAssertTrue(text.contains("second-line"), text)
        XCTAssertEqual(session.status, .exited)
        XCTAssertTrue(session.snapshot().count > 0)
    }

    private func inflate(_ data: Data) throws -> Data {
        // Raw deflate with sync flushes: zlib's inflate handles the concatenated pieces.
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
