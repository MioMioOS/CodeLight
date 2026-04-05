import Foundation

/// Server update event (persistent, stored in DB).
public struct ServerUpdate: Codable, Sendable {
    public let type: String
    public let sessionId: String?
    public let message: UpdateMessage?
    public let metadata: String?
    public let active: Bool?
}

public struct UpdateMessage: Codable, Sendable {
    public let id: String
    public let seq: Int
    public let content: String
    public let localId: String?
}

/// Server ephemeral event (transient, not stored).
public struct ServerEphemeral: Codable, Sendable {
    public let type: String
    public let sessionId: String?
    public let active: Bool?
}
