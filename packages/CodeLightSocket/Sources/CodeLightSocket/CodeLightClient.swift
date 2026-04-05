import Foundation
import SocketIO
import CodeLightProtocol
import CodeLightCrypto

/// Main client for connecting to a CodeLight Server.
/// Handles auth, Socket.io connection, message sending/receiving, and RPC.
public final class CodeLightClient: @unchecked Sendable {

    private let serverUrl: String
    private let keyManager: KeyManager
    private var token: String?
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var crypto: MessageCrypto?

    public var onUpdate: ((ServerUpdate) -> Void)?
    public var onEphemeral: ((ServerEphemeral) -> Void)?
    public var onRpcCall: ((String, String, @escaping (String) -> Void) -> Void)?
    public var isConnected: Bool { socket?.status == .connected }

    public init(serverUrl: String, keyManager: KeyManager) {
        self.serverUrl = serverUrl
        self.keyManager = keyManager
        self.token = keyManager.loadToken(forServer: serverUrl)
    }

    // MARK: - Authentication

    /// Authenticate with the server using Ed25519 challenge-response.
    public func authenticate() async throws -> AuthResponse {
        let challenge = UUID().uuidString
        let challengeData = Data(challenge.utf8)
        let signature = try keyManager.sign(challengeData)
        let publicKey = try keyManager.publicKeyBase64()

        let request = AuthRequest(
            publicKey: publicKey,
            challenge: challengeData.base64EncodedString(),
            signature: signature.base64EncodedString()
        )

        let url = URL(string: "\(serverUrl)/v1/auth")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)

        if let token = response.token {
            self.token = token
            try keyManager.storeToken(token, forServer: serverUrl)
        }

        return response
    }

    // MARK: - Socket Connection

    /// Connect to the server via Socket.io.
    public func connect(clientType: String = "user-scoped", sessionId: String? = nil) {
        guard let token = self.token else { return }

        let url = URL(string: serverUrl)!
        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .path("/v1/updates"),
            .connectParams(["token": token, "clientType": clientType] as [String: Any]),
            .reconnects(true),
            .reconnectWait(1),
            .reconnectWaitMax(5),
        ])

        socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            print("[CodeLightClient] Connected to \(self?.serverUrl ?? "")")
        }

        socket?.on(clientEvent: .disconnect) { _, _ in
            print("[CodeLightClient] Disconnected")
        }

        socket?.on("update") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let update = try? JSONDecoder().decode(ServerUpdate.self, from: jsonData) else { return }
            self?.onUpdate?(update)
        }

        socket?.on("ephemeral") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let ephemeral = try? JSONDecoder().decode(ServerEphemeral.self, from: jsonData) else { return }
            self?.onEphemeral?(ephemeral)
        }

        socket?.on("rpc-call") { [weak self] data, ack in
            guard let dict = data.first as? [String: Any],
                  let method = dict["method"] as? String,
                  let params = dict["params"] as? String else { return }
            self?.onRpcCall?(method, params) { result in
                ack.with(["ok": true, "result": result])
            }
        }

        socket?.connect()
    }

    /// Disconnect from the server.
    public func disconnect() {
        socket?.disconnect()
        manager = nil
        socket = nil
    }

    // MARK: - Messages

    /// Send a message via Socket.io.
    public func sendMessage(sessionId: String, content: String, localId: String? = nil) {
        var payload: [String: Any] = [
            "sid": sessionId,
            "message": content,
        ]
        if let localId { payload["localId"] = localId }

        socket?.emitWithAck("message", payload).timingOut(after: 30) { data in
            // Handle ack if needed
        }
    }

    /// Send session-alive heartbeat.
    public func sendAlive(sessionId: String) {
        socket?.emit("session-alive", ["sid": sessionId])
    }

    /// Send session-end event.
    public func sendSessionEnd(sessionId: String) {
        socket?.emit("session-end", ["sid": sessionId])
    }

    /// Register as RPC handler for a method prefix.
    public func registerRpc(method: String) {
        socket?.emit("rpc-register", ["method": method])
    }

    // MARK: - HTTP API

    /// Create or load a session.
    public func createSession(tag: String, metadata: String) async throws -> [String: Any] {
        return try await postJSON(path: "/v1/sessions", body: ["tag": tag, "metadata": metadata])
    }

    /// List sessions.
    public func listSessions() async throws -> [[String: Any]] {
        let result = try await getJSON(path: "/v1/sessions")
        return result["sessions"] as? [[String: Any]] ?? []
    }

    // MARK: - HTTP Helpers

    private func postJSON(path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = URL(string: "\(serverUrl)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func getJSON(path: String) async throws -> [String: Any] {
        let url = URL(string: "\(serverUrl)\(path)")!
        var request = URLRequest(url: url)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
