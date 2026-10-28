import XCTest
@testable import HostCore

final class SessionHubTests: XCTestCase {
    func testRegisterAndUnregister() {
        let hub = SessionHub()
        let id = SessionID()
        hub.register(id)
        XCTAssertEqual(hub.sessionIDs, [id])
        hub.unregister(id)
        XCTAssertTrue(hub.sessionIDs.isEmpty)
    }
}
