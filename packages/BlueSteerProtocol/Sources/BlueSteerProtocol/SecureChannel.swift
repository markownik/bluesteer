import CryptoKit
import Foundation

/// One end of an encrypted BlueSteer link (SPEC.md §2–3), independent of the
/// transport: feed it the bytes that arrive and write out the bytes it returns.
///
/// Handshake messages and transport messages all use the 2-byte length framing,
/// so a BLE byte stream can be fed in arbitrary chunks via `receive(_:)`.
public final class SecureChannel {
    public static let prologue = Data("bluesteer/1".utf8)

    public enum Role {
        /// The Mac. `pairedKeys` are accepted remote static keys; `pairingPSK`
        /// (when set) allows one new remote to pair with `Noise_XXpsk3`;
        /// `acceptUnknownRemote` allows one to pair by code (SPEC.md §2.1b).
        case host(pairedKeys: Set<Data>, pairingPSK: Data?, acceptUnknownRemote: Bool = false)
        /// A remote. `pinnedHostKey` is the host's static key from pairing;
        /// `pairingPSK` is set while pairing (from the QR code).
        case remote(pinnedHostKey: Data?, pairingPSK: Data?)
    }

    public enum Event: Equatable {
        /// Bytes to write to the peer (handshake replies).
        case send(Data)
        /// The handshake finished; the peer's static key is authenticated.
        case established(remoteStaticKey: Data)
        /// A decrypted application message.
        case message(Data)
    }

    public enum Error: Swift.Error, Equatable {
        case unknownRemote
        case hostKeyMismatch
        case notEstablished
        case protocolViolation
    }

    public let role: Role
    private var handshake: NoiseHandshake?
    private var send: NoiseCipherState?
    private var receive: NoiseCipherState?
    private var framer = Framer()
    public private(set) var remoteStaticKey: Data?
    /// The Noise handshake hash, available once established (pairing code, SPEC.md §2.1b).
    public private(set) var handshakeHash: Data?

    public var isEstablished: Bool { send != nil }

    /// Six-digit pairing code both sides derive from the handshake hash (SPEC.md §2.1b).
    public static func pairingCode(handshakeHash h: Data) -> String {
        let digest = SHA256.hash(data: Data("bluesteer pair code".utf8) + h)
        let n = digest.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return String(format: "%06d", n % 1_000_000)
    }

    public init(role: Role, staticKey: NoiseKeyPair) throws {
        self.role = role
        let pairing: Bool
        let psk: Data?
        let initiator: Bool
        switch role {
        case .host(_, let p, _): pairing = p != nil; psk = p; initiator = false
        case .remote(_, let p): pairing = p != nil; psk = p; initiator = true
        }
        handshake = try NoiseHandshake(pattern: pairing ? .xxpsk3 : .xx, initiator: initiator,
                                       prologue: Self.prologue, staticKey: staticKey, psk: psk)
    }

    /// The initiator (remote) calls this once to get the first bytes to send.
    public func start() throws -> Data {
        guard var hs = handshake, hs.isInitiator else { throw Error.protocolViolation }
        let m = try hs.writeMessage()
        handshake = hs
        return try Framing.frame(m)
    }

    /// Feeds bytes from the peer; returns what happened, in order.
    public func receive(_ bytes: Data) throws -> [Event] {
        var events: [Event] = []
        for frame in framer.receive(bytes) {
            if var hs = handshake {
                _ = try hs.readMessage(frame)
                try checkPeer(hs.remoteStatic)
                if !hs.isComplete {
                    events.append(.send(try Framing.frame(try hs.writeMessage())))
                }
                if hs.isComplete {
                    finish(hs)
                    events.append(.established(remoteStaticKey: remoteStaticKey!))
                } else {
                    handshake = hs
                }
            } else if var rx = receive {
                let plain = try rx.decrypt(ciphertext: frame)
                receive = rx
                events.append(.message(plain))
            } else {
                throw Error.notEstablished
            }
        }
        return events
    }

    /// Encrypts and frames one application message.
    public func encrypt(_ plaintext: Data) throws -> Data {
        guard var tx = send else { throw Error.notEstablished }
        let c = try tx.encrypt(plaintext: plaintext)
        send = tx
        return try Framing.frame(c)
    }

    private func checkPeer(_ key: Data?) throws {
        guard let key else { return }
        switch role {
        case .host(let paired, let psk, let acceptUnknown):
            if psk == nil && !acceptUnknown && !paired.contains(key) { throw Error.unknownRemote }
        case .remote(let pinned, let psk):
            if psk == nil, let pinned, pinned != key { throw Error.hostKeyMismatch }
        }
    }

    private func finish(_ hs: NoiseHandshake) {
        let states = try! hs.split()
        send = states.send
        receive = states.receive
        remoteStaticKey = hs.remoteStatic
        handshakeHash = hs.handshakeHash
        handshake = nil
    }
}
