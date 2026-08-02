import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor final class AuthManager: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var token: String?
    @Published var errorMessage: String?
    @Published var isWorking = false
    private var nonce: String?
    private var webSession: ASWebAuthenticationSession?
    private let webPresentation = WebAuthPresentationContext()
    private let keychainKey = "native-session"

    init() {
        token = Keychain.read(keychainKey)
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            token = "demo"; user = User(id: "demo-user", name: "Luke", email: "luke@example.com")
        }
    }

    var client: APIClient { APIClient(token: token) }

    func restore() async {
        guard token != nil, token != "demo" else { return }
        do { let response: SessionResponse = try await client.request("/api/native-auth/session"); user = response.user }
        catch { signOutLocally() }
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
            token = issuedToken; user = response.user; Keychain.write(issuedToken, key: keychainKey)
        } catch { errorMessage = error.localizedDescription }
    }

    func signInWithWeb() {
        let verifier = Self.randomNonce()
        let challenge = Self.sha256Base64URL(verifier)
        var components = URLComponents(url: APIClient.baseURL.appending(path: "/native-connect"), resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "challenge", value: challenge)]
        let session = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: "stitchly") { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                self.webSession = nil
                if let error { if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin { self.errorMessage = error.localizedDescription }; return }
                guard let callbackURL, let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else { self.errorMessage = "The sign-in response was invalid."; return }
                await self.redeemWebCode(code, verifier: verifier)
            }
        }
        session.presentationContextProvider = webPresentation
        session.prefersEphemeralWebBrowserSession = false
        webSession = session
        session.start()
    }

    private func redeemWebCode(_ code: String, verifier: String) async {
        isWorking = true; defer { isWorking = false }
        do {
            struct Body: Encodable { let code: String; let verifier: String }
            let response: SessionResponse = try await APIClient(token: nil).request("/api/native-auth/redeem", method: "POST", body: Body(code: code, verifier: verifier))
            guard let issuedToken = response.token else { throw APIError.invalidResponse }
            token = issuedToken; user = response.user; Keychain.write(issuedToken, key: keychainKey)
        } catch { errorMessage = error.localizedDescription }
    }

    func signOut() async { if token != "demo" { let _: EmptyResponse? = try? await client.request("/api/native-auth/session", method: "DELETE") }; signOutLocally() }
    func deleteAccount() async throws { let _: EmptyResponse = try await client.request("/api/native-auth/account", method: "DELETE"); signOutLocally() }
    private func signOutLocally() { Keychain.delete(keychainKey); token = nil; user = nil }
    private static func sha256(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    private static func sha256Base64URL(_ value: String) -> String { Data(SHA256.hash(data: Data(value.utf8))).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    private static func randomNonce() -> String { (0..<32).compactMap { _ in "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._".randomElement() }.reduce("") { $0 + String($1) } }
}

@MainActor private final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private enum Keychain {
    static func write(_ value: String, key: String) { delete(key); let data = Data(value.utf8); SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary, nil) }
    static func read(_ key: String) -> String? { var item: CFTypeRef?; let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &item); guard status == errSecSuccess, let data = item as? Data else { return nil }; return String(data: data, encoding: .utf8) }
    static func delete(_ key: String) { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary) }
}
