import SwiftUI

/// Shows connection status at the top of session list.
struct ConnectionStatusBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.isConnected {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Reconnecting...")
                    .font(.caption)
                Spacer()
                Button("Retry") {
                    Task {
                        if let server = appState.currentServer {
                            await appState.connectTo(server)
                        }
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.15))
        }
    }
}
