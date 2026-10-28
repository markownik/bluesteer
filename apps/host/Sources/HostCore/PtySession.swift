import BlueSteerProtocol
import Darwin
import Foundation
import SwiftTerm

/// A command running in a pseudo-terminal with a headless emulator tracking
/// its screen. Output is delivered on the main queue.
public final class PtySession {
    public let id: SessionID
    public let command: [String]
    public let cwd: String
    public private(set) var status: BSSessionStatus = .busy
    public private(set) var exitCode: Int32 = 0
    public var title: String { delegate.title ?? command.first.map { ($0 as NSString).lastPathComponent } ?? "" }
    public var rows: Int { terminal.rows }
    public var cols: Int { terminal.cols }

    /// Raw PTY output, as read.
    public var onOutput: ((Data) -> Void)?
    public var onExit: (() -> Void)?

    private let terminal: Terminal
    private let master: Int32
    private let pid: pid_t
    private var reader: DispatchSourceRead?
    private let delegate = NullTerminalDelegate()

    /// Starts `command` through the user's login shell so PATH matches the terminal.
    public init(id: SessionID = SessionID(), command: [String], cwd: String, rows: Int, cols: Int) throws {
        self.id = id
        self.command = command
        self.cwd = cwd
        terminal = Terminal(delegate: delegate, options: TerminalOptions(cols: cols, rows: rows))

        var ws = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
        var fd: Int32 = 0
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let argv = [shell, "-l", "-c", "exec \"$@\"", "--"] + command
        let cargs = argv.map { strdup($0) } + [nil]
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["BLUESTEER_SESSION"] = id.rawValue
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        let cenv = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        let child = forkpty(&fd, nil, nil, &ws)
        if child < 0 { throw POSIXError(.EAGAIN) }
        if child == 0 {
            chdir(cwd)
            execve(argv[0], cargs, cenv)
            _exit(127)
        }
        for p in cargs { free(p) }
        for p in cenv { free(p) }
        master = fd
        pid = child
        startReading()
    }

    private func startReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: master, queue: DispatchQueue(label: "pty.\(id.rawValue)"))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var buf = [UInt8](repeating: 0, count: 65536)
            let n = read(master, &buf, buf.count)
            if n > 0 {
                let data = Data(buf[0..<n])
                DispatchQueue.main.async {
                    self.terminal.feed(byteArray: [UInt8](data))
                    self.onOutput?(data)
                }
            } else {
                source.cancel()
                var status: Int32 = 0
                waitpid(self.pid, &status, 0)
                DispatchQueue.main.async {
                    self.exitCode = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
                    self.status = .exited
                    self.onExit?()
                }
            }
        }
        source.setCancelHandler { [master] in close(master) }
        reader = source
        source.resume()
    }

    public func write(_ data: Data) {
        data.withUnsafeBytes { ptr in
            var off = 0
            while off < data.count {
                let n = Darwin.write(master, ptr.baseAddress! + off, data.count - off)
                if n <= 0 { break }
                off += n
            }
        }
    }

    public func resize(rows: Int, cols: Int) {
        guard rows > 0, cols > 0, rows != terminal.rows || cols != terminal.cols else { return }
        var ws = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(master, TIOCSWINSZ, &ws)
        terminal.resize(cols: cols, rows: rows)
    }

    public func stop(signal sig: Int32 = SIGTERM) {
        guard status != .exited else { return }
        kill(pid, sig)
    }

    /// Full-screen state for a newly subscribed remote.
    func snapshot() -> Data { TerminalSnapshot.render(terminal) }

    public var state: BSSessionState {
        BSSessionState.with {
            $0.sessionID = id.rawValue
            $0.source = .hostSpawned
            $0.command = command.joined(separator: " ")
            $0.cwd = cwd
            $0.title = title
            $0.status = status
            $0.rows = UInt32(rows)
            $0.cols = UInt32(cols)
            $0.exitCode = exitCode
        }
    }
}

final class NullTerminalDelegate: TerminalDelegate {
    var title: String?
    func send(source: Terminal, data: ArraySlice<UInt8>) {}
    func setTerminalTitle(source: Terminal, title: String) { self.title = title }
}
