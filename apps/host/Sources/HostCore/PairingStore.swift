import BlueSteerProtocol
import Foundation

/// The host's static key and the set of paired remotes, persisted as a
/// 0600 JSON file in the support directory.
/// TODO(Phase 5): move the private key into the Keychain.
public final class PairingStore {
    public struct Remote: Codable, Identifiable, Equatable {
        public var id: String { key.base64EncodedString() }
        public let key: Data
        public var name: String
        public let pairedAt: Date
    }

    private struct File: Codable {
        var hostPrivateKey: Data
        var remotes: [Remote]
    }

    public enum Error: Swift.Error, LocalizedError {
        /// The file exists but cannot be read: starting with a fresh key would
        /// silently unpair every remote, so the host refuses to start instead.
        case unreadable(URL, Swift.Error)
        public var errorDescription: String? {
            switch self {
            case .unreadable(let url, let why): "\(url.path) is unreadable (\(why)); move it away to start fresh (every remote must pair again)"
            }
        }
    }

    public let hostKey: NoiseKeyPair
    public private(set) var remotes: [Remote]
    private let url: URL

    public init(directory: URL = HostInfo.supportDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        url = directory.appendingPathComponent("pairing.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let file = try JSONDecoder().decode(File.self, from: try Data(contentsOf: url))
                hostKey = try NoiseKeyPair(privateKey: file.hostPrivateKey)
                remotes = file.remotes
            } catch {
                throw Error.unreadable(url, error)
            }
        } else {
            hostKey = NoiseKeyPair()
            remotes = []
            try save()
        }
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
        let data = try JSONEncoder().encode(File(hostPrivateKey: hostKey.privateKey.rawRepresentation, remotes: remotes))
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
