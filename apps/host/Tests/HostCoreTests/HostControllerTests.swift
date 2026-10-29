import XCTest
@testable import HostCore

final class HostControllerTests: XCTestCase {
    /// "Disconnect all" closes the pairing window and stops accepting remotes until asked again.
    func testDisconnectAllStopsAcceptingUntilResumed() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bluesteer-ctl-\(UUID().uuidString.prefix(8))")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let controller = try HostController(store: try PairingStore(directory: dir), displayName: "test-mac",
                                            socketPath: dir.appendingPathComponent("s.sock").path, audit: AuditLog(directory: dir))
        controller.beginPairing()
        XCTAssertTrue(controller.pairingOpen)
        XCTAssertTrue(controller.accepting)

        controller.disconnectAll()
        XCTAssertFalse(controller.accepting)
        XCTAssertFalse(controller.pairingOpen)
        XCTAssertTrue(controller.connected.isEmpty)
        controller.disconnectAll() // idempotent

        controller.acceptRemotes()
        XCTAssertTrue(controller.accepting)
        controller.acceptRemotes()
        XCTAssertTrue(controller.accepting)
    }
}
