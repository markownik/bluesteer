import BlueSteerProtocol
import XCTest
@testable import HostCore
@testable import RemoteCore

final class RemoteStoreTests: XCTestCase {
    private func tempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bluesteer-remote-\(UUID().uuidString.prefix(8))")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// The console remote introduces itself by the Mac's Computer Name, like the host does.
    func testDeviceNameIsTheComputerName() throws {
        let store = try RemoteStore(directory: tempDirectory())
        XCTAssertEqual(store.deviceName, HostController.defaultDisplayName)
        XCTAssertFalse(store.deviceName.isEmpty)
    }

    /// A remote.json written before the name was computed (it stored a hostname) still loads.
    func testOldFileWithStoredNameStillLoads() throws {
        let dir = tempDirectory()
        let first = try RemoteStore(directory: dir)
        try first.add(RemoteStore.Host(id: "abc", name: "mini", hostKey: Data(repeating: 2, count: 32)))
        let url = dir.appendingPathComponent("remote.json")
        var json = try JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as! [String: Any]
        json["deviceName"] = "old-hostname.local"
        try JSONSerialization.data(withJSONObject: json).write(to: url)

        let again = try RemoteStore(directory: dir)
        XCTAssertEqual(again.keyPair.publicKey, first.keyPair.publicKey)
        XCTAssertEqual(again.hosts.map(\.name), ["mini"])
        XCTAssertEqual(again.deviceName, HostController.defaultDisplayName)
    }
}
