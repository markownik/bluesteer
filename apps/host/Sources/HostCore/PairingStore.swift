import BlueSteerProtocol
import Foundation
import Security

/// The host's static key and the set of paired remotes. The remotes live in a
/// 0600 JSON file in the support directory; the private key lives in the login
/// Keychain for signed builds (`KeyStorage.keychain`) or in the same file for
/// tests and ad-hoc builds (`KeyStorage.file`). A file that still carries a key
/// is migrated into the Keychain once and rewritten without it.
public final class PairingStore {
    public struct Remote: Codable, Identifiable, Equatable {
        public var id: String { key.base64EncodedString() }
        public let key: Data
        public var name: String
        public let pairedAt: Date
    }

    /// Where the host's private key is kept.
    public enum KeyStorage: Equatable {
        /// Inside `pairing.json` (tests, and ad-hoc builds whose code identity changes on every rebuild).
        case file
        /// A generic password item in the login Keychain, under this service name.
        case keychain(service: String)

        public static let keychain = KeyStorage.keychain(service: "app.devland.bluesteer.host.macos")
    }

    private struct File: Codable {
        var hostPrivateKey: Data?
        var remotes: [Remote]
    }

    public enum Error: Swift.Error, LocalizedError {
        /// The file exists but cannot be read: starting with a fresh key would
        /// silently unpair every remote, so the host refuses to start instead.
        case unreadable(URL, Swift.Error)
        /// The Keychain refused to hand out or store the host key (access denied,
        /// prompt cancelled…); a fresh key would unpair every remote, so the host stops.
        case keychain(OSStatus)
        public var errorDescription: String? {
            switch self {
            case .unreadable(let url, let why): return "\(url.path) is unreadable (\(why)); move it away to start fresh (every remote must pair again)"
            case .keychain(let status):
                let text = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
                return "the Keychain refused the BlueSteer host key (\(text)); allow BlueSteer in the Keychain prompt, or delete the \"BlueSteer host key\" item in Keychain Access to start fresh (every remote must pair again)"
            }
        }
    }

    static let keychainAccount = "host-key"

    public let hostKey: NoiseKeyPair
    public let keyStorage: KeyStorage
    public private(set) var remotes: [Remote]
    private let url: URL

    /// Signed builds keep the key in the Keychain. An ad-hoc signed build (every local
    /// `swift build`) gets a new code identity on each rebuild and would be asked for
    /// Keychain access every time, so it keeps the file.
    public static var defaultKeyStorage: KeyStorage { isAdHocSigned ? .file : .keychain }

    public init(directory: URL = HostInfo.supportDirectory, keyStorage: KeyStorage = PairingStore.defaultKeyStorage) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        url = directory.appendingPathComponent("pairing.json")
        self.keyStorage = keyStorage
        var file = File(hostPrivateKey: nil, remotes: [])
        var needsSave = true
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                file = try JSONDecoder().decode(File.self, from: try Data(contentsOf: url))
            } catch {
                throw Error.unreadable(url, error)
            }
            needsSave = false
        }
        let fileURL = url  // a nested function may not capture self before every property is set
        func key(_ raw: Data) throws -> NoiseKeyPair {
            do { return try NoiseKeyPair(privateKey: raw) } catch { throw Error.unreadable(fileURL, error) }
        }
        switch keyStorage {
        case .file:
            if let raw = file.hostPrivateKey {
                hostKey = try key(raw)
            } else {
                hostKey = NoiseKeyPair()
                needsSave = true
            }
        case .keychain(let service):
            if let raw = try Self.readKeychainKey(service: service) {
                hostKey = try key(raw)
            } else if let raw = file.hostPrivateKey {
                // One-time migration of a key that lived in the file.
                hostKey = try key(raw)
                try Self.addKeychainKey(raw, service: service)
            } else {
                hostKey = NoiseKeyPair()
                try Self.addKeychainKey(hostKey.privateKey.rawRepresentation, service: service)
            }
            if file.hostPrivateKey != nil { needsSave = true }
        }
        remotes = file.remotes
        if needsSave { try save() }
    }

    public var pairedKeys: Set<Data> { Set(remotes.map(\.key)) }

    public func add(key: Data, name: String) throws {
        remotes.removeAll { $0.key == key }
        remotes.append(Remote(key: key, name: name, pairedAt: Date()))
        try save()
    }

    /// Updates the name a remote reports in its `RemoteHello`.
    public func rename(key: Data, name: String) throws {
        guard let i = remotes.firstIndex(where: { $0.key == key }), remotes[i].name != name else { return }
        remotes[i].name = name
        try save()
    }

    public func remove(key: Data) throws {
        remotes.removeAll { $0.key == key }
        try save()
    }

    private func save() throws {
        let raw: Data? = keyStorage == .file ? hostKey.privateKey.rawRepresentation : nil
        let data = try JSONEncoder().encode(File(hostPrivateKey: raw, remotes: remotes))
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    // MARK: Keychain

    private static func query(service: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: keychainAccount]
    }

    static func readKeychainKey(service: String) throws -> Data? {
        var q = query(service: service)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        switch status {
        case errSecSuccess: return item as? Data
        case errSecItemNotFound: return nil
        default: throw Error.keychain(status)
        }
    }

    static func addKeychainKey(_ raw: Data, service: String) throws {
        var q = query(service: service)
        q[kSecValueData as String] = raw
        q[kSecAttrLabel as String] = "BlueSteer host key"
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw Error.keychain(status) }
    }

    /// Tests only: removes the item so the next start mints a fresh key.
    static func deleteKeychainKey(service: String) throws {
        let status = SecItemDelete(query(service: service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Error.keychain(status) }
    }

    /// True when this process's code signature is ad-hoc (or absent), i.e. a local development build.
    static var isAdHocSigned: Bool {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return true }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return true }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, [], &info) == errSecSuccess,
              let flags = (info as? [String: Any])?[kSecCodeInfoFlags as String] as? UInt32 else { return true }
        return flags & SecCodeSignatureFlags.adhoc.rawValue != 0
    }
}
