// term-bench: replays a pty-recorder recording through a headless SwiftTerm
// emulator and reports how many bytes per second the BlueSteer host would
// have to push over BLE under three strategies:
//   raw        – the PTY byte stream as is
//   deflate    – the same stream through one raw-deflate stream, sync-flushed every tick
//   snapshot   – a full-screen snapshot (VT serialisation) taken every `--snapshot-every` seconds
//
//   term-bench session.rec [--tick 50] [--snapshot-every 5]

import Foundation
import SwiftTerm
import zlib

// --- args ---------------------------------------------------------------

var args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else {
    print("usage: term-bench <file.rec> [--tick ms] [--snapshot-every s]")
    exit(64)
}
let path = args.removeFirst()
var tickMs = 50
var snapshotEvery = 5.0
while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--tick": tickMs = Int(args.removeFirst())!
    case "--snapshot-every": snapshotEvery = Double(args.removeFirst())!
    default: print("unknown option \(a)"); exit(64)
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

// --- deflate stream (raw, sync flush per tick) ----------------------------

final class DeflateStream {
    private var strm = z_stream()
    private var out = [UInt8](repeating: 0, count: 1 << 16)
    init() {
        deflateInit2_(&strm, 6, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    }
    /// Compresses `input` and sync-flushes; returns the number of bytes produced.
    func push(_ input: Data, flush: Bool) -> Int {
        var produced = 0
        var inBytes = [UInt8](input)
        inBytes.withUnsafeMutableBufferPointer { inPtr in
            strm.next_in = inPtr.baseAddress
            strm.avail_in = UInt32(inPtr.count)
            repeat {
                out.withUnsafeMutableBufferPointer { outPtr in
                    strm.next_out = outPtr.baseAddress
                    strm.avail_out = UInt32(outPtr.count)
                    deflate(&strm, flush ? Z_SYNC_FLUSH : Z_NO_FLUSH)
                    produced += outPtr.count - Int(strm.avail_out)
                }
            } while strm.avail_out == 0
        }
        return produced
    }
    static func oneShot(_ input: Data) -> Int {
        let s = DeflateStream()
        return s.push(input, flush: true)
    }
}

// --- headless terminal ----------------------------------------------------

final class Delegate: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {}
}

/// Serialises the visible screen as VT sequences a remote emulator can replay.
func snapshot(_ t: Terminal) -> Data {
    var s = "\u{1b}[H\u{1b}[2J"
    var lastAttr: Attribute? = nil
    for row in 0..<t.rows {
        s += "\u{1b}[\(row + 1);1H"
        var line = ""
        for col in 0..<t.cols {
            guard let cd = t.getCharData(col: col, row: row) else { continue }
            if cd.attribute != lastAttr {
                line += sgr(cd.attribute)
                lastAttr = cd.attribute
            }
            let ch = cd.getCharacter()
            line.append(ch == "\0" ? " " : ch)
        }
        s += line
    }
    s += "\u{1b}[0m\u{1b}[\(t.getCursorLocation().y + 1);\(t.getCursorLocation().x + 1)H"
    return s.data(using: .utf8)!
}

func sgr(_ a: Attribute) -> String {
    var codes = ["0"]
    if a.style.contains(.bold) { codes.append("1") }
    if a.style.contains(.dim) { codes.append("2") }
    if a.style.contains(.italic) { codes.append("3") }
    if a.style.contains(.underline) { codes.append("4") }
    if a.style.contains(.inverse) { codes.append("7") }
    codes.append(contentsOf: colorCodes(a.fg, fg: true))
    codes.append(contentsOf: colorCodes(a.bg, fg: false))
    return "\u{1b}[" + codes.joined(separator: ";") + "m"
}

func colorCodes(_ c: Attribute.Color, fg: Bool) -> [String] {
    switch c {
    case .defaultColor, .defaultInvertedColor: return []
    case .ansi256(let code):
        if code < 8 { return [String((fg ? 30 : 40) + Int(code))] }
        if code < 16 { return [String((fg ? 90 : 100) + Int(code) - 8)] }
        return [fg ? "38" : "48", "5", String(code)]
    case .trueColor(let r, let g, let b):
        return [fg ? "38" : "48", "2", String(r), String(g), String(b)]
    }
}

