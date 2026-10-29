import Darwin
import Foundation

/// The PTY owner's side of the wrapper socket. `bluesteer run` and the
/// session helper (`bluesteer serve-session`) use it to bridge a terminal to
/// the host app: connect, say hello, send the current screen, stream output,
/// and take input and resizes back. When the host goes away the terminal
/// keeps running and the client retries every second, so a session outlives a
/// host restart and re-attaches with its screen.
///
/// `hello` and `screen` are called on the client's own queue at every
/// (re)connect; callbacks arrive on that queue too.
public final class WrapperClient {
    public var onInput: ((Data) -> Void)?
    /// Rows and columns the host wants (host-spawned sessions follow the remote).
    public var onResize: ((Int, Int) -> Void)?

    private let path: String
    private let hello: () -> WrapperHello
    private let screen: () -> Data
    private let queue = DispatchQueue(label: "dev.bluesteer.wrapper-client")
    private var fd: Int32 = -1
    private var reader: DispatchSourceRead?
    private var retry: DispatchSourceTimer?
    private var parser = WrapperFrameParser()
    private var stopped = false

    public init(path: String = WrapperSocket.path, hello: @escaping () -> WrapperHello, screen: @escaping () -> Data) {
        self.path = path
        self.hello = hello
        self.screen = screen
    }

    /// Connects now if the host is there, otherwise keeps trying.
    public func start() { queue.async { self.connectNow() } }

    /// Disconnects after everything queued was written; `completion` runs on the client's queue.
    public func stop(completion: (() -> Void)? = nil) {
        queue.async {
            self.stopped = true
            self.retry?.cancel()
            self.retry = nil
            self.disconnect()
            completion?()
        }
    }

    /// Terminal output; dropped while the host is away (the screen catches it up).
    public func send(output: Data) { queue.async { self.write(WrapperFrame.output, output) } }

    /// The terminal's own size changed (wrapped sessions).
    public func send(rows: Int, cols: Int) {
        queue.async { self.write(WrapperFrame.resize, Data("{\"rows\":\(rows),\"cols\":\(cols)}".utf8)) }
    }

    private func connectNow() {
        guard !stopped, fd < 0 else { return }
        let s = socket(AF_UNIX, SOCK_STREAM, 0)
        guard s >= 0 else { scheduleRetry(); return }
        LocalSocket.harden(s)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = path.withCString { strlcpy(&addr.sun_path.0, $0, MemoryLayout.size(ofValue: addr.sun_path)) }
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard ok == 0 else { close(s); scheduleRetry(); return }
        fd = s
        parser = WrapperFrameParser()
        let source = DispatchSource.makeReadSource(fileDescriptor: s, queue: queue)
        source.setEventHandler { [weak self] in self?.readable() }
        source.setCancelHandler { close(s) }
        source.resume()
        reader = source
        write(WrapperFrame.hello, (try? JSONEncoder().encode(hello())) ?? Data())
        write(WrapperFrame.screen, screen())
    }

    private func readable() {
        guard fd >= 0 else { return }
        var buf = [UInt8](repeating: 0, count: 65536)
        let n = read(fd, &buf, buf.count)
        guard n > 0 else { lost(); return }
        for frame in parser.receive(Data(buf[0..<n])) {
            switch frame.type {
            case WrapperFrame.input:
                onInput?(frame.payload)
            case WrapperFrame.resizeTo:
                if let d = try? JSONDecoder().decode([String: Int].self, from: frame.payload), let r = d["rows"], let c = d["cols"] {
                    onResize?(r, c)
                }
            default:
                break
            }
        }
    }

    private func write(_ type: UInt8, _ payload: Data) {
        guard fd >= 0 else { return }
        let frame = WrapperFrame.encode(type, payload)
        var off = 0
        frame.withUnsafeBytes { ptr in
            while off < frame.count {
                let n = Darwin.send(fd, ptr.baseAddress! + off, frame.count - off, 0)
                if n <= 0 { break }
                off += n
            }
        }
        if off < frame.count { lost() }  // EPIPE: the host went away
    }

    /// The host is gone: drop the connection and try again in a second.
    private func lost() {
        disconnect()
        scheduleRetry()
    }

    private func disconnect() {
        guard fd >= 0 else { return }
        fd = -1
        reader?.cancel()  // its cancel handler closes the socket
        reader = nil
    }

    private func scheduleRetry() {
        guard !stopped, retry == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1)
        t.setEventHandler { [weak self] in
            self?.retry = nil
            self?.connectNow()
        }
        t.resume()
        retry = t
    }
}
