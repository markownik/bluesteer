import BlueSteerProtocol
import Foundation
import HostCore

/// This Mac's identity as a remote and the hosts it paired with, in a 0600
/// JSON file next to the host's own state (`remote.json`).
public final class RemoteStore {
    public struct Host: Codable, Equatable {
        /// base64url of the host instance id (INFO characteristic).
        public let id: String
        public var name: String
        public let hostKey: Data
        public init(id: String, name: String, hostKey: Data) { self.id = id; self.name = name; self.hostKey = hostKey }
    }

    private struct File: Codable {
        var privateKey: Data
        var hosts: [Host]
    }

    public let keyPair: NoiseKeyPair
    public private(set) var hosts: [Host]
    /// This Mac's Computer Name ("Marek's MacBook"), sent in `RemoteHello`; the host shows it.
    public let deviceName = HostController.defaultDisplayName
    private let url: URL

    public init(directory: URL = HostInfo.supportDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        url = directory.appendingPathComponent("remote.json")
        if let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) {
            keyPair = try NoiseKeyPair(privateKey: file.privateKey)
            hosts = file.hosts
        } else {
            keyPair = NoiseKeyPair()
            hosts = []
            try save()
        }
    }

    public func add(_ host: Host) throws {
        hosts.removeAll { $0.id == host.id }
        hosts.append(host)
        try save()
    }

    public func remove(id: String) throws {
        hosts.removeAll { $0.id == id }
        try save()
    }

    private func save() throws {
        let data = try JSONEncoder().encode(File(privateKey: keyPair.privateKey.rawRepresentation, hosts: hosts))
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
