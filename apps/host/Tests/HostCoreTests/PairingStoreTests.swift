import BlueSteerProtocol
import XCTest
@testable import HostCore

final class PairingStoreTests: XCTestCase {
    private func tempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bluesteer-store-\(UUID().uuidString.prefix(8))")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testKeyAndRemotesSurviveAReload() throws {
        let dir = tempDirectory()
        let first = try PairingStore(directory: dir)
        try first.add(key: Data(repeating: 1, count: 32), name: "phone")
        let again = try PairingStore(directory: dir)
        XCTAssertEqual(again.hostKey.publicKey, first.hostKey.publicKey)
        XCTAssertEqual(again.remotes.map(\.name), ["phone"])
    }

    /// A damaged file must not be replaced by a fresh key (that would unpair everyone).
    func testUnreadableFileRefusesToStart() throws {
        let dir = tempDirectory()
        _ = try PairingStore(directory: dir)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("pairing.json"))
        XCTAssertThrowsError(try PairingStore(directory: dir)) { error in
            guard case PairingStore.Error.unreadable? = error as? PairingStore.Error else { return XCTFail("\(error)") }
        }
    }
}
