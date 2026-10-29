import BlueSteerProtocol
import CoreBluetooth
import Foundation
import Observation

/// Wires the BLE peripheral, the pairing store and one SecureChannel per link.
/// Observable so the menu-bar UI can show state directly.
@Observable
public final class HostController {
    public struct ConnectedRemote: Identifiable, Equatable {
        public let id: BLEPeripheralService.LinkID
        public var name: String
        public let key: Data
    }

    /// A remote pairing by code (SPEC.md §2.1b), waiting for both confirmations.
    public struct PendingPairing: Equatable {
        public let link: BLEPeripheralService.LinkID
        public let key: Data
        public var deviceName: String
        public let code: String
        public var remoteConfirmed = false
        public var hostConfirmed = false
        var confirmCmdID: UInt64 = 0
    }

    /// Handshake selector byte (SPEC.md §2.0).
    enum Selector: UInt8 { case psk = 0x01, paired = 0x02, code = 0x03 }

    static let pairingWindow: TimeInterval = 120

    public private(set) var bluetoothState: CBManagerState = .unknown
    public private(set) var connected: [ConnectedRemote] = []
    public private(set) var pairedRemotes: [PairingStore.Remote] = []
    /// True while new remotes may pair (the pairing window is open).
    public private(set) var pairingOpen = false
    /// Non-nil while pairing; the QR code encodes this.
    public private(set) var pairingPSK: Data?
    public private(set) var pendingPairing: PendingPairing?
    /// Name of the remote that paired in the current window, once one did.
    public private(set) var lastPairedName: String?
    /// Development aid (`BlueSteerHost --pair`): confirm code pairings without the window.
    public var autoConfirmPairing = false
    public let displayName: String

    private let store: PairingStore
    private let ble: BLEPeripheralService
    private let audit = AuditLog.shared
    public let hub = SessionHub()
    private let wrapperServer = WrapperSocketServer()
    private var channels: [BLEPeripheralService.LinkID: SecureChannel] = [:]
    private var selectors: [BLEPeripheralService.LinkID: Selector] = [:]
    /// Links waiting for their selector byte.
    private var awaitingSelector: Set<BLEPeripheralService.LinkID> = []
    /// Links ignored until the central reconnects (rejected or failed).
    private var dead: Set<BLEPeripheralService.LinkID> = []
    private var pairingTimer: Timer?
    private let instanceID: Data
    /// `NewSession` commands whose helper has not connected yet, by the session id we gave it.
    private var pendingSessions: [SessionID: (link: BLEPeripheralService.LinkID, cmdID: UInt64, timer: Timer)] = [:]
    static let sessionStartTimeout: TimeInterval = 10

    public init(store: PairingStore, displayName: String = ProcessInfo.processInfo.hostName) throws {
        self.store = store
        self.displayName = displayName
        pairedRemotes = store.remotes
        instanceID = Data(SHA256Digest(store.hostKey.publicKey).prefix(16))
        ble = BLEPeripheralService(protocolVersion: protocolVersion, instanceID: instanceID, displayName: displayName)
        ble.onStateChange = { [weak self] s in DispatchQueue.main.async { self?.bluetoothState = s } }
        ble.onLinkOpened = { [weak self] id in DispatchQueue.main.async { self?.linkOpened(id) } }
        ble.onLinkClosed = { [weak self] id in DispatchQueue.main.async { self?.linkClosed(id) } }
        ble.onBytes = { [weak self] id, bytes in DispatchQueue.main.async { self?.received(bytes, on: id) } }
        hub.send = { [weak self] envelope, link in
            do { try self?.send(envelope, to: link) } catch { log("link \(link) send failed: \(error)") }
        }
        hub.pendingBytes = { [weak self] link in self?.ble.pendingBytes(for: link) ?? 0 }
        hub.onSessionChanged = { [weak self] session in
            guard let self, hub.isCurrent(session) else { return }
            broadcast(BSEnvelope.with { $0.sessionState = session.state })
            if session.status == .exited {
                audit.record("session exited id=\(session.id.rawValue) code=\(session.state.exitCode)")
                hub.remove(session.id)
            }
        }
        hub.onSessionAdded = { [weak self] session in
            let st = session.state
            self?.audit.record("session started id=\(st.sessionID) source=\(st.source) command=\"\(st.command)\" cwd=\(st.cwd)")
        }
        hub.onSessionReattached = { [weak self] session in
            self?.audit.record("session re-attached id=\(session.id.rawValue) source=\(session.state.source)")
        }
        wrapperServer.onSession = { [weak self] session in
            guard let self else { return }
            hub.add(session)
            // A helper we started reports back: now the remote may subscribe.
            if let pending = pendingSessions.removeValue(forKey: session.id) {
                pending.timer.invalidate()
                try? ack(pending.cmdID, to: pending.link, sessionID: session.id)
            }
        }
        wrapperServer.onHook = { [weak self] event in self?.hub.hook(event) }
        try wrapperServer.start()
        audit.record("host started version=\(HostInfo.version) name=\"\(displayName)\"")
    }

