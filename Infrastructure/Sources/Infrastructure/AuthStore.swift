//
//  AuthStore.swift        (Infrastructure)
//
//  Talks to Google Sign-In and to /auth/google/mobile-token,
//  persists the resulting JWT in the keychain, and hands a
//  fresh bearer token to networking code.
//

import Foundation                     // URL, Date, JSON…
import Security                       // keychain
import AuthenticationServices          // ASAuthorizationController
@preconcurrency import GoogleSignIn
import Configuration

public actor AuthStore: @unchecked Sendable {

    // MARK: – Public surface --------------------------------------------
    public init() {}
    /// `nil` until the first sign-in succeeds or after sign-out.
    nonisolated
    public var jwt: String? { Keychain.jwt }

    /// Launches Google Sign-In, exchanges the id_token for our JWT,
    /// and persists the result.  `rootVC` is the controller you
    /// present the SDK’s sheet from.
    public func signIn(from rootVC: UIViewController) async throws {
        let idToken = try await googleIDToken(from: rootVC)
        let appToken = try await exchangeWithBackend(idToken)
        await persist(jwt: appToken)
    }

    /// Invalidates the cache, erases the keychain entry, and
    /// revokes the user’s Google refresh token.
    public func signOut() async {
        Keychain.jwt = nil
        await GIDSignIn.sharedInstance.signOut()
    }

    /// Always returns a token whose `exp` is at least five minutes
    /// in the future, or `nil` if not signed in.
    func validJWT() async throws -> String? {
        guard var token = Keychain.jwt else { return nil }

        if isExpiringSoon(token) {
            if let refreshed = try await refreshGoogleAndBackend(token) {
                token = refreshed
                await persist(jwt: token)
            } else {
                return nil                              // refresh failed
            }
        }
        return token
    }

    // MARK: – Google -----------------------------------------------------
    @MainActor
    private func googleIDToken(from vc: UIViewController) async throws -> String {
        let config = GIDConfiguration(clientID: Config.googleClientID)

        // We call but _don’t store_ the result, so the non-Sendable value
        // never leaves the main actor.
        try await GIDSignIn.sharedInstance
            .signIn(withPresenting: vc, hint: nil, additionalScopes: [])

        guard let token = GIDSignIn.sharedInstance.currentUser?
                .idToken?.tokenString else {
            throw AuthError.noIDToken
        }
        return token
    }

    @MainActor
    private func refreshGoogleAndBackend(_ current: String) async throws -> String? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        try await user.refreshTokensIfNeeded()

        guard let fresh = user.idToken?.tokenString else { return nil }
        return try await exchangeWithBackend(fresh)
    }

    // MARK: – Backend ----------------------------------------------------

    private let endpoint = URL(string: "\(Config.apiBase)/auth/google/mobile-token")!

    private func exchangeWithBackend(_ idToken: String) async throws -> String {
        struct Body: Codable { let id_token: String }
        struct Resp: Codable { let access_token: String }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(id_token: idToken))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.backend
        }
        return try JSONDecoder().decode(Resp.self, from: data).access_token
    }

    // MARK: – Helpers ----------------------------------------------------

    private func persist(jwt: String) {
        Keychain.jwt = jwt
    }

    private func isExpiringSoon(_ token: String) -> Bool {
        guard
            let payloadData = token
                .split(separator: ".").dropFirst().first
                .flatMap({ Data(base64URLEncoded: String($0)) }),
            let obj = try? JSONSerialization.jsonObject(with: payloadData),
            let dict = obj as? [String: Any],
            let exp = dict["exp"] as? TimeInterval
        else { return true }           // assume worst case

        let expiry = Date(timeIntervalSince1970: exp)
        return expiry < Date().addingTimeInterval(300)        // 5 min
    }
}

// MARK: – Keychain thin wrapper -------------------------------------------

private enum Keychain {
    private static let service = Bundle.main.bundleIdentifier ?? "DreamApp"
    private static let key     = "jwt"

    static var jwt: String? {
        get {
            var query: [String: Any] = [
                kSecClass             as String: kSecClassGenericPassword,
                kSecAttrService       as String: service,
                kSecAttrAccount       as String: key,
                kSecReturnData        as String: kCFBooleanTrue!,
            ]
            var out: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
                  let data = out as? Data
            else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let encoded = newValue?.data(using: .utf8)
            var query: [String: Any] = [
                kSecClass       as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
            ]
            SecItemDelete(query as CFDictionary)
            guard let encoded else { return }              // nil means delete
            query[kSecValueData as String] = encoded
            SecItemAdd(query as CFDictionary, nil)
        }
    }
}

// MARK: – Support ----------------------------------------------------------

private enum AuthError: Error { case noIDToken, backend }

private extension Data {
    /// Google/JWT uses base64url.  This helper decodes such strings.
    init?(base64URLEncoded s: String) {
        var base64 = s.replacingOccurrences(of: "-", with: "+")
                      .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - base64.count % 4
        if pad < 4 { base64.append(String(repeating: "=", count: pad)) }
        self.init(base64Encoded: base64)
    }
}
