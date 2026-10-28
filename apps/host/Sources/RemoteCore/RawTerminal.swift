import Darwin
import Foundation

/// The real terminal this process runs in: raw mode in, size out.
public struct RawTerminal {
    public let isTTY: Bool
    private var saved = termios()

    public init() {
        isTTY = isatty(STDIN_FILENO) == 1
        if isTTY { tcgetattr(STDIN_FILENO, &saved) }
    }

    /// Current size, or 120×40 when not a terminal.
    public static var size: (rows: Int, cols: Int) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != 0 || ws.ws_row == 0 { return (40, 120) }
        return (Int(ws.ws_row), Int(ws.ws_col))
    }

    /// The termios the child of a wrapper should start with.
    public var savedTermios: termios { saved }

    public func enterRaw() {
        guard isTTY else { return }
        var raw = saved
        cfmakeraw(&raw)
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
    }

    public func restore() {
        guard isTTY else { return }
        var t = saved
        tcsetattr(STDIN_FILENO, TCSANOW, &t)
    }

    /// Calls `handler` on `queue` whenever the terminal is resized.
    public static func onResize(queue: DispatchQueue, _ handler: @escaping () -> Void) -> DispatchSourceSignal {
        signal(SIGWINCH, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: queue)
        source.setEventHandler(handler: handler)
        source.resume()
        return source
    }

    public static func writeAll(_ fd: Int32, _ data: Data) {
        data.withUnsafeBytes { ptr in
            var off = 0
            while off < data.count {
                let n = write(fd, ptr.baseAddress! + off, data.count - off)
                if n <= 0 { break }
                off += n
            }
        }
    }
}
