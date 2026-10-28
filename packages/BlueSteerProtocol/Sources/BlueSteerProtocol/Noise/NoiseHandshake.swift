import CryptoKit
import Foundation

// Noise Protocol Framework (revision 34) for the two patterns BlueSteer uses:
// Noise_XX_25519_ChaChaPoly_SHA256 and Noise_XXpsk3_25519_ChaChaPoly_SHA256
// (SPEC.md §2). Verified against protocol/testvectors/noise.

public enum NoiseError: Error, Equatable {
    case handshakeComplete
    case notYourTurn
    case messageTooShort
    case decryptionFailed
    case missingStaticKey
    case missingPSK
    case nonceExhausted
    case messageTooLong
}

public enum NoisePattern: String, Sendable {
    case xx = "Noise_XX_25519_ChaChaPoly_SHA256"
    case xxpsk3 = "Noise_XXpsk3_25519_ChaChaPoly_SHA256"

    /// Message patterns, initiator writes first. "psk" is a token like any other.
    var messages: [[String]] {
        switch self {
        case .xx: return [["e"], ["e", "ee", "s", "es"], ["s", "se"]]
        case .xxpsk3: return [["e"], ["e", "ee", "s", "es"], ["s", "se", "psk"]]
        }
    }

    var usesPSK: Bool { self == .xxpsk3 }
}

/// A Curve25519 static or ephemeral key pair.
public struct NoiseKeyPair: Sendable {
    public let privateKey: Curve25519.KeyAgreement.PrivateKey
    public var publicKey: Data { privateKey.publicKey.rawRepresentation }

    public init() { privateKey = Curve25519.KeyAgreement.PrivateKey() }
    public init(privateKey raw: Data) throws { privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) }

    func dh(_ remotePublic: Data) throws -> Data {
        let pub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remotePublic)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: pub)
        return secret.withUnsafeBytes { Data($0) }
    }
}

// MARK: - CipherState

/// AEAD state for one direction of a Noise session.
public struct NoiseCipherState {
    private var key: SymmetricKey?
    private var nonce: UInt64 = 0

    init(key: Data? = nil) { self.key = key.map { SymmetricKey(data: $0) } }

    public var hasKey: Bool { key != nil }

    private func nonceData() -> Data {
        var d = Data(repeating: 0, count: 4)
        var n = nonce.littleEndian
        withUnsafeBytes(of: &n) { d.append(contentsOf: $0) }
        return d
    }

    public mutating func encrypt(plaintext: Data, ad: Data = Data()) throws -> Data {
        guard let key else { return plaintext }
        guard nonce != UInt64.max else { throw NoiseError.nonceExhausted }
        let box = try ChaChaPoly.seal(plaintext, using: key, nonce: ChaChaPoly.Nonce(data: nonceData()), authenticating: ad)
        nonce += 1
        var out = Data(box.ciphertext)   // fresh Data: SealedBox slices keep their startIndex
        out.append(box.tag)
        return out
    }

    public mutating func decrypt(ciphertext: Data, ad: Data = Data()) throws -> Data {
        guard let key else { return ciphertext }
        guard nonce != UInt64.max else { throw NoiseError.nonceExhausted }
        guard ciphertext.count >= 16 else { throw NoiseError.messageTooShort }
        let box = try ChaChaPoly.SealedBox(nonce: ChaChaPoly.Nonce(data: nonceData()),
                                           ciphertext: ciphertext.prefix(ciphertext.count - 16),
                                           tag: ciphertext.suffix(16))
        guard let plain = try? ChaChaPoly.open(box, using: key, authenticating: ad) else { throw NoiseError.decryptionFailed }
        nonce += 1
        return plain
    }
}

// MARK: - SymmetricState

struct SymmetricState {
    private(set) var chainingKey: Data
    private(set) var hash: Data
    var cipher = NoiseCipherState()

    init(protocolName: String) {
        let name = Data(protocolName.utf8)
        hash = name.count <= 32 ? name + Data(repeating: 0, count: 32 - name.count) : Data(SHA256.hash(data: name))
        chainingKey = hash
    }

    private static func hmac(_ key: Data, _ data: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key)))
    }

    /// Noise HKDF: returns `outputs` keys derived from chaining key and input material.
    private static func hkdf(_ ck: Data, _ input: Data, outputs: Int) -> [Data] {
        let temp = hmac(ck, input)
        var out: [Data] = [hmac(temp, Data([1]))]
        for i in 2...max(2, outputs) {
            out.append(hmac(temp, out[i - 2] + Data([UInt8(i)])))
        }
        return Array(out.prefix(outputs))
    }

    mutating func mixKey(_ input: Data) {
        let k = Self.hkdf(chainingKey, input, outputs: 2)
        chainingKey = k[0]
        cipher = NoiseCipherState(key: k[1])
    }

    mutating func mixHash(_ data: Data) {
        hash = Data(SHA256.hash(data: hash + data))
    }

    mutating func mixKeyAndHash(_ input: Data) {
        let k = Self.hkdf(chainingKey, input, outputs: 3)
        chainingKey = k[0]
        mixHash(k[1])
        cipher = NoiseCipherState(key: k[2])
    }

    mutating func encryptAndHash(_ plaintext: Data) throws -> Data {
        let ciphertext = try cipher.encrypt(plaintext: plaintext, ad: hash)
        mixHash(ciphertext)
        return ciphertext
    }

    mutating func decryptAndHash(_ ciphertext: Data) throws -> Data {
        let plaintext = try cipher.decrypt(ciphertext: ciphertext, ad: hash)
        mixHash(ciphertext)
        return plaintext
    }

    func split() -> (NoiseCipherState, NoiseCipherState) {
        let k = Self.hkdf(chainingKey, Data(), outputs: 2)
        return (NoiseCipherState(key: k[0]), NoiseCipherState(key: k[1]))
    }
}

