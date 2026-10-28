import BlueSteerProtocol
import Darwin
import Foundation

/// Attaches this terminal to one session on the host: snapshot and output to
/// stdout, keystrokes to the session, SIGWINCH as Resize. Ctrl-] detaches.
public final class TerminalAttach {
    public static let detachKey: UInt8 = 0x1d  // Ctrl-]
    public static let scrollbackLines: UInt32 = 500

    public enum Outcome { case detached, sessionExited(Int32), linkLost, error(Swift.Error) }

    private let session: RemoteSession
    private let sessionID: String
    private let queue: DispatchQueue
    private var inflater = InflateStream()
    private var lastSeq: UInt64 = 0
    private var subscribeCmd: UInt64 = 0
    private var finished: ((Outcome) -> Void)?
    private var winch: DispatchSourceSignal?
    private var stdinSource: DispatchSourceRead?

    public init(session: RemoteSession, sessionID: String) {
        self.session = session
        self.sessionID = sessionID
        queue = session.queue
    }

    /// Subscribes and runs until detach, exit or link loss. Call on the session's queue;
    /// `completion` runs there too. The terminal must already be in raw mode.
    public func run(completion: @escaping (Outcome) -> Void) {
        finished = completion
        session.onEnvelope = { [weak self] e in self?.handle(e) }
        session.onClosed = { [weak self] in self?.finish(.linkLost) }
        session.onError = { [weak self] e in self?.finish(.error(e)) }
        winch = RawTerminal.onResize(queue: queue) { [weak self] in
            guard let self else { return }
            let size = RawTerminal.size
            try? session.send(BSEnvelope.with {
                $0.resize = BSResize.with { $0.cmdID = self.session.nextCommandID(); $0.sessionID = self.sessionID; $0.rows = UInt32(size.rows); $0.cols = UInt32(size.cols) }
            })
        }
        let source = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: queue)
        source.setEventHandler { [weak self] in self?.readStdin() }
        source.resume()
        stdinSource = source
        subscribe()
    }

    private func subscribe() {
        let size = RawTerminal.size
        subscribeCmd = session.nextCommandID()
        try? session.send(BSEnvelope.with {
            $0.subscribe = BSSubscribe.with {
                $0.cmdID = self.subscribeCmd; $0.sessionID = self.sessionID
                $0.rows = UInt32(size.rows); $0.cols = UInt32(size.cols); $0.scrollbackLines = Self.scrollbackLines
            }
        })
    }

    private func readStdin() {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(STDIN_FILENO, &buf, buf.count)
        guard n > 0 else { finish(.detached); return }
        var bytes = buf[0..<n]
        if let i = bytes.firstIndex(of: Self.detachKey) {
            bytes = bytes[bytes.startIndex..<i]
            if !bytes.isEmpty { send(Data(bytes)) }
            finish(.detached)
            return
        }
        send(Data(bytes))
    }

    private func send(_ input: Data) {
        try? session.send(BSEnvelope.with { $0.termInput = BSTermInput.with { $0.sessionID = self.sessionID; $0.data = input } })
    }

    private func handle(_ e: BSEnvelope) {
        switch e.body {
        case .termSnapshot(let snap) where snap.sessionID == sessionID:
            inflater = InflateStream()
            var vt = snap.compressed ? InflateStream.inflateAll(snap.vt) : snap.vt
            // Keep this terminal's own history: the host's "erase scrollback" is for emulators we own.
            vt = Data(String(decoding: vt, as: UTF8.self).replacingOccurrences(of: "\u{1b}[3J", with: "").utf8)
            RawTerminal.writeAll(STDOUT_FILENO, vt)
            lastSeq = snap.seq
        case .termOutput(let out) where out.sessionID == sessionID:
            guard out.seq == lastSeq + 1 else { subscribe(); return }
            lastSeq = out.seq
            RawTerminal.writeAll(STDOUT_FILENO, out.compressed ? inflater.push(out.data) : out.data)
        case .sessionState(let st) where st.sessionID == sessionID && st.status == .exited:
            finish(.sessionExited(st.exitCode))
        case .ack(let ack) where ack.cmdID == subscribeCmd && !ack.ok:
            finish(.error(RemoteSession.Error.rejected(ack.error)))
        default:
            break
        }
    }

    private func finish(_ outcome: Outcome) {
        guard let f = finished else { return }
        finished = nil
        stdinSource?.cancel()
        winch?.cancel()
        session.onEnvelope = nil
        f(outcome)
    }
}
