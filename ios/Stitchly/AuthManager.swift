import AuthenticationServices
import CryptoKit
import Foundation
import Security

struct AuthenticationRequest: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor final class AuthManager: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var token: String?
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published private(set) var isRestoring = false
    @Published var authenticationRequest: AuthenticationRequest?
    private var nonce: String?
    private let keychainKey = "native-session"

    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetAuthForUITests") { Keychain.delete(keychainKey) }
        if ProcessInfo.processInfo.arguments.contains("-resetDemoReaderProgressForUITests") {
            UserDefaults.standard.set(DemoData.project.currentInstruction, forKey: "demoReaderPosition")
        }
        token = Keychain.read(keychainKey)
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            token = "demo"; user = User(id: "demo-user", name: "Luke", email: "luke@example.com")
        }
        isRestoring = token != nil && token != "demo"
    }

    var client: APIClient { APIClient(token: token) }
    var isGuest: Bool { user == nil }
    var usesGuestDemo: Bool { isGuest || token == "demo" }
    var contentIdentity: String { usesGuestDemo ? "guest" : (user?.id ?? "guest") }

    func requireAuthentication(title: String, message: String) {
        guard isGuest, authenticationRequest == nil else { return }
        authenticationRequest = AuthenticationRequest(title: title, message: message)
    }

    func dismissAuthenticationRequest() { authenticationRequest = nil }

    func restore() async {
        guard token != nil, token != "demo" else { isRestoring = false; return }
        defer { isRestoring = false }
        do { let response: SessionResponse = try await client.request("/api/native-auth/session"); user = response.user }
        catch { await signOutLocally() }
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let raw = Self.randomNonce(); nonce = raw
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(raw)
    }

    func complete(_ result: Result<ASAuthorization, Error>) async {
        isWorking = true; defer { isWorking = false }
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityData = credential.identityToken, let identityToken = String(data: identityData, encoding: .utf8), let nonce else { throw APIError.invalidResponse }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let name = PersonNameComponentsFormatter().string(from: credential.fullName ?? .init())
            struct Body: Encodable { let identityToken: String; let authorizationCode: String?; let nonce: String; let name: String? }
            let response: SessionResponse = try await APIClient(token: nil).request("/api/native-auth/apple", method: "POST", body: Body(identityToken: identityToken, authorizationCode: code, nonce: nonce, name: name.isEmpty ? nil : name))
            guard let issuedToken = response.token else { throw APIError.invalidResponse }
            if let previousUserID = user?.id, previousUserID != response.user.id { await AppDataCache.shared.clear(for: previousUserID) }
            token = issuedToken; user = response.user; Keychain.write(issuedToken, key: keychainKey)
            authenticationRequest = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func authenticateWithEmail(email: String, password: String, name: String?, createAccount: Bool) async {
        isWorking = true; defer { isWorking = false }
        do {
            struct Body: Encodable { let email: String; let password: String; let name: String?; let mode: String }
            let response: SessionResponse = try await APIClient(token: nil).request("/api/native-auth/email", method: "POST", body: Body(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, name: name?.trimmingCharacters(in: .whitespacesAndNewlines), mode: createAccount ? "sign-up" : "sign-in"))
            guard let issuedToken = response.token else { throw APIError.invalidResponse }
            if let previousUserID = user?.id, previousUserID != response.user.id { await AppDataCache.shared.clear(for: previousUserID) }
            token = issuedToken; user = response.user; Keychain.write(issuedToken, key: keychainKey)
            authenticationRequest = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func signOut() async { isWorking = true; defer { isWorking = false }; if token != "demo" { let _: EmptyResponse? = try? await client.request("/api/native-auth/session", method: "DELETE") }; await signOutLocally() }
    func deleteAccount() async throws { isWorking = true; defer { isWorking = false }; let _: EmptyResponse = try await client.request("/api/native-auth/account", method: "DELETE"); await signOutLocally() }
    private func signOutLocally() async {
        if let userID = user?.id { await AppDataCache.shared.clear(for: userID) }
        Keychain.delete(keychainKey); token = nil; user = nil
    }
    private static func sha256(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    private static func randomNonce() -> String { (0..<32).compactMap { _ in "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._".randomElement() }.reduce("") { $0 + String($1) } }
}

private enum Keychain {
    static func write(_ value: String, key: String) { delete(key); let data = Data(value.utf8); SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary, nil) }
    static func read(_ key: String) -> String? { var item: CFTypeRef?; let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &item); guard status == errSecSuccess, let data = item as? Data else { return nil }; return String(data: data, encoding: .utf8) }
    static func delete(_ key: String) { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary) }
}
