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
    }

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
        channels[id] = try? SecureChannel(role: .host(pairedKeys: store.pairedKeys, pairingPSK: pairingPSK),
                                          staticKey: store.hostKey)
    }

    private func linkClosed(_ id: BLEPeripheralService.LinkID) {
        channels[id] = nil
        connected.removeAll { $0.id == id }
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
                    connected.append(ConnectedRemote(id: id, name: name, key: key))
                    try send(hello(), to: id)
                case .message(let plaintext):
                    try handle(try BSEnvelope(serializedBytes: plaintext), from: id)
                }
            }
        } catch {
            // Any protocol error ends the link's session; the central will reconnect and re-handshake.
            channels[id] = nil
            connected.removeAll { $0.id == id }
        }
    }

    private func handle(_ envelope: BSEnvelope, from id: BLEPeripheralService.LinkID) throws {
        switch envelope.body {
        case .ping(let ping):
            try send(BSEnvelope.with { $0.pong = BSPong.with { $0.nonce = ping.nonce } }, to: id)
        case .listSessions(let cmd):
            try send(BSEnvelope.with { $0.ack = BSAck.with { $0.cmdID = cmd.cmdID; $0.ok = true } }, to: id)
            try send(BSEnvelope.with { $0.sessionList = BSSessionList() }, to: id)
        default:
            break // Phase 2: sessions
        }
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