    /// Commands the remote may start (SPEC.md §4.1: v1 is the login shell only).
    public static let presets: [String: [String]] = [
        "shell": [ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"],
    ]

    // MARK: Pairing

    /// Opens the pairing window: one new remote may pair by QR code or by code
    /// comparison within `pairingWindow` seconds. Returns the QR payload (SPEC.md §2.1).
    @discardableResult
    public func beginPairing() -> String {
        if let pending = pendingPairing { reject(pending) }
        pairingPSK = Self.randomPSK()
        pairingOpen = true
        lastPairedName = nil
        ble.setPairingOpen(true)
        pairingTimer?.invalidate()
        pairingTimer = Timer.scheduledTimer(withTimeInterval: Self.pairingWindow, repeats: false) { [weak self] _ in
            self?.endPairing()
        }
        return qrPayload!
    }

    public func endPairing() {
        if let pending = pendingPairing { reject(pending) }
        pairingTimer?.invalidate()
        pairingTimer = nil
        pairingPSK = nil
        pairingOpen = false
        ble.setPairingOpen(false)
    }

    public var qrPayload: String? {
        guard let psk = pairingPSK else { return nil }
        func b64(_ d: Data) -> String {
            d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        let name = displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "bluesteer://pair?v=\(protocolVersion)&id=\(b64(instanceID))&psk=\(b64(psk))&name=\(name)"
    }

    /// The Mac's user saw the same code on the remote.
    public func confirmPairing() {
        guard pendingPairing != nil else { return }
        pendingPairing!.hostConfirmed = true
        completePairingIfConfirmed()
    }

    /// The Mac's user rejected the remote (or the codes differed).
    public func rejectPairing() {
        guard let pending = pendingPairing else { return }
        reject(pending)
    }

    public func revoke(_ remote: PairingStore.Remote) {
        try? store.remove(key: remote.key)
        pairedRemotes = store.remotes
        audit.record("remote revoked name=\"\(remote.name)\" key=\(Self.keyPrefix(remote.key))")
        for link in connected.filter({ $0.key == remote.key }) { kill(link.id) }
    }

    private func reject(_ pending: PendingPairing) {
        if pending.remoteConfirmed { try? ack(pending.confirmCmdID, to: pending.link, error: "rejected") }
        audit.record("pairing rejected device=\"\(pending.deviceName)\" key=\(Self.keyPrefix(pending.key))")
        pendingPairing = nil
        kill(pending.link)
    }

    private func completePairingIfConfirmed() {
        guard let pending = pendingPairing, pending.remoteConfirmed, pending.hostConfirmed else { return }
        do {
            try store.add(key: pending.key, name: pending.deviceName)
        } catch {
            log("pairing store failed: \(error)")
            reject(pending)
            return
        }
        pairedRemotes = store.remotes
        pendingPairing = nil
        audit.record("remote paired by code device=\"\(pending.deviceName)\" key=\(Self.keyPrefix(pending.key))")
        finishPairing(name: pending.deviceName)
        establishedLink(pending.link, key: pending.key, name: pending.deviceName)
    }

    private func finishPairing(name: String) {
        lastPairedName = name
        pairingTimer?.invalidate()
        pairingTimer = nil
        pairingPSK = nil
        pairingOpen = false
        ble.setPairingOpen(false)
    }

    private static func randomPSK() -> Data {
        var psk = Data(count: 32)
        _ = psk.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        return psk
    }

    // MARK: Links

    private func linkOpened(_ id: BLEPeripheralService.LinkID) {
        // A central's identifier is stable across reconnects; a missed unsubscribe leaves stale state.
        if channels[id] != nil || selectors[id] != nil { linkClosed(id) }
        dead.remove(id)
        awaitingSelector.insert(id)
        log("link \(id) opened, pairing=\(pairingOpen)")
    }

    private func linkClosed(_ id: BLEPeripheralService.LinkID) {
        if let remote = connected.first(where: { $0.id == id }) {
            audit.record("remote disconnected name=\"\(remote.name)\" key=\(Self.keyPrefix(remote.key))")
        }
        channels[id] = nil
        selectors[id] = nil
        awaitingSelector.remove(id)
        dead.remove(id)
        connected.removeAll { $0.id == id }
        if pendingPairing?.link == id { pendingPairing = nil }
        hub.linkClosed(id)
    }

    /// Stops talking to a link until its central reconnects (a peripheral cannot disconnect it).
    private func kill(_ id: BLEPeripheralService.LinkID) {
        channels[id] = nil
        selectors[id] = nil
        awaitingSelector.remove(id)
        connected.removeAll { $0.id == id }
        hub.linkClosed(id)
        dead.insert(id)
    }

    private func received(_ bytes: Data, on id: BLEPeripheralService.LinkID) {
        guard !dead.contains(id) else { return }
        var bytes = bytes
        if channels[id] == nil {
            guard awaitingSelector.contains(id), let first = bytes.first else { return }
            awaitingSelector.remove(id)
            guard let selector = Selector(rawValue: first), let channel = openChannel(selector) else {
                log("link \(id) rejected selector \(first) (pairing=\(pairingOpen))")
                audit.record("handshake rejected link=\(id) reason=\"selector \(first) while pairing=\(pairingOpen)\"")
                kill(id)
                return
            }
            selectors[id] = selector
            channels[id] = channel
            bytes = bytes.dropFirst()
            if bytes.isEmpty { return }
        }
        guard let channel = channels[id], let selector = selectors[id] else { return }
        do {
            for event in try channel.receive(bytes) {
                switch event {
                case .send(let data):
                    ble.send(data, to: id)
                case .established(let key):
                    try established(id, key: key, selector: selector, channel: channel)
                case .message(let plaintext):
                    try handle(try BSEnvelope(serializedBytes: plaintext), from: id)
                }
            }
        } catch {
            // Any protocol error ends the link's session; the central will reconnect and re-handshake.
            log("link \(id) protocol error: \(error)")
            audit.record("handshake or protocol error link=\(id) mode=\(selector) error=\"\(error)\"")
            if pendingPairing?.link == id { pendingPairing = nil }
            kill(id)
            // A failed QR pairing invalidates its PSK (SPEC.md §2.1a).
            if selector == .psk, pairingOpen { pairingPSK = Self.randomPSK() }
        }
    }

    private func openChannel(_ selector: Selector) -> SecureChannel? {
        let role: SecureChannel.Role
        switch selector {
        case .psk:
            guard pairingOpen, let psk = pairingPSK else { return nil }
            role = .host(pairedKeys: store.pairedKeys, pairingPSK: psk)
        case .paired:
            role = .host(pairedKeys: store.pairedKeys, pairingPSK: nil)
        case .code:
            guard pairingOpen, pendingPairing == nil else { return nil }
            role = .host(pairedKeys: store.pairedKeys, pairingPSK: nil, acceptUnknownRemote: true)
        }
        return try? SecureChannel(role: role, staticKey: store.hostKey)
    }

    private func established(_ id: BLEPeripheralService.LinkID, key: Data, selector: Selector, channel: SecureChannel) throws {
        let known = store.remotes.first { $0.key == key }
        switch selector {
        case .psk:
            if known == nil { try store.add(key: key, name: "Remote") }
            pairedRemotes = store.remotes
            audit.record("remote paired by QR key=\(Self.keyPrefix(key))")
            finishPairing(name: known?.name ?? "Remote")
            establishedLink(id, key: key, name: known?.name ?? "Remote")
        case .paired:
            establishedLink(id, key: key, name: known?.name ?? "Remote")
        case .code:
            if let known {
                // An already paired remote chose the code flow: nothing to confirm.
                establishedLink(id, key: key, name: known.name)
                return
            }
            guard let hash = channel.handshakeHash else { throw SecureChannel.Error.protocolViolation }
            pendingPairing = PendingPairing(link: id, key: key, deviceName: "Remote",
                                            code: SecureChannel.pairingCode(handshakeHash: hash))
            log("link \(id) pairing by code \(pendingPairing!.code)")
            if autoConfirmPairing { print("PAIRING CODE \(pendingPairing!.code)"); confirmPairing() }
        }
    }

    private func establishedLink(_ id: BLEPeripheralService.LinkID, key: Data, name: String) {
        log("link \(id) established as \(name)")
        audit.record("remote connected name=\"\(name)\" key=\(Self.keyPrefix(key))")
        connected.append(ConnectedRemote(id: id, name: name, key: key))
        try? send(hello(), to: id)
    }

    private func handle(_ envelope: BSEnvelope, from id: BLEPeripheralService.LinkID) throws {
        if case .termInput = envelope.body {} else {
            log("link \(id) received \(envelope.body.map { String(describing: $0).prefix(60) } ?? "empty envelope")")
        }
        if pendingPairing?.link == id {
            // Until both sides confirm, only the pairing messages count (SPEC.md §2.1b).
            switch envelope.body {
            case .remoteHello(let hello):
                pendingPairing!.deviceName = hello.deviceName.isEmpty ? "Remote" : hello.deviceName
            case .pairConfirm(let cmd):
                pendingPairing!.remoteConfirmed = true
                pendingPairing!.confirmCmdID = cmd.cmdID
                completePairingIfConfirmed()
            default:
                break
            }
            return
        }
        switch envelope.body {
        case .remoteHello(let hello):
            guard let i = connected.firstIndex(where: { $0.id == id }), !hello.deviceName.isEmpty else { return }
            connected[i].name = hello.deviceName
            try store.rename(key: connected[i].key, name: hello.deviceName)
            pairedRemotes = store.remotes
            if lastPairedName == "Remote" { lastPairedName = hello.deviceName }
        case .ping(let ping):
            try send(BSEnvelope.with { $0.pong = BSPong.with { $0.nonce = ping.nonce } }, to: id)
        case .listSessions(let cmd):
            try ack(cmd.cmdID, to: id)
            try send(BSEnvelope.with { $0.sessionList = hub.sessionList }, to: id)
        case .newSession(let cmd):
            guard let command = Self.presets[cmd.preset] else { try ack(cmd.cmdID, to: id, error: "unknown preset \(cmd.preset)"); return }
            let cwd = cmd.cwd.isEmpty ? NSHomeDirectory() : cmd.cwd
            // The session runs in a detached helper that outlives us; the Ack waits for its hello.
            let sid = SessionID()
            do {
                try SessionLauncher.spawn(id: sid, command: command, cwd: cwd, rows: Int(cmd.rows), cols: Int(cmd.cols))
                let timer = Timer(timeInterval: Self.sessionStartTimeout, repeats: false) { [weak self] _ in
                    guard let self, let pending = pendingSessions.removeValue(forKey: sid) else { return }
                    log("session \(sid.rawValue) helper did not report back")
                    try? ack(pending.cmdID, to: pending.link, error: "the session helper did not start")
                }
                RunLoop.main.add(timer, forMode: .common)
                pendingSessions[sid] = (id, cmd.cmdID, timer)
            } catch {
                try ack(cmd.cmdID, to: id, error: error.localizedDescription)
            }
        case .subscribe(let cmd):
            let sid = SessionID(rawValue: cmd.sessionID)
            guard hub.sessions[sid] != nil else { try ack(cmd.cmdID, to: id, error: "no such session"); return }
            try ack(cmd.cmdID, to: id)
            hub.subscribe(link: id, session: sid, rows: Int(cmd.rows), cols: Int(cmd.cols), scrollbackLines: Int(cmd.scrollbackLines))
        case .unsubscribe(let cmd):
            hub.unsubscribe(link: id, session: SessionID(rawValue: cmd.sessionID))
            try ack(cmd.cmdID, to: id)
        case .termInput(let input):
            hub.input(input.data, session: SessionID(rawValue: input.sessionID))
        case .resize(let cmd):
            hub.resize(session: SessionID(rawValue: cmd.sessionID), rows: Int(cmd.rows), cols: Int(cmd.cols))
            try ack(cmd.cmdID, to: id)
        case .stopSession(let cmd):
            hub.stop(SessionID(rawValue: cmd.sessionID), signal: cmd.signal)
            try ack(cmd.cmdID, to: id)
        default:
            break
        }
    }

    private func ack(_ cmdID: UInt64, to id: BLEPeripheralService.LinkID, error: String? = nil, sessionID: SessionID? = nil) throws {
        try send(BSEnvelope.with {
            $0.ack = BSAck.with {
                $0.cmdID = cmdID
                $0.ok = error == nil
                $0.error = error ?? ""
                $0.sessionID = sessionID?.rawValue ?? ""
            }
        }, to: id)
    }

    private func broadcast(_ envelope: BSEnvelope) {
        for id in connected.map(\.id) { try? send(envelope, to: id) }
    }

    private func hello() -> BSEnvelope {
        BSEnvelope.with {
            $0.hostHello = BSHostHello.with {
                $0.protocolVersion = protocolVersion
                $0.hostName = displayName
                $0.hostVersion = HostInfo.version
            }
        }
    }

    private func send(_ envelope: BSEnvelope, to id: BLEPeripheralService.LinkID) throws {
        guard let channel = channels[id] else { return }
        ble.send(try channel.encrypt(try envelope.serializedData()), to: id)
    }

    static func keyPrefix(_ key: Data) -> String { String(key.base64EncodedString().prefix(8)) }
}

import CryptoKit
private func SHA256Digest(_ d: Data) -> Data { Data(SHA256.hash(data: d)) }
/// Unbuffered, timestamped diagnostics on stderr.
private func log(_ message: String) { fputs("\(logClock.string(from: Date())) [host] \(message)\n", stderr) }
private let logClock: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
