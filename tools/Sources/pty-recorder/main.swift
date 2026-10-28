// pty-recorder: runs a command in a pseudo-terminal, proxies it to the real
// terminal, and records the raw PTY output with timestamps.
//
//   pty-recorder -o session.rec -- claude
//
// Recording format (little-endian):
//   magic "BSREC\x01"
//   entries: [u8 type][u64 micros since start][u32 len][payload]
//     type 0 = PTY output bytes
//     type 1 = resize, payload = [u16 rows][u16 cols]
// Input is never recorded (it may contain secrets).

import Darwin
import Foundation

func usage() -> Never {
    FileHandle.standardError.write("usage: pty-recorder -o <file.rec> -- <command> [args...]\n".data(using: .utf8)!)
    exit(64)
}

var args = Array(CommandLine.arguments.dropFirst())
var outputPath: String?
var command: [String] = []
while !args.isEmpty {
    let a = args.removeFirst()
    if a == "-o" {
        guard !args.isEmpty else { usage() }
        outputPath = args.removeFirst()
    } else if a == "--" {
        command = args
        args = []
    } else {
        command = [a] + args
        args = []
    }
}
guard let outputPath, !command.isEmpty else { usage() }

// --- recording file -------------------------------------------------------

final class Recorder {
    private let handle: FileHandle
    private let start = DispatchTime.now()
    private let lock = NSLock()

    init(path: String) throws {
        FileManager.default.createFile(atPath: path, contents: nil)
        handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        handle.write("BSREC\u{01}".data(using: .utf8)!)
    }

    func write(type: UInt8, payload: Data) {
        let micros = (DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1000
        var entry = Data([type])
        var t = micros.littleEndian
        withUnsafeBytes(of: &t) { entry.append(contentsOf: $0) }
        var len = UInt32(payload.count).littleEndian
        withUnsafeBytes(of: &len) { entry.append(contentsOf: $0) }
        entry.append(payload)
        lock.lock(); handle.write(entry); lock.unlock()
    }

    func resize(_ ws: winsize) {
        var p = Data()
        var r = ws.ws_row.littleEndian, c = ws.ws_col.littleEndian
        withUnsafeBytes(of: &r) { p.append(contentsOf: $0) }
        withUnsafeBytes(of: &c) { p.append(contentsOf: $0) }
        write(type: 1, payload: p)
    }

    func close() { lock.lock(); try? handle.close(); lock.unlock() }
}

// --- terminal setup --------------------------------------------------------

var originalTermios = termios()
let stdinIsTTY = isatty(STDIN_FILENO) == 1
if stdinIsTTY { tcgetattr(STDIN_FILENO, &originalTermios) }

var ws = winsize()
if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != 0 || ws.ws_row == 0 {
    ws.ws_row = 40; ws.ws_col = 120
}

let recorder: Recorder
do { recorder = try Recorder(path: outputPath) } catch {
    FileHandle.standardError.write("cannot open \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}
recorder.resize(ws)

// --- fork ------------------------------------------------------------------

var master: Int32 = 0
var childTermios = originalTermios
let pid: pid_t = stdinIsTTY ? forkpty(&master, nil, &childTermios, &ws) : forkpty(&master, nil, nil, &ws)
if pid < 0 {
    perror("forkpty"); exit(1)
}
if pid == 0 {
    // child
    let cargs = command.map { strdup($0) } + [nil]
    execvp(command[0], cargs)
    perror("execvp")
    _exit(127)
}

// parent: raw mode on the real terminal
if stdinIsTTY {
    var raw = originalTermios
    cfmakeraw(&raw)
    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
}

func restoreTerminal() {
    if stdinIsTTY { tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios) }
}

// SIGWINCH → propagate size to the PTY and record it.
signal(SIGWINCH, SIG_IGN)
let winchSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
winchSource.setEventHandler {
    var now = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &now) == 0 {
        _ = ioctl(master, TIOCSWINSZ, &now)
        recorder.resize(now)
    }
}
winchSource.resume()

// PTY → stdout + recording
let outQueue = DispatchQueue(label: "pty.out")
outQueue.async {
    var buf = [UInt8](repeating: 0, count: 65536)
    while true {
        let n = read(master, &buf, buf.count)
        if n <= 0 { break }
        let data = Data(buf[0..<n])
        recorder.write(type: 0, payload: data)
        data.withUnsafeBytes { ptr in
            var off = 0
            while off < n {
                let w = write(STDOUT_FILENO, ptr.baseAddress! + off, n - off)
                if w <= 0 { break }
                off += w
            }
        }
    }
}

// stdin → PTY
let inQueue = DispatchQueue(label: "pty.in")
inQueue.async {
    var buf = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = read(STDIN_FILENO, &buf, buf.count)
        if n <= 0 { break }
        _ = write(master, buf, n)
    }
}

// Wait for the child on a background queue, then exit from main.
DispatchQueue.global().async {
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    usleep(50_000) // let the last output drain
    recorder.close()
    restoreTerminal()
    let code: Int32
    if (status & 0x7f) == 0 { code = (status >> 8) & 0xff } else { code = 128 + (status & 0x7f) }
    exit(code)
}

dispatchMain()
