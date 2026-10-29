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
        XCTAssertTrue(session.snapshot(scrollbackLines: 0).count > 0)
    }

    /// A snapshot with heavy truecolor history is cut down to the 32 KiB cap
    /// (SPEC.md §3) rather than exceeding one frame, and still shows the screen.
    func testSnapshotHistoryIsCutToTheSizeCap() throws {
        let hub = SessionHub()
        let session = FakeSession(rows: 10, cols: 40)
        hub.add(session)
        var rng = SystemRandomNumberGenerator()
        var text = ""
        for line in 0..<500 {
            for col in 0..<39 {
                text += "\u{1b}[38;2;\(Int.random(in: 0...255, using: &rng));\(Int.random(in: 0...255, using: &rng));\(Int.random(in: 0...255, using: &rng))m\(col % 10)"
            }
            text += "\u{1b}[0m\r\n"
            if line == 499 { text += "last-line-marker\r\n" }
        }
        session.emit(Data(text.utf8))
        XCTAssertGreaterThan(DeflateStream.compress(session.snapshot(scrollbackLines: 500)).count, SessionHub.snapshotLimit,
                             "the test needs a history that does not fit")

        var received: [BSEnvelope] = []
        hub.send = { env, _ in received.append(env) }
        hub.pendingBytes = { _ in 0 }
        hub.subscribe(link: UUID(), session: session.id, rows: 10, cols: 40, scrollbackLines: 500)
        guard case .termSnapshot(let snap)? = received.first?.body else { return XCTFail("expected a snapshot") }
        XCTAssertLessThanOrEqual(snap.vt.count, SessionHub.snapshotLimit)
        XCTAssertTrue(String(decoding: try inflate(snap.vt), as: UTF8.self).contains("last-line-marker"))
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

/// An in-memory session: output is whatever the test feeds it.
final class FakeSession: EmulatedSession, TerminalSession {
    let id = SessionID()
    private(set) var status: BSSessionStatus = .busy
    let pid: pid_t = 0
    var cwd = "/tmp"
    var onOutput: ((Data) -> Void)?
    var onExit: (() -> Void)?
    var written = Data()

    override init(rows: Int, cols: Int) { super.init(rows: rows, cols: cols) }

    func emit(_ data: Data) {
        feed(data)
        onOutput?(data)
    }

    func write(_ data: Data) { written.append(data) }
    func resize(rows: Int, cols: Int) { terminal.resize(cols: cols, rows: rows) }
    func stop(signal: Int32) {}
    func setStatus(_ status: BSSessionStatus) { self.status = status }
    var state: BSSessionState {
        BSSessionState.with { $0.sessionID = id.rawValue; $0.status = status; $0.rows = UInt32(rows); $0.cols = UInt32(cols) }
    }
}