// --- replay ---------------------------------------------------------------

let entries = readRecording(path)
let terminal = Terminal(delegate: Delegate(), options: TerminalOptions(cols: 120, rows: 40))
let deflater = DeflateStream()

var rawPerSecond: [Int: Int] = [:]
var deflatePerSecond: [Int: Int] = [:]
var snapshotSizes: [(raw: Int, deflated: Int)] = []
var tickBuffer = Data()
var nextTick: UInt64 = 0
var nextSnapshot: UInt64 = 0
let tickMicros = UInt64(tickMs) * 1000
let snapshotMicros = UInt64(snapshotEvery * 1_000_000)
var totalRaw = 0, totalDeflate = 0

func flushTick(at micros: UInt64) {
    if !tickBuffer.isEmpty {
        let produced = deflater.push(tickBuffer, flush: true)
        let sec = Int(micros / 1_000_000)
        deflatePerSecond[sec, default: 0] += produced
        totalDeflate += produced
        tickBuffer.removeAll(keepingCapacity: true)
    }
}

var lastMicros: UInt64 = 0
for e in entries {
    while e.micros >= nextTick { flushTick(at: nextTick); nextTick += tickMicros }
    while e.micros >= nextSnapshot {
        let snap = snapshot(terminal)
        snapshotSizes.append((snap.count, DeflateStream.oneShot(snap)))
        nextSnapshot += snapshotMicros
    }
    switch e.type {
    case 0:
        terminal.feed(byteArray: [UInt8](e.payload))
        tickBuffer.append(e.payload)
        rawPerSecond[Int(e.micros / 1_000_000), default: 0] += e.payload.count
        totalRaw += e.payload.count
    case 1:
        let rows = Int(e.payload.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian)
        let cols = Int(e.payload.advanced(by: 2).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian)
        terminal.resize(cols: cols, rows: rows)
    default: break
    }
    lastMicros = e.micros
}
flushTick(at: lastMicros)

func percentile(_ values: [Int], _ p: Double) -> Int {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let idx = min(sorted.count - 1, Int(Double(sorted.count - 1) * p))
    return sorted[idx]
}

let seconds = max(1, Int(lastMicros / 1_000_000) + 1)
let rawSeries = (0..<seconds).map { rawPerSecond[$0, default: 0] }
let defSeries = (0..<seconds).map { deflatePerSecond[$0, default: 0] }
let activeRaw = rawSeries.filter { $0 > 0 }
let activeDef = defSeries.filter { $0 > 0 }

func kb(_ b: Int) -> String { String(format: "%6.1f KB", Double(b) / 1024) }

print("recording: \(path)")
print("duration:  \(seconds) s, \(entries.count) entries, tick \(tickMs) ms, terminal \(terminal.cols)x\(terminal.rows)")
print("")
print("                 mean(all)   mean(active)   p50(active)   p95(active)       max")
print("raw      /s   \(kb(totalRaw / seconds))  \(kb(activeRaw.isEmpty ? 0 : activeRaw.reduce(0,+) / activeRaw.count))   \(kb(percentile(activeRaw, 0.5)))   \(kb(percentile(activeRaw, 0.95)))   \(kb(rawSeries.max() ?? 0))")
print("deflate  /s   \(kb(totalDeflate / seconds))  \(kb(activeDef.isEmpty ? 0 : activeDef.reduce(0,+) / activeDef.count))   \(kb(percentile(activeDef, 0.5)))   \(kb(percentile(activeDef, 0.95)))   \(kb(defSeries.max() ?? 0))")
print("")
let snapRaw = snapshotSizes.map { $0.raw }, snapDef = snapshotSizes.map { $0.deflated }
print("snapshots: \(snapshotSizes.count) taken every \(snapshotEvery) s")
print("  raw      p50 \(kb(percentile(snapRaw, 0.5)))  p95 \(kb(percentile(snapRaw, 0.95)))  max \(kb(snapRaw.max() ?? 0))")
print("  deflate  p50 \(kb(percentile(snapDef, 0.5)))  p95 \(kb(percentile(snapDef, 0.95)))  max \(kb(snapDef.max() ?? 0))")
print("")
print("ratio raw/deflate: \(String(format: "%.1fx", Double(totalRaw) / Double(max(1, totalDeflate))))")
