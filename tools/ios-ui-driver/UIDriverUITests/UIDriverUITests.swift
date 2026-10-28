import Network
import XCTest

/// A UI "test" that never finishes on its own: it serves tap/type/screenshot
/// commands over HTTP so the remote app can be driven on a real iPhone from the
/// Mac (see driver.sh). Runs under XCTest because only XCUITest may synthesize
/// touches and keystrokes on a device.
final class UIDriverUITests: XCTestCase {
    static let bundleID = "dev.bluesteer.bluesteerRemote"
    static let port: UInt16 = 8099
    static let maxUptime: TimeInterval = 2 * 60 * 60

    func testServe() throws {
        continueAfterFailure = true
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        let server = try DriverServer(port: Self.port)
        server.start()
        let deadline = Date().addingTimeInterval(Self.maxUptime)
        while Date() < deadline {
            guard let request = server.dequeue() else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                continue
            }
            if request.path == "/quit" {
                server.respond(request, body: "bye")
                return
            }
            handle(request, app: app, server: server)
        }
    }

    private func handle(_ request: DriverServer.Request, app: XCUIApplication, server: DriverServer) {
        let q = request.query
        switch request.path {
        case "/activate":
            app.activate()
            server.respond(request, body: "state=\(app.state.rawValue)")
        case "/terminate":
            app.terminate()
            server.respond(request, body: "ok")
        case "/info":
            let b = UIScreen.main.bounds
            server.respond(request, body: "state=\(app.state.rawValue) points=\(Int(b.width))x\(Int(b.height)) scale=\(UIScreen.main.scale)")
        case "/tree":
            server.respond(request, body: app.debugDescription)
        case "/tap", "/press":
            let seconds = Double(q["seconds"] ?? "") ?? 1.0
            if let label = q["label"] {
                let element = find(label, in: app)
                guard element.waitForExistence(timeout: Double(q["timeout"] ?? "") ?? 5) else {
                    server.respond(request, status: 404, body: "no element matching \(label)")
                    return
                }
                let frame = element.frame
                if request.path == "/press" { element.press(forDuration: seconds) } else { element.tap() }
                server.respond(request, body: "\(request.path) \(element.elementType.rawValue) \"\(element.label)\" at \(Int(frame.midX)),\(Int(frame.midY))")
            } else if let x = Double(q["x"] ?? ""), let y = Double(q["y"] ?? "") {
                let point = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
                if request.path == "/press" { point.press(forDuration: seconds) } else { point.tap() }
                server.respond(request, body: "\(request.path) at \(x),\(y)")
            } else {
                server.respond(request, status: 400, body: "need label= or x=&y=")
            }
        case "/type":
            // Taps the on-screen keyboard key by key. XCUIElement.typeText needs
            // accessibility focus, which a Flutter app does not expose, and its
            // failure ends the test.
            let text = q["text"] ?? ""
            var tapped = 0
            for ch in text {
                let name: String
                switch ch {
                case "\n": name = "return"
                case " ": name = "space"
                default: name = String(ch)
                }
                guard let key = key(named: name, in: app) else {
                    server.respond(request, status: 404, body: "no key \(name) after \(tapped) keys")
                    return
                }
                key.tap()
                tapped += 1
            }
            server.respond(request, body: "tapped \(tapped) keys")
        case "/swipe":
            // Drag from (x,y) to (x2,y2) in points, e.g. to scroll the terminal.
            guard let x = Double(q["x"] ?? ""), let y = Double(q["y"] ?? ""),
                  let x2 = Double(q["x2"] ?? ""), let y2 = Double(q["y2"] ?? "") else {
                server.respond(request, status: 400, body: "need x=&y=&x2=&y2=")
                return
            }
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
            let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x2, dy: y2))
            from.press(forDuration: 0.1, thenDragTo: to)
            server.respond(request, body: "swiped \(x),\(y) -> \(x2),\(y2)")
        case "/home":
            XCUIDevice.shared.press(.home)
            server.respond(request, body: "home")
        case "/screenshot":
            server.respond(request, type: "image/png", body: XCUIScreen.main.screenshot().pngRepresentation)
        default:
            server.respond(request, status: 404, body: "unknown command \(request.path)")
        }
    }

    /// The on-screen key for one character, switching keyboard layouts
    /// (letters, numbers, symbols) and shift state until it is visible.
    private func key(named name: String, in app: XCUIApplication) -> XCUIElement? {
        for layout in ["", "numbers", "symbols", "letters"] {
            if !layout.isEmpty {
                let switcher = app.keys[layout]
                guard switcher.exists else { continue }
                switcher.tap()
            }
            if app.keys[name].exists { return app.keys[name] }
            if name.count == 1, name.uppercased() == name, name.lowercased() != name {
                let shift = app.keys["shift"]
                if shift.exists, app.keys[name.lowercased()].exists {
                    shift.tap()
                    if app.keys[name].waitForExistence(timeout: 1) { return app.keys[name] }
                }
            }
        }
        return app.keyboards.buttons[name].exists ? app.keyboards.buttons[name] : nil
    }

    private func find(_ text: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@ OR identifier == %@", text, text)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }
}

/// Just enough HTTP for curl: one request per connection, path + query string.
final class DriverServer {
    struct Request {
        let connection: NWConnection
        let path: String
        let query: [String: String]
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "ui-driver")
    private let lock = NSLock()
    private var pending: [Request] = []

    init(port: UInt16) throws {
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self!.queue)
            self?.receive(connection, buffer: Data())
        }
        listener.start(queue: queue)
    }

    func dequeue() -> Request? {
        lock.lock(); defer { lock.unlock() }
        return pending.isEmpty ? nil : pending.removeFirst()
    }

    func respond(_ request: Request, status: Int = 200, type: String = "text/plain; charset=utf-8", body: String) {
        respond(request, status: status, type: type, body: Data(body.utf8))
    }

    func respond(_ request: Request, status: Int = 200, type: String, body: Data) {
        let head = "HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        request.connection.send(content: data, completion: .contentProcessed { _ in request.connection.cancel() })
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
                let target = head.split(separator: "\r\n").first?.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
                let components = URLComponents(string: target)
                var query: [String: String] = [:]
                for item in components?.queryItems ?? [] { query[item.name] = item.value ?? "" }
                let request = Request(connection: connection, path: components?.path ?? target, query: query)
                lock.lock(); pending.append(request); lock.unlock()
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                receive(connection, buffer: buffer)
            }
        }
    }
}
