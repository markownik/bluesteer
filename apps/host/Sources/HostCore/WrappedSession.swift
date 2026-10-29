import BlueSteerProtocol
import Darwin
import Foundation

/// A terminal whose PTY belongs to another process: the `bluesteer run`
/// wrapper in the user's own terminal, or the detached helper behind a
/// host-spawned session. Output arrives over the socket; input (and, for
/// host-spawned sessions, resizes) go back the same way.
public final class WrappedSession: EmulatedSession, TerminalSession {
    public let id: SessionID
    public let hello: WrapperHello
    public var cwd: String
    public private(set) var status: BSSessionStatus = .busy
    public var onOutput: ((Data) -> Void)?
    public var onExit: (() -> Void)?
    private let fd: Int32

    public var pid: pid_t { hello.pid }
    /// Started by the host (through the helper) rather than in the user's terminal.
    public var isHostSpawned: Bool { hello.source == WrapperHello.hostSpawned }

    init(hello: WrapperHello, fd: Int32) {
        self.hello = hello
        id = SessionID(rawValue: hello.sessionId ?? UUID().uuidString)
        cwd = hello.cwd
        self.fd = fd
        super.init(rows: hello.rows, cols: hello.cols)
    }

    func received(_ frame: (type: UInt8, payload: Data)) {
        switch frame.type {
        case WrapperFrame.output:
            feed(frame.payload)
            onOutput?(frame.payload)
        case WrapperFrame.resize:
            if let d = try? JSONDecoder().decode([String: Int].self, from: frame.payload), let r = d["rows"], let c = d["cols"] {
                terminal.resize(cols: max(c, 2), rows: max(r, 2))
            }
        case WrapperFrame.screen:
            // The wrapper's own screen (with history) at attach time: replay it into our emulator.
            feed(frame.payload)
        default: break
        }
    }

    func closed() {
        status = .exited
        onExit?()
    }

    public func setStatus(_ status: BSSessionStatus) {
        guard self.status != .exited, status != .exited else { return }
        self.status = status
    }

    public func write(_ data: Data) { send(WrapperFrame.input, data) }

    /// Host-spawned sessions take the remote's size; a wrapped session keeps
    /// the real terminal's size and remotes follow it.
    public func resize(rows: Int, cols: Int) {
        guard isHostSpawned, rows > 0, cols > 0, rows != terminal.rows || cols != terminal.cols else { return }
        terminal.resize(cols: cols, rows: rows)
        send(WrapperFrame.resizeTo, Data("{\"rows\":\(rows),\"cols\":\(cols)}".utf8))
    }

    private func send(_ type: UInt8, _ payload: Data) {
        let frame = WrapperFrame.encode(type, payload)
        frame.withUnsafeBytes { _ = Darwin.send(fd, $0.baseAddress, frame.count, 0) }  // EPIPE ends the session via the reader
    }

    public func stop(signal: Int32) { kill(hello.pid, signal) }

    public var state: BSSessionState {
        BSSessionState.with {
            $0.sessionID = id.rawValue
            $0.source = isHostSpawned ? .hostSpawned : .wrapped
            $0.command = hello.command.joined(separator: " ")
            $0.cwd = cwd
            $0.title = title ?? hello.title ?? (hello.command.first as NSString?)?.lastPathComponent ?? ""
            $0.status = status
            $0.rows = UInt32(rows)
            $0.cols = UInt32(cols)
        }
    }
}

/// Listens on the local Unix socket for `bluesteer run` wrappers and session helpers.
public final class WrapperSocketServer {
    public var onSession: ((WrappedSession) -> Void)?
    public var onHook: ((HookEvent) -> Void)?
    private let path: String
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var connections: [Int32: (parser: WrapperFrameParser, session: WrappedSession?, source: DispatchSourceRead)] = [:]
    private let queue = DispatchQueue(label: "dev.bluesteer.wrapper")

    public init(path: String = WrapperSocket.path) { self.path = path }

    public func start() throws {
        unlink(path)
        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else { throw POSIXError(.EIO) }
        LocalSocket.harden(listenFD)
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = path.withCString { strlcpy(&addr.sun_path.0, $0, MemoryLayout.size(ofValue: addr.sun_path)) }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listenFD, $0, len) } }
        guard bound == 0, listen(listenFD, 8) == 0 else { throw POSIXError(.EADDRINUSE) }
        chmod(path, 0o600)
        let source = DispatchSource.makeReadSource(fileDescriptor: listenFD, queue: queue)
        source.setEventHandler { [weak self] in self?.accept() }
        source.setCancelHandler { [listenFD] in close(listenFD) }
        source.resume()
        acceptSource = source
    }

    /// Stops listening and drops every connection (their sessions end).
    public func stop() {
        queue.sync {
            acceptSource?.cancel()
            acceptSource = nil
            for (_, conn) in connections {
                conn.source.cancel()
                DispatchQueue.main.async { conn.session?.closed() }
            }
            connections.removeAll()
        }
        unlink(path)
    }

    private func accept() {
        let fd = Darwin.accept(listenFD, nil, nil)
        guard fd >= 0 else { return }
        // Only this user's processes may drive sessions or report hook events; the
        // kernel vouches for the peer (a shared token would be readable by them anyway).
        var uid = uid_t(), gid = gid_t()
        guard getpeereid(fd, &uid, &gid) == 0, uid == geteuid() else { close(fd); return }
        LocalSocket.harden(fd)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        connections[fd] = (WrapperFrameParser(), nil, source)
        source.setEventHandler { [weak self] in self?.readable(fd) }
        source.setCancelHandler { close(fd) }
        source.resume()
    }

    private func readable(_ fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 65536)
        let n = read(fd, &buf, buf.count)
        guard n > 0, var conn = connections[fd] else {
            if let conn = connections.removeValue(forKey: fd) {
                conn.source.cancel()
                DispatchQueue.main.async { conn.session?.closed() }
            }
            return
        }
        for frame in conn.parser.receive(Data(buf[0..<n])) {
            if frame.type == WrapperFrame.hello, conn.session == nil,
               let hello = try? JSONDecoder().decode(WrapperHello.self, from: frame.payload) {
                let session = WrappedSession(hello: hello, fd: fd)
                conn.session = session
                DispatchQueue.main.async { self.onSession?(session) }
            } else if frame.type == WrapperFrame.hook, let event = try? JSONDecoder().decode(HookEvent.self, from: frame.payload) {
                DispatchQueue.main.async { self.onHook?(event) }
            } else if let session = conn.session {
                DispatchQueue.main.async { session.received(frame) }
            }
        }
        connections[fd] = conn
    }
}
