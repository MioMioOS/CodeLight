import ActivityKit
import Foundation

/// ActivityAttributes for CodeLight Live Activities (Dynamic Island + Lock Screen).
/// Shared between the main app and the widget extension.
struct CodeLightActivityAttributes: ActivityAttributes {
    /// Dynamic state — updated as session progresses.
    struct ContentState: Codable, Hashable {
        var phase: String              // "thinking", "tool_running", "waiting_approval", "idle", "ended", "error"
        var toolName: String?          // Current tool name
        var projectName: String        // Project / session title
        var lastUserMessage: String?   // Latest user question (truncated)
        var lastAssistantSummary: String?  // Latest Claude response summary (truncated)
        var startedAt: TimeInterval    // Unix timestamp (seconds since 1970) — must match server

        /// Computed Date for display
        var startedAtDate: Date {
            Date(timeIntervalSince1970: startedAt)
        }
    }

    /// Fixed for the lifetime of the activity.
    var sessionId: String
    var serverName: String
}
