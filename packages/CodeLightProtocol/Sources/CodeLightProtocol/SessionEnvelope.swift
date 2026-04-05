import Foundation

/// A message envelope sent between CodeIsland and CodeLight.
/// Content is E2E encrypted — the server only sees the encrypted blob.
public struct SessionEnvelope: Codable, Sendable {
    public let id: String
    public let type: EnvelopeType
    public let content: String  // encrypted JSON string
    public let localId: String?
    public let timestamp: Date

    public init(id: String = UUID().uuidString, type: EnvelopeType, content: String, localId: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.content = content
        self.localId = localId
        self.timestamp = timestamp
    }
}

public enum EnvelopeType: String, Codable, Sendable {
    case userMessage = "user"
    case assistantMessage = "assistant"
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case system = "system"
    case status = "status"
}
