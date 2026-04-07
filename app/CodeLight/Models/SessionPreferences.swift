//
//  SessionPreferences.swift
//  CodeLight
//
//  Per-device, per-session UI preferences that live entirely on the iPhone.
//  We deliberately keep these client-side instead of round-tripping to the
//  server because they're personal opinions ("I want THIS session to show up
//  as 'launchpad bug fix'") and have no value to other devices.
//

import Foundation
import Combine

@MainActor
final class SessionPreferences: ObservableObject {
    static let shared = SessionPreferences()

    @Published private(set) var customNames: [String: String] = [:]
    @Published private(set) var archivedIds: Set<String> = []

    private let customNamesKey = "session.customNames.v1"
    private let archivedKey = "session.archived.v1"

    private init() {
        load()
    }

    // MARK: - Custom name

    func customName(for sessionId: String) -> String? {
        let trimmed = customNames[sessionId]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    func setCustomName(_ name: String?, for sessionId: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            customNames[sessionId] = trimmed
        } else {
            customNames.removeValue(forKey: sessionId)
        }
        persist()
    }

    // MARK: - Archive

    func isArchived(_ sessionId: String) -> Bool {
        archivedIds.contains(sessionId)
    }

    func archive(_ sessionId: String) {
        archivedIds.insert(sessionId)
        persist()
    }

    func unarchive(_ sessionId: String) {
        archivedIds.remove(sessionId)
        persist()
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: customNamesKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            customNames = decoded
        }
        if let data = UserDefaults.standard.data(forKey: archivedKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            archivedIds = Set(decoded)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customNames) {
            UserDefaults.standard.set(data, forKey: customNamesKey)
        }
        if let data = try? JSONEncoder().encode(Array(archivedIds)) {
            UserDefaults.standard.set(data, forKey: archivedKey)
        }
    }
}
