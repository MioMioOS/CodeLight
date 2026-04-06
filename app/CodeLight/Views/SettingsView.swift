import SwiftUI
import CodeLightCrypto

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Connection
            Section {
                if let server = appState.currentServer {
                    HStack {
                        Label("Server", systemImage: "server.rack")
                        Spacer()
                        Text(URL(string: server.url)?.host ?? server.url)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Label("Status", systemImage: "circle.fill")
                            .foregroundStyle(appState.isConnected ? .green : .red)
                        Spacer()
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Device Name", systemImage: "iphone")
                        Spacer()
                        Text(server.name)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Paired", systemImage: "calendar")
                        Spacer()
                        Text(server.pairedAt, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Connection")
            }

            // Actions
            Section {
                Button {
                    Task {
                        if let server = appState.currentServer {
                            await appState.connectTo(server)
                        }
                    }
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                }

                Button {
                    appState.disconnect()
                    appState.servers.removeAll()
                    UserDefaults.standard.removeObject(forKey: "servers")
                    dismiss()
                } label: {
                    Label("Scan New QR Code", systemImage: "qrcode.viewfinder")
                }

                Button(role: .destructive) {
                    if let server = appState.currentServer {
                        appState.removeServer(server)
                    }
                    dismiss()
                } label: {
                    Label("Disconnect & Remove", systemImage: "wifi.slash")
                }
            } header: {
                Text("Actions")
            }

            // Notifications
            Section {
                HStack {
                    Label("Push Notifications", systemImage: "bell.badge")
                    Spacer()
                    Text(PushManager.shared.isRegistered ? "Enabled" : "Disabled")
                        .foregroundStyle(.secondary)
                }

                if !PushManager.shared.isRegistered {
                    Button {
                        Task { await PushManager.shared.requestPermission() }
                    } label: {
                        Text("Enable Notifications")
                    }
                }
            } header: {
                Text("Notifications")
            }

            // About
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com/xmqywx/CodeLight")!) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/xmqywx/CodeIsland")!) {
                    Label("CodeIsland (Mac companion)", systemImage: "desktopcomputer")
                }

                Link(destination: URL(string: "https://github.com/xmqywx/CodeLight/blob/main/PRIVACY.md")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            } header: {
                Text("About")
            } footer: {
                Text("CodeLight — Monitor and control Claude Code from your iPhone.\nMade with passion by the CodeIsland team.")
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
