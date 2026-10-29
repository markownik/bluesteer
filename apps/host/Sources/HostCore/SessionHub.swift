import BlueSteerProtocol
import Foundation

/// Identifies one bridged terminal session.
public struct SessionID: Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String = UUID().uuidString) { self.rawValue = rawValue }
}

/// Owns all sessions and the per-remote subscriptions to their output.
/// Everything runs on the main queue.
public final class SessionHub {
    public typealias LinkID = UUID

    /// Un-sent bytes per link above which pending output is replaced by a snapshot (SPEC.md §5).
    static let backpressureLimit = 16 * 1024
    static let resumeBelow = 4 * 1024
    /// Largest compressed snapshot payload (SPEC.md §3); history is cut until it fits.
    static let snapshotLimit = 32 * 1024
    static let tick: TimeInterval = 0.05
    static let cwdPollInterval: TimeInterval = 2

    private final class Subscription {
        var deflate = DeflateStream()
        var pending = Data()
        var needsSnapshot = true
        /// History lines wanted in the first snapshot (SPEC.md §4.4); 0 afterwards.
        var scrollbackLines = 0
        var seq: UInt64 = 0
    }

    public private(set) var sessions: [SessionID: TerminalSession] = [:]
    private var subscriptions: [LinkID: [SessionID: Subscription]] = [:]
    private var timer: Timer?
    private var cwdTimer: Timer?

    /// Sends one envelope to a link.
    public var send: ((BSEnvelope, LinkID) -> Void)?
    /// Un-sent bytes queued for a link at the transport.
    public var pendingBytes: ((LinkID) -> Int)?
    /// Called when any session's state changes (for broadcasting SessionState).
    public var onSessionChanged: ((TerminalSession) -> Void)?
    /// Called once when a session is registered (audit).
    public var onSessionAdded: ((TerminalSession) -> Void)?

    public init() {}

    public var sessionList: BSSessionList {
        BSSessionList.with { $0.sessions = sessions.values.sorted { $0.id.rawValue < $1.id.rawValue }.map(\.state) }
    }

    // MARK: Sessions

    @discardableResult
    public func start(command: [String], cwd: String, rows: Int, cols: Int) throws -> PtySession {
        let session = try PtySession(command: command, cwd: cwd, rows: max(rows, 2), cols: max(cols, 2))
        add(session)
        return session
    }

    /// Registers any session (host-spawned or wrapped) and starts streaming it.
    public func add(_ session: TerminalSession) {
        sessions[session.id] = session
        session.onOutput = { [weak self, id = session.id] data in self?.output(data, from: id) }
        session.onExit = { [weak self, weak session] in
            guard let self, let session else { return }
            // Deliver the last output before anyone learns the session is gone.
            for link in subscriptions.keys { flush(link: link, session: session) }
            onSessionChanged?(session)
        }
        startTimer()
        onSessionAdded?(session)
        onSessionChanged?(session)
    }

    public func stop(_ id: SessionID, signal: Int32) {
        sessions[id]?.stop(signal: signal == 0 ? SIGTERM : signal)
    }

    /// Applies a Claude Code hook event to the session it came from (SPEC.md §4.1).
    public func hook(_ e: HookEvent) {
        guard let session = sessions[SessionID(rawValue: e.session)], session.status != .exited else { return }
        let status: BSSessionStatus?
        switch e.event {
        case "UserPromptSubmit": status = .busy
        case "Notification":
            switch e.notificationType {
            case "permission_prompt": status = .waitingPermission
            case "idle_prompt": status = .waitingInput
            default: status = nil
            }
        case "Stop", "SessionStart": status = .waitingInput
        case "SessionEnd": status = .idle
        default: status = nil
        }
        guard let status, status != session.status else { return }
        session.setStatus(status)
        onSessionChanged?(session)
    }

    /// Forgets an exited session.
    public func remove(_ id: SessionID) {
        guard sessions[id]?.status == .exited else { return }
        sessions[id] = nil
        for link in subscriptions.keys { subscriptions[link]?[id] = nil }
    }

    // MARK: Subscriptions

    public func subscribe(link: LinkID, session id: SessionID, rows: Int, cols: Int, scrollbackLines: Int = 0) {
        guard let session = sessions[id] else { return }
        session.resize(rows: rows, cols: cols)
        let sub = Subscription()
        sub.scrollbackLines = scrollbackLines
        subscriptions[link, default: [:]][id] = sub
        flush(link: link, session: session)
    }

    public func unsubscribe(link: LinkID, session id: SessionID) {
        subscriptions[link]?[id] = nil
    }

    public func linkClosed(_ link: LinkID) {
        subscriptions[link] = nil
    }

    public func input(_ data: Data, session id: SessionID) {
        sessions[id]?.write(data)
    }

    public func resize(session id: SessionID, rows: Int, cols: Int) {
        sessions[id]?.resize(rows: rows, cols: cols)
    }

    // MARK: Output pipeline

    private func output(_ data: Data, from id: SessionID) {
        for (_, subs) in subscriptions {
            if let sub = subs[id], !sub.needsSnapshot { sub.pending.append(data) }
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in self?.flushAll() }
        cwdTimer = Timer.scheduledTimer(withTimeInterval: Self.cwdPollInterval, repeats: true) { [weak self] _ in self?.pollCwds() }
    }

    /// Follows `cd` in each session so remotes can show the current directory.
    private func pollCwds() {
        for session in sessions.values where session.status != .exited {
            guard let cwd = Self.currentDirectory(of: session.pid), cwd != session.cwd else { continue }
            session.cwd = cwd
            onSessionChanged?(session)
        }
    }

    static func currentDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        return withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
    }

    private func flushAll() {
        for (link, subs) in subscriptions {
            for (id, _) in subs {
                if let session = sessions[id] { flush(link: link, session: session) }
            }
        }
    }

    private func flush(link: LinkID, session: TerminalSession) {
        guard let sub = subscriptions[link]?[session.id] else { return }
        let queued = pendingBytes?(link) ?? 0
        if queued > Self.backpressureLimit {
            // The link cannot keep up: drop what we buffered and start over from a snapshot.
            sub.pending.removeAll()
            sub.needsSnapshot = true
            return
        }
        if sub.needsSnapshot {
            guard queued < Self.resumeBelow else { return }
            sub.needsSnapshot = false
            sub.deflate = DeflateStream()
            sub.seq += 1
            var history = sub.scrollbackLines
            var vt = DeflateStream.compress(session.snapshot(scrollbackLines: history))
            while vt.count > Self.snapshotLimit && history > 0 {
                history /= 2
                vt = DeflateStream.compress(session.snapshot(scrollbackLines: history))
            }
            let snapshot = BSEnvelope.with {
                $0.termSnapshot = BSTermSnapshot.with {
                    $0.sessionID = session.id.rawValue
                    $0.seq = sub.seq
                    $0.rows = UInt32(session.rows)
                    $0.cols = UInt32(session.cols)
                    $0.vt = vt
                    $0.compressed = true
                }
            }
            // Only the first snapshot carries history; later ones keep the remote's own.
            sub.scrollbackLines = 0
            send?(snapshot, link)
            return
        }
        while !sub.pending.isEmpty {
            let piece = sub.pending.prefix(3000)
            sub.pending.removeFirst(piece.count)
            sub.seq += 1
            let out = BSEnvelope.with {
                $0.termOutput = BSTermOutput.with {
                    $0.sessionID = session.id.rawValue
                    $0.seq = sub.seq
                    $0.data = sub.deflate.push(piece)
                    $0.compressed = true
                }
            }
            send?(out, link)
        }
    }
}
