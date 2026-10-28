import BlueSteerProtocol
import Foundation
import SwiftTerm

/// Anything the hub can bridge: a PTY it owns, or a terminal wrapped by `bluesteer run`.
public protocol TerminalSession: AnyObject {
    var id: SessionID { get }
    var state: BSSessionState { get }
    var status: BSSessionStatus { get }
    var rows: Int { get }
    var cols: Int { get }
    /// The process whose working directory `cwd` mirrors.
    var pid: pid_t { get }
    var cwd: String { get set }
    /// Raw terminal output, as produced.
    var onOutput: ((Data) -> Void)? { get set }
    var onExit: (() -> Void)? { get set }
    func write(_ data: Data)
    /// May be ignored by sessions whose size belongs to another terminal.
    func resize(rows: Int, cols: Int)
    func stop(signal: Int32)
    /// Full-screen state for a newly subscribed remote.
    func snapshot() -> Data
}

/// Shared headless emulator so every session can produce snapshots.
public class EmulatedSession {
    let terminal: Terminal
    let delegate = NullTerminalDelegate()

    init(rows: Int, cols: Int) {
        terminal = Terminal(delegate: delegate, options: TerminalOptions(cols: max(cols, 2), rows: max(rows, 2)))
    }

    public var rows: Int { terminal.rows }
    public var cols: Int { terminal.cols }
    public var title: String? { delegate.title }

    func feed(_ data: Data) { terminal.feed(byteArray: [UInt8](data)) }

    public func snapshot() -> Data { TerminalSnapshot.render(terminal) }
}

final class NullTerminalDelegate: TerminalDelegate {
    var title: String?
    func send(source: Terminal, data: ArraySlice<UInt8>) {}
    func setTerminalTitle(source: Terminal, title: String) { self.title = title }
}
