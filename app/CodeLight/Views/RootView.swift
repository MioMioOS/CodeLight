import SwiftUI

/// Root navigation — shows pairing if no servers, otherwise session list.
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            if appState.servers.isEmpty {
                PairingView()
            } else if appState.isConnected {
                SessionListView(server: appState.currentServer ?? appState.servers[0])
            } else {
                connectingView
                    .task {
                        if let server = appState.currentServer ?? appState.servers.first {
                            await appState.connectTo(server)
                            if !appState.isConnected {
                                errorMessage = "Could not connect to server"
                                showError = true
                            }
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var connectingView: some View {
        VStack(spacing: 24) {
            Spacer()

            if showError {
                // Error state
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("Connection Failed")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        showError = false
                        Task {
                            if let server = appState.currentServer ?? appState.servers.first {
                                await appState.connectTo(server)
                                if !appState.isConnected {
                                    showError = true
                                }
                            }
                        }
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        appState.servers.removeAll()
                        UserDefaults.standard.removeObject(forKey: "servers")
                        appState.disconnect()
                    } label: {
                        Text("Reset Connection")
                    }
                }
                .padding(.horizontal, 40)
            } else {
                // Loading state
                ProgressView()
                    .scaleEffect(1.2)

                Text("Connecting to server...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
