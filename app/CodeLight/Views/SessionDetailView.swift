import SwiftUI

struct SessionDetailView: View {
    @EnvironmentObject var appState: AppState
    let sessionId: String

    private var session: SessionInfo? {
        appState.sessions.first { $0.id == sessionId }
    }

    var body: some View {
        List {
            if let session {
                Section {
                    HStack {
                        Label("Status", systemImage: "circle.fill")
                            .foregroundStyle(session.active ? .green : .gray)
                        Spacer()
                        Text(session.active ? "Active" : "Inactive")
                            .foregroundStyle(.secondary)
                    }

                    if let path = session.metadata?.path {
                        HStack {
                            Label("Path", systemImage: "folder")
                            Spacer()
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }

                    if let model = session.metadata?.model {
                        HStack {
                            Label("Model", systemImage: "cpu")
                            Spacer()
                            Text(model.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let mode = session.metadata?.mode {
                        HStack {
                            Label("Mode", systemImage: "shield")
                            Spacer()
                            Text(mode.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Label("Last Active", systemImage: "clock")
                        Spacer()
                        Text(session.lastActiveAt, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Session Info")
                }

                Section {
                    NavigationLink(value: sessionId) {
                        Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            } else {
                ContentUnavailableView("Session Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(session?.metadata?.title ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}
