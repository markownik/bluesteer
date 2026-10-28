import Foundation

/// Identifies one bridged terminal session.
public struct SessionID: Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String = UUID().uuidString) { self.rawValue = rawValue }
}

/// Owns all sessions and routes between them and connected remotes.
/// Phase 2 fills this in; for now it only tracks identifiers.
public final class SessionHub {
    public private(set) var sessionIDs: [SessionID] = []

    public init() {}

    public func register(_ id: SessionID) { sessionIDs.append(id) }
    public func unregister(_ id: SessionID) { sessionIDs.removeAll { $0 == id } }
}
