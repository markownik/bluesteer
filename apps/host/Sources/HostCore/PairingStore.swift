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

    public let hostKey: NoiseKeyPair
    public private(set) var remotes: [Remote]
    private let url: URL

    public init(directory: URL = HostInfo.supportDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        url = directory.appendingPathComponent("pairing.json")
        if let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) {
            hostKey = try NoiseKeyPair(privateKey: file.hostPrivateKey)
            remotes = file.remotes
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
