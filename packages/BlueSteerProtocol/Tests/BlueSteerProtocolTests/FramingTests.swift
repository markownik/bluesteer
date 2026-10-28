import XCTest
@testable import BlueSteerProtocol

final class FramingTests: XCTestCase {
    func testRoundTripSingleMessage() throws {
        let message = Data("hello".utf8)
        var framer = Framer()
        XCTAssertEqual(framer.receive(try Framing.frame(message)), [message])
        XCTAssertEqual(framer.pendingByteCount, 0)
    }

    func testReassemblesAcrossArbitraryChunks() throws {
        let a = Data(repeating: 0x41, count: 300)
        let b = Data(repeating: 0x42, count: 7)
        let stream = try Framing.frame(a) + Framing.frame(b)
        var framer = Framer()
        var got: [Data] = []
        // Split at every awkward boundary: inside a length prefix and inside payloads.
        for chunk in stride(from: 0, to: stream.count, by: 3).map({ stream[$0..<min($0 + 3, stream.count)] }) {
            got += framer.receive(Data(chunk))
        }
        XCTAssertEqual(got, [a, b])
        XCTAssertEqual(framer.pendingByteCount, 0)
    }

    func testEmptyMessageIsValid() throws {
        var framer = Framer()
        XCTAssertEqual(framer.receive(try Framing.frame(Data())), [Data()])
    }

    func testRejectsOversizedMessage() {
        XCTAssertThrowsError(try Framing.frame(Data(count: Framing.maxFrameLength + 1)))
    }

    func testKeepsPartialFrame() throws {
        var framer = Framer()
        let framed = try Framing.frame(Data("abc".utf8))
        XCTAssertEqual(framer.receive(framed.prefix(4)), [])
        XCTAssertEqual(framer.pendingByteCount, 4)
        XCTAssertEqual(framer.receive(framed.suffix(1)), [Data("abc".utf8)])
    }
}
