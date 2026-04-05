import CodeLightCrypto
import Foundation
import UIKit
import UserNotifications
import os.log

/// Manages push notification registration and token handling.
@MainActor
final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()
    private static let logger = Logger(subsystem: "com.codelight.app", category: "Push")

    @Published var isRegistered = false
    private var deviceToken: String?

    override private init() {
        super.init()
    }

    /// Request notification permissions and register for remote notifications.
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                Self.logger.info("Push permission granted")
            } else {
                Self.logger.info("Push permission denied")
            }
        } catch {
            Self.logger.error("Push permission error: \(error)")
        }
    }

    /// Called by AppDelegate when device token is received.
    func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        self.isRegistered = true
        Self.logger.info("Device token: \(token.prefix(16))...")

        // Send to current server
        Task {
            await sendTokenToServer(token)
        }
    }

    /// Called by AppDelegate when registration fails.
    func didFailToRegisterForRemoteNotifications(error: Error) {
        Self.logger.error("Push registration failed: \(error)")
        self.isRegistered = false
    }

    /// Send the device token to the CodeLight Server.
    private func sendTokenToServer(_ token: String) async {
        guard let serverUrl = AppState.shared.currentServer?.url,
              let authToken = KeyManager(serviceName: "com.codelight.app").loadToken(forServer: serverUrl) else {
            return
        }

        let url = URL(string: "\(serverUrl)/v1/push-tokens")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                Self.logger.info("Push token registered with server")
            }
        } catch {
            Self.logger.error("Failed to register push token: \(error)")
        }
    }
}
