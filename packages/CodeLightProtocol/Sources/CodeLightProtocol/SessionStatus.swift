import Foundation

/// Real-time session status for Dynamic Island display.
public struct SessionStatus: Codable, Sendable {
    public let sessionId: String
    public let phase: SessionPhase
    public let toolName: String?
    public let projectName: String?
    public let timestamp: Date

    public init(sessionId: String, phase: SessionPhase, toolName: String? = nil, projectName: String? = nil, timestamp: Date = Date()) {
        self.sessionId = sessionId
        self.phase = phase
        self.toolName = toolName
        self.projectName = projectName
        self.timestamp = timestamp
    }
}

public enum SessionPhase: String, Codable, Sendable {
    case idle
    case thinking
    case toolRunning = "tool_running"
    case waitingApproval = "waiting_approval"
    case ended
}
