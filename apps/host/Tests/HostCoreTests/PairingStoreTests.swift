import BlueSteerProtocol
import XCTest
@testable import HostCore

final class PairingStoreTests: XCTestCase {
    private func tempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bluesteer-store-\(UUID().uuidString.prefix(8))")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func fileJSON(_ dir: URL) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: try Data(contentsOf: dir.appendingPathComponent("pairing.json"))) as! [String: Any]
    }

    func testKeyAndRemotesSurviveAReload() throws {
        let dir = tempDirectory()
        let first = try PairingStore(directory: dir, keyStorage: .file)
        try first.add(key: Data(repeating: 1, count: 32), name: "phone")
        let again = try PairingStore(directory: dir, keyStorage: .file)
        XCTAssertEqual(again.hostKey.publicKey, first.hostKey.publicKey)
        XCTAssertEqual(again.remotes.map(\.name), ["phone"])
        XCTAssertNotNil(try fileJSON(dir)["hostPrivateKey"], "file storage keeps the key in the file")
    }

    /// A damaged file must not be replaced by a fresh key (that would unpair everyone).
    func testUnreadableFileRefusesToStart() throws {
        let dir = tempDirectory()
        _ = try PairingStore(directory: dir, keyStorage: .file)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("pairing.json"))
        XCTAssertThrowsError(try PairingStore(directory: dir, keyStorage: .file)) { error in
            guard case PairingStore.Error.unreadable? = error as? PairingStore.Error else { return XCTFail("\(error)") }
        }
    }

    /// Against the real login Keychain: set BLUESTEER_KEYCHAIN_TESTS=1 to run.
    func testKeychainStorageMigratesTheFileKeyOnce() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BLUESTEER_KEYCHAIN_TESTS"] == "1", "needs the login Keychain")
        let service = "app.devland.bluesteer.test-\(UUID().uuidString.prefix(8))"
        addTeardownBlock { try? PairingStore.deleteKeychainKey(service: service) }
        let storage = PairingStore.KeyStorage.keychain(service: service)
        let dir = tempDirectory()

        // An old file with the key inside, plus one remote.
        let old = try PairingStore(directory: dir, keyStorage: .file)
        try old.add(key: Data(repeating: 2, count: 32), name: "phone")

        let migrated = try PairingStore(directory: dir, keyStorage: storage)
        XCTAssertEqual(migrated.hostKey.publicKey, old.hostKey.publicKey, "the key moved, it was not replaced")
        XCTAssertEqual(migrated.remotes.map(\.name), ["phone"])
        XCTAssertNil(try fileJSON(dir)["hostPrivateKey"], "the file no longer carries the key")
        XCTAssertEqual(try PairingStore.readKeychainKey(service: service), old.hostKey.privateKey.rawRepresentation)

        let again = try PairingStore(directory: dir, keyStorage: storage)
        XCTAssertEqual(again.hostKey.publicKey, old.hostKey.publicKey)
        XCTAssertNil(try fileJSON(dir)["hostPrivateKey"])

        // A fresh directory mints a key straight into the Keychain.
        try PairingStore.deleteKeychainKey(service: service)
        let fresh = try PairingStore(directory: tempDirectory(), keyStorage: storage)
        XCTAssertEqual(try PairingStore.readKeychainKey(service: service), fresh.hostKey.privateKey.rawRepresentation)
    }
}
