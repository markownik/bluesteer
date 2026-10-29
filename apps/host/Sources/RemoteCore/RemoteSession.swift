import BlueSteerProtocol
import Foundation
import HostCore

/// A byte stream to one host (a BLE link, or a pipe in tests). Callbacks
/// arrive on the session's queue.
public protocol RemoteTransport: AnyObject {
    var onData: ((Data) -> Void)? { get set }
    var onClosed: (() -> Void)? { get set }
    func write(_ data: Data)
    func close()
}

/// The remote end of SPEC.md §2–4 on top of a transport: selector byte,
/// handshake, hellos, pairing by code, then envelopes. Call everything on `queue`.
public final class RemoteSession {
    public enum Mode {
        case psk(Data)
        case paired(hostKey: Data)
        case code
        var selector: UInt8 {
            switch self { case .psk: 0x01; case .paired: 0x02; case .code: 0x03 }
        }
    }

    public enum Error: Swift.Error, LocalizedError {
        case rejected(String)
        case closed
        /// The Mac speaks another protocol version (SPEC.md §7).
        case protocolMismatch(UInt32)
        public var errorDescription: String? {
            switch self {
            case .rejected(let why): "the Mac did not accept the pairing: \(why)"
            case .closed: "the link closed"
            case .protocolMismatch(let v):
                v > protocolVersion ? "the Mac runs a newer BlueSteer (protocol \(v)); update this tool"
                                    : "the Mac runs an older BlueSteer (protocol \(v)); update BlueSteer there"
            }
        }
    }

    public let queue: DispatchQueue
    public let mode: Mode
    public private(set) var hostHello: BSHostHello?
    public var hostKey: Data? { channel.remoteStaticKey }
    /// Pairing by code: the code to compare, set once the handshake completes.
    public private(set) var pairingCode: String?

    /// Fired once `HostHello` arrived (the host accepted us).
    public var onReady: (() -> Void)?
    /// Pairing by code: the code is known; show it and call `confirmPairing()`.
    public var onPairingCode: ((String) -> Void)?
    public var onEnvelope: ((BSEnvelope) -> Void)?
    public var onError: ((Swift.Error) -> Void)?
    public var onClosed: (() -> Void)?

    private let transport: RemoteTransport
    private let channel: SecureChannel
    private let deviceName: String
    private var cmdID: UInt64 = 1

    public init(transport: RemoteTransport, identity: NoiseKeyPair, deviceName: String, mode: Mode, queue: DispatchQueue) throws {
        self.transport = transport
        self.deviceName = deviceName
        self.mode = mode
        self.queue = queue
        let role: SecureChannel.Role
        switch mode {
        case .psk(let psk): role = .remote(pinnedHostKey: nil, pairingPSK: psk)
        case .paired(let key): role = .remote(pinnedHostKey: key, pairingPSK: nil)
        case .code: role = .remote(pinnedHostKey: nil, pairingPSK: nil)
        }
        channel = try SecureChannel(role: role, staticKey: identity)
        transport.onData = { [weak self] data in self?.received(data) }
        transport.onClosed = { [weak self] in self?.onClosed?() }
    }

    /// Writes the selector byte and Noise message 1.
    public func start() throws {
        transport.write(Data([mode.selector]) + (try channel.start()))
    }

    public func nextCommandID() -> UInt64 { defer { cmdID += 1 }; return cmdID }

    public func send(_ envelope: BSEnvelope) throws {
        transport.write(try channel.encrypt(try envelope.serializedData()))
    }

    /// Pairing by code: the user saw the same code on the Mac.
    public func confirmPairing() throws {
        try send(BSEnvelope.with { $0.pairConfirm = BSPairConfirm.with { $0.cmdID = self.nextCommandID() } })
    }

    public func close() { transport.close() }

    private func received(_ data: Data) {
        do {
            for event in try channel.receive(data) {
                switch event {
                case .send(let bytes):
                    transport.write(bytes)
                case .established:
                    try send(BSEnvelope.with {
                        $0.remoteHello = BSRemoteHello.with {
                            $0.protocolVersion = protocolVersion
                            $0.deviceName = deviceName
                            $0.appVersion = HostInfo.version
                        }
                    })
                    if case .code = mode, let hash = channel.handshakeHash {
                        pairingCode = SecureChannel.pairingCode(handshakeHash: hash)
                        onPairingCode?(pairingCode!)
                    }
                case .message(let plaintext):
                    let envelope = try BSEnvelope(serializedBytes: plaintext)
                    if hostHello == nil {
                        if case .hostHello(let hello) = envelope.body {
                            guard hello.protocolVersion == protocolVersion else { throw Error.protocolMismatch(hello.protocolVersion) }
                            hostHello = hello
                            onReady?()
                            continue
                        }
                        if case .ack(let ack) = envelope.body, !ack.ok {
                            throw Error.rejected(ack.error.isEmpty ? "rejected" : ack.error)
                        }
                    }
                    onEnvelope?(envelope)
                }
            }
        } catch {
            onError?(error)
        }
    }
}
