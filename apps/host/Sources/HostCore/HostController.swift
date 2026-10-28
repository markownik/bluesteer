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
        public let name: String
        public let key: Data
    }

    public private(set) var bluetoothState: CBManagerState = .unknown
    public private(set) var connected: [ConnectedRemote] = []
    public private(set) var pairedRemotes: [PairingStore.Remote] = []
    /// Non-nil while a new remote may pair; the QR code encodes this.
    public private(set) var pairingPSK: Data?
    public let displayName: String

    private let store: PairingStore
    private let ble: BLEPeripheralService
    public let hub = SessionHub()
    private let wrapperServer = WrapperSocketServer()
    private var channels: [BLEPeripheralService.LinkID: SecureChannel] = [:]
    private var pendingHello: [BLEPeripheralService.LinkID: String] = [:]
    private let instanceID: Data

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
        hub.send = { [weak self] envelope, link in try? self?.send(envelope, to: link) }
        hub.pendingBytes = { [weak self] link in self?.ble.pendingBytes(for: link) ?? 0 }
        hub.onSessionChanged = { [weak self] session in
            guard let self else { return }
            broadcast(BSEnvelope.with { $0.sessionState = session.state })
            if session.status == .exited { hub.remove(session.id) }
        }
        wrapperServer.onSession = { [weak self] session in self?.hub.add(session) }
        try wrapperServer.start()
    }

    /// Commands the remote may start (SPEC.md §4.1: v1 is the login shell only).
    public static let presets: [String: [String]] = [
        "shell": [ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"],
    ]

    // MARK: Pairing

    /// Starts accepting one new remote. Returns the QR payload (SPEC.md §2.1).
    @discardableResult
    public func beginPairing() -> String {
        var psk = Data(count: 32)
        _ = psk.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        pairingPSK = psk
        return qrPayload!
    }

    public func endPairing() { pairingPSK = nil }

    public var qrPayload: String? {
        guard let psk = pairingPSK else { return nil }
        func b64(_ d: Data) -> String {
            d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        let name = displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "bluesteer://pair?v=\(protocolVersion)&id=\(b64(instanceID))&psk=\(b64(psk))&name=\(name)"
    }

    /// Eight-digit fallback code for manual entry (first 8 digits of the PSK as a decimal number).
    public var pairingCode: String? {
        guard let psk = pairingPSK else { return nil }
        let digits = psk.reduce(into: "") { $0 += String($1) }
        return String(digits.prefix(8))
    }

    public func revoke(_ remote: PairingStore.Remote) {
        try? store.remove(key: remote.key)
        pairedRemotes = store.remotes
    }

    // MARK: Links

    private func linkOpened(_ id: BLEPeripheralService.LinkID) {
        log("link \(id) opened, pairing=\(pairingPSK != nil)")
        channels[id] = try? SecureChannel(role: .host(pairedKeys: store.pairedKeys, pairingPSK: pairingPSK),
                                          staticKey: store.hostKey)
    }

    private func linkClosed(_ id: BLEPeripheralService.LinkID) {
        channels[id] = nil
        connected.removeAll { $0.id == id }
        hub.linkClosed(id)
    }

    private func received(_ bytes: Data, on id: BLEPeripheralService.LinkID) {
        guard let channel = channels[id] else { return }
        do {
            for event in try channel.receive(bytes) {
                switch event {
                case .send(let data):
                    ble.send(data, to: id)
                case .established(let key):
                    if pairingPSK != nil, !store.pairedKeys.contains(key) {
                        try store.add(key: key, name: "Remote")
                        pairedRemotes = store.remotes
                        pairingPSK = nil
                    }
                    let name = store.remotes.first { $0.key == key }?.name ?? "Remote"
                    log("link \(id) established as \(name)")
                    connected.append(ConnectedRemote(id: id, name: name, key: key))
                    try send(hello(), to: id)
                case .message(let plaintext):
                    try handle(try BSEnvelope(serializedBytes: plaintext), from: id)
                }
            }
        } catch {
            // Any protocol error ends the link's session; the central will reconnect and re-handshake.
            log("link \(id) protocol error: \(error)")
            channels[id] = nil
            connected.removeAll { $0.id == id }
        }
    }

    private func handle(_ envelope: BSEnvelope, from id: BLEPeripheralService.LinkID) throws {
        switch envelope.body {
        case .ping(let ping):
            try send(BSEnvelope.with { $0.pong = BSPong.with { $0.nonce = ping.nonce } }, to: id)
        case .listSessions(let cmd):
            try ack(cmd.cmdID, to: id)
            try send(BSEnvelope.with { $0.sessionList = hub.sessionList }, to: id)
        case .newSession(let cmd):
            guard let command = Self.presets[cmd.preset] else { try ack(cmd.cmdID, to: id, error: "unknown preset \(cmd.preset)"); return }
            let cwd = cmd.cwd.isEmpty ? NSHomeDirectory() : cmd.cwd
            do {
                let session = try hub.start(command: command, cwd: cwd, rows: Int(cmd.rows), cols: Int(cmd.cols))
                try ack(cmd.cmdID, to: id, sessionID: session.id)
            } catch {
                try ack(cmd.cmdID, to: id, error: "\(error)")
            }
        case .subscribe(let cmd):
            let sid = SessionID(rawValue: cmd.sessionID)
            guard hub.sessions[sid] != nil else { try ack(cmd.cmdID, to: id, error: "no such session"); return }
            try ack(cmd.cmdID, to: id)
            hub.subscribe(link: id, session: sid, rows: Int(cmd.rows), cols: Int(cmd.cols))
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
        for id in channels.keys { try? send(envelope, to: id) }
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
}

import CryptoKit
private func SHA256Digest(_ d: Data) -> Data { Data(SHA256.hash(data: d)) }
/// Unbuffered diagnostics on stderr.
private func log(_ message: String) { fputs("[host] \(message)\n", stderr) }