// MARK: - HandshakeState

/// Drives one Noise handshake. Call `writeMessage`/`readMessage` alternately
/// starting with the initiator; when `isComplete`, call `split()`.
public struct NoiseHandshake {
    public let pattern: NoisePattern
    public let isInitiator: Bool
    private var symmetric: SymmetricState
    private let s: NoiseKeyPair
    private var e: NoiseKeyPair?
    private(set) public var remoteStatic: Data?
    private var remoteEphemeral: Data?
    private let psk: Data?
    private var remaining: [[String]]
    private var myTurn: Bool

    /// - Parameters:
    ///   - ephemeral: only for tests; a fresh key is generated otherwise.
    public init(pattern: NoisePattern, initiator: Bool, prologue: Data, staticKey: NoiseKeyPair,
                psk: Data? = nil, ephemeral: NoiseKeyPair? = nil) throws {
        if pattern.usesPSK { guard let psk, psk.count == 32 else { throw NoiseError.missingPSK } }
        self.pattern = pattern
        self.isInitiator = initiator
        self.s = staticKey
        self.e = ephemeral
        self.psk = psk
        self.remaining = pattern.messages
        self.myTurn = initiator
        symmetric = SymmetricState(protocolName: pattern.rawValue)
        symmetric.mixHash(prologue)
    }

    public var isComplete: Bool { remaining.isEmpty }
    public var handshakeHash: Data { symmetric.hash }

    public mutating func writeMessage(payload: Data = Data()) throws -> Data {
        guard !remaining.isEmpty else { throw NoiseError.handshakeComplete }
        guard myTurn else { throw NoiseError.notYourTurn }
        var out = Data()
        for token in remaining.removeFirst() {
            switch token {
            case "e":
                if e == nil { e = NoiseKeyPair() }
                out += e!.publicKey
                symmetric.mixHash(e!.publicKey)
                if pattern.usesPSK { symmetric.mixKey(e!.publicKey) }
            case "s":
                out += try symmetric.encryptAndHash(s.publicKey)
            case "ee": symmetric.mixKey(try e!.dh(remoteEphemeral!))
            case "es": symmetric.mixKey(isInitiator ? try e!.dh(remoteStatic!) : try s.dh(remoteEphemeral!))
            case "se": symmetric.mixKey(isInitiator ? try s.dh(remoteEphemeral!) : try e!.dh(remoteStatic!))
            case "ss": symmetric.mixKey(try s.dh(remoteStatic!))
            case "psk": symmetric.mixKeyAndHash(psk!)
            default: fatalError("unknown token \(token)")
            }
        }
        out += try symmetric.encryptAndHash(payload)
        guard out.count <= 65535 else { throw NoiseError.messageTooLong }
        myTurn = false
        return out
    }

    public mutating func readMessage(_ message: Data) throws -> Data {
        guard !remaining.isEmpty else { throw NoiseError.handshakeComplete }
        guard !myTurn else { throw NoiseError.notYourTurn }
        var cursor = message.startIndex
        func take(_ n: Int) throws -> Data {
            guard message.endIndex - cursor >= n else { throw NoiseError.messageTooShort }
            defer { cursor += n }
            return Data(message[cursor..<(cursor + n)])
        }
        for token in remaining.removeFirst() {
            switch token {
            case "e":
                let re = try take(32)
                remoteEphemeral = re
                symmetric.mixHash(re)
                if pattern.usesPSK { symmetric.mixKey(re) }
            case "s":
                let chunk = try take(symmetric.cipher.hasKey ? 48 : 32)
                remoteStatic = try symmetric.decryptAndHash(chunk)
            case "ee": symmetric.mixKey(try e!.dh(remoteEphemeral!))
            case "es": symmetric.mixKey(isInitiator ? try e!.dh(remoteStatic!) : try s.dh(remoteEphemeral!))
            case "se": symmetric.mixKey(isInitiator ? try s.dh(remoteEphemeral!) : try e!.dh(remoteStatic!))
            case "ss": symmetric.mixKey(try s.dh(remoteStatic!))
            case "psk": symmetric.mixKeyAndHash(psk!)
            default: fatalError("unknown token \(token)")
            }
        }
        let payload = try symmetric.decryptAndHash(Data(message[cursor...]))
        myTurn = true
        return payload
    }

    /// Transport cipher states: `send` encrypts our messages, `receive` decrypts the peer's.
    public func split() throws -> (send: NoiseCipherState, receive: NoiseCipherState) {
        guard isComplete else { throw NoiseError.notYourTurn }
        let (c1, c2) = symmetric.split()
        return isInitiator ? (c1, c2) : (c2, c1)
    }
}
