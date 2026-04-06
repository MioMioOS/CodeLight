import ActivityKit
import Foundation

/// Global CodeLight Live Activity — one per device, shows aggregate session state.
struct CodeLightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // Active session being displayed (may switch as phase changes arrive)
        var activeSessionId: String
        var projectName: String
        var phase: String              // "thinking", "tool_running", "waiting_approval", "idle", "ended", "error"
        var toolName: String?
        var lastUserMessage: String?
        var lastAssistantSummary: String?

        // Aggregate counts across all sessions
        var totalSessions: Int
        var activeSessions: Int

        var startedAt: TimeInterval

        var startedAtDate: Date {
            Date(timeIntervalSince1970: startedAt)
        }
    }

    /// Global activity — not tied to a specific session
    var serverName: String
}
