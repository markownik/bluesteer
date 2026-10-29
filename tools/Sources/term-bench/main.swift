// term-bench: replays a pty-recorder recording through the host's headless
// emulator and reports how many bytes per second the BlueSteer host would
// have to push over BLE:
//   raw        – the PTY byte stream as is
//   deflate    – the same stream through the host's raw-deflate stream, sync-flushed
//                per piece of at most 3000 bytes (SessionHub.pieceSize), reset at every snapshot
//   wire       – deflate plus the per-message overhead of the protobuf envelope,
//                the Noise tag and the length prefix (SPEC.md §3–4)
//   snapshot   – a full-screen snapshot (HostCore's TerminalSnapshot) every `--snapshot-every` seconds
//
//   term-bench session.rec [--tick 50] [--snapshot-every 5] [--history 500]

import Foundation
import HostCore
import zlib

// --- args ---------------------------------------------------------------

var args = Array(CommandLine.arguments.dropFirst())
let usage = "usage: term-bench <file.rec> [--tick ms] [--snapshot-every s] [--history lines]"
guard !args.isEmpty else { print(usage); exit(64) }
let path = args.removeFirst()
var tickMs = 50
var snapshotEvery = 5.0
var historyLines = 500
func value(for flag: String) -> String {
    guard !args.isEmpty else { print("\(flag) needs a value\n\(usage)"); exit(64) }
    return args.removeFirst()
}
while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--tick": tickMs = Int(value(for: a)) ?? tickMs
    case "--snapshot-every": snapshotEvery = Double(value(for: a)) ?? snapshotEvery
    case "--history": historyLines = Int(value(for: a)) ?? historyLines
    default: print("unknown option \(a)\n\(usage)"); exit(64)
    }
}

// --- recording reader -----------------------------------------------------

struct Entry { let type: UInt8; let micros: UInt64; let payload: Data }

func readRecording(_ path: String) -> [Entry] {
    guard let data = FileManager.default.contents(atPath: path), data.starts(with: "BSREC\u{01}".data(using: .utf8)!) else {
        print("not a pty-recorder file: \(path)"); exit(1)
    }
    var entries: [Entry] = []
    var i = 6
    while i + 13 <= data.count {
        let type = data[i]
        let micros = data[(i+1)..<(i+9)].withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian
        let len = Int(data[(i+9)..<(i+13)].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)
        i += 13
        guard i + len <= data.count else { break }
        entries.append(Entry(type: type, micros: micros, payload: data[i..<(i+len)]))
        i += len
    }
    return entries
}

// --- deflate stream (raw, sync flush per piece, as the host does) ----------

final class DeflateStream {
    private var strm = z_stream()
    private var out = [UInt8](repeating: 0, count: 1 << 16)
    init() {
        deflateInit2_(&strm, 6, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    }
    deinit { deflateEnd(&strm) }
    /// Compresses `input` with a sync flush; returns the number of bytes produced.
    func push(_ input: Data) -> Int {
        var produced = 0
        var inBytes = [UInt8](input)
        inBytes.withUnsafeMutableBufferPointer { inPtr in
            strm.next_in = inPtr.baseAddress
            strm.avail_in = UInt32(inPtr.count)
            repeat {
                out.withUnsafeMutableBufferPointer { outPtr in
                    strm.next_out = outPtr.baseAddress
                    strm.avail_out = UInt32(outPtr.count)
                    deflate(&strm, Z_SYNC_FLUSH)
                    produced += outPtr.count - Int(strm.avail_out)
                }
            } while strm.avail_out == 0
        }
        return produced
    }
    static func oneShot(_ input: Data) -> Int { DeflateStream().push(input) }
}

// --- the wire format's fixed costs -----------------------------------------

/// Plaintext per TermOutput (SessionHub.pieceSize).
let pieceSize = 3000
/// Protobuf envelope with a 36-character session id and small varints (~60 B),
/// the Noise AEAD tag (16 B) and the frame length (2 B).
let messageOverhead = 60 + 16 + 2

// --- replay ---------------------------------------------------------------

let entries = readRecording(path)
let emulator = EmulatedSession(rows: 40, cols: 120)
var deflater = DeflateStream()

var rawPerSecond: [Int: Int] = [:]
var deflatePerSecond: [Int: Int] = [:]
var wirePerSecond: [Int: Int] = [:]
var snapshotSizes: [(raw: Int, deflated: Int)] = []
var tickBuffer = Data()
var nextTick: UInt64 = 0
var nextSnapshot: UInt64 = 0
let tickMicros = UInt64(tickMs) * 1000
let snapshotMicros = UInt64(snapshotEvery * 1_000_000)
var totalRaw = 0, totalDeflate = 0, totalWire = 0, messages = 0

func flushTick(at micros: UInt64) {
    guard !tickBuffer.isEmpty else { return }
    let sec = Int(micros / 1_000_000)
    var offset = 0
    while offset < tickBuffer.count {
        let piece = tickBuffer[offset..<min(offset + pieceSize, tickBuffer.count)]
        let produced = deflater.push(Data(piece))
        deflatePerSecond[sec, default: 0] += produced
        wirePerSecond[sec, default: 0] += produced + messageOverhead
        totalDeflate += produced
        totalWire += produced + messageOverhead
        messages += 1
        offset += piece.count
    }
    tickBuffer.removeAll(keepingCapacity: true)
}

var lastMicros: UInt64 = 0
for e in entries {
    while e.micros >= nextTick { flushTick(at: nextTick); nextTick += tickMicros }
    while e.micros >= nextSnapshot {
        let snap = emulator.snapshot(scrollbackLines: 0)
        snapshotSizes.append((snap.count, DeflateStream.oneShot(snap)))
        deflater = DeflateStream() // SPEC.md §4.3: the stream restarts at every snapshot
        nextSnapshot += snapshotMicros
    }
    switch e.type {
    case 0:
        emulator.feed(e.payload)
        tickBuffer.append(e.payload)
        rawPerSecond[Int(e.micros / 1_000_000), default: 0] += e.payload.count
        totalRaw += e.payload.count
    case 1:
        let rows = Int(e.payload.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian)
        let cols = Int(e.payload.advanced(by: 2).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian)
        emulator.resizeEmulator(rows: rows, cols: cols)
    default: break
    }
    lastMicros = e.micros
}
flushTick(at: lastMicros)
let historySnapshot = emulator.snapshot(scrollbackLines: historyLines)
let historySnapshotDeflated = DeflateStream.oneShot(historySnapshot)

func percentile(_ values: [Int], _ p: Double) -> Int {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let idx = min(sorted.count - 1, Int(Double(sorted.count - 1) * p))
    return sorted[idx]
}

let seconds = max(1, Int(lastMicros / 1_000_000) + 1)
func series(_ m: [Int: Int]) -> [Int] { (0..<seconds).map { m[$0, default: 0] } }
func kb(_ b: Int) -> String { String(format: "%6.1f KB", Double(b) / 1024) }
func row(_ name: String, _ total: Int, _ m: [Int: Int]) -> String {
    let all = series(m), active = all.filter { $0 > 0 }
    let meanActive = active.isEmpty ? 0 : active.reduce(0, +) / active.count
    return "\(name.padding(toLength: 11, withPad: " ", startingAt: 0))/s   \(kb(total / seconds))  \(kb(meanActive))   \(kb(percentile(active, 0.5)))   \(kb(percentile(active, 0.95)))   \(kb(all.max() ?? 0))"
}

print("recording: \(path)")
print("duration:  \(seconds) s, \(entries.count) entries, tick \(tickMs) ms, terminal \(emulator.cols)x\(emulator.rows), \(messages) messages")
print("")
print("                 mean(all)   mean(active)   p50(active)   p95(active)       max")
print(row("raw", totalRaw, rawPerSecond))
print(row("deflate", totalDeflate, deflatePerSecond))
print(row("wire", totalWire, wirePerSecond))
print("")
let snapRaw = snapshotSizes.map { $0.raw }, snapDef = snapshotSizes.map { $0.deflated }
print("snapshots: \(snapshotSizes.count) taken every \(snapshotEvery) s (screen only)")
print("  raw      p50 \(kb(percentile(snapRaw, 0.5)))  p95 \(kb(percentile(snapRaw, 0.95)))  max \(kb(snapRaw.max() ?? 0))")
print("  deflate  p50 \(kb(percentile(snapDef, 0.5)))  p95 \(kb(percentile(snapDef, 0.95)))  max \(kb(snapDef.max() ?? 0))")
print("first snapshot with \(historyLines) lines of history at the end: raw \(kb(historySnapshot.count)), deflate \(kb(historySnapshotDeflated))")
print("")
print("ratio raw/deflate: \(String(format: "%.1fx", Double(totalRaw) / Double(max(1, totalDeflate))))")
