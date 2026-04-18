import Foundation
import DeviceCheck
import CryptoKit

actor AppAttestAuthManager {
    static let shared = AppAttestAuthManager()

    enum AuthError: LocalizedError {
        case notConfigured
        case unsupportedDevice
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "App attestation is not configured."
            case .unsupportedDevice:
                return "This device does not support App Attest."
            case .invalidResponse:
                return "Invalid auth response from server."
            }
        }
    }

    private struct ChallengeResponse: Codable {
        let challenge: String
        let expiresInSeconds: Int?
    }

    private struct RegisterRequest: Codable {
        let installationId: String
        let keyId: String
        let challenge: String
        let attestation: String
    }

    private struct AssertRequest: Codable {
        let installationId: String
        let keyId: String
        let challenge: String
        let payload: String
        let assertion: String
    }

    private struct TokenResponse: Codable {
        let token: String
        let expiresAt: String
    }

    private let keyIdStorageKey = "attest.key_id"
    private let installationStorageKey = "attest.installation_id"
    private let tokenStorageKey = "attest.token"
    private let tokenExpiryStorageKey = "attest.token_expiry"
    private let refreshLeeway: TimeInterval = 60

    private let service = DCAppAttestService.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let dateFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let dateFormatterInternet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private var cachedToken: String?
    private var cachedTokenExpiry: Date?

    init() {
        cachedToken = UserDefaults.standard.string(forKey: tokenStorageKey)
        let expiryString = UserDefaults.standard.string(forKey: tokenExpiryStorageKey)
        cachedTokenExpiry = expiryString.flatMap(parseExpiryDate)
    }

    func authorize(_ request: inout URLRequest) async throws {
        #if DEBUG
        if !service.isSupported, let legacyToken = Secrets.kaiBackendToken {
            request.setValue("Bearer \(legacyToken)", forHTTPHeaderField: "Authorization")
            return
        }
        #endif

        guard service.isSupported else {
            throw AuthError.unsupportedDevice
        }

        let token = try await ensureValidToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func ensureValidToken() async throws -> String {
        if let token = cachedToken,
           let expiry = cachedTokenExpiry,
           expiry.timeIntervalSinceNow > refreshLeeway {
            #if DEBUG
            print("🔐 AppAttestAuth: using cached token (expires in \(Int(expiry.timeIntervalSinceNow))s)")
            #endif
            return token
        }

        #if DEBUG
        if let expiry = cachedTokenExpiry {
            print("🔐 AppAttestAuth: token refresh required (expires in \(Int(expiry.timeIntervalSinceNow))s, leeway \(Int(refreshLeeway))s)")
        } else {
            print("🔐 AppAttestAuth: token refresh required (no valid cached expiry)")
        }
        #endif

        var keyId = storedKeyId
        if keyId == nil {
            #if DEBUG
            print("🔐 AppAttestAuth: no keyId found, registering attestation")
            #endif
            keyId = try await registerAttestation()
        }

        do {
            guard let resolvedKeyId = keyId else {
                throw AuthError.invalidResponse
            }
            #if DEBUG
            print("🔐 AppAttestAuth: refreshing token via assertion")
            #endif
            return try await refreshToken(using: resolvedKeyId)
        } catch {
            // If assertion fails due invalid/stale key, re-register once.
            #if DEBUG
            print("🔐 AppAttestAuth: assertion refresh failed, re-registering key (\(error.localizedDescription))")
            #endif
            clearKeyAndToken()
            let newKeyId = try await registerAttestation()
            return try await refreshToken(using: newKeyId)
        }
    }

    private func registerAttestation() async throws -> String {
        guard let baseURL = Secrets.kaiAttestBaseURL else {
            throw AuthError.notConfigured
        }

        let installationId = installationId()
        let challenge = try await requestChallenge(baseURL: baseURL, installationId: installationId, purpose: "register")
        let keyId = try await service.generateKey()

        let challengeHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestationData = try await service.attestKey(keyId, clientDataHash: challengeHash)

        let payload = RegisterRequest(
            installationId: installationId,
            keyId: keyId,
            challenge: challenge,
            attestation: attestationData.base64EncodedString()
        )

        let tokenResponse = try await postJSON(
            url: baseURL.appendingPathComponent("register"),
            payload: payload,
            responseType: TokenResponse.self
        )

        storeKeyId(keyId)
        storeToken(tokenResponse)
        #if DEBUG
        print("🔐 AppAttestAuth: register succeeded, token issued")
        #endif
        return keyId
    }

    private func refreshToken(using keyId: String) async throws -> String {
        guard let baseURL = Secrets.kaiAttestBaseURL else {
            throw AuthError.notConfigured
        }

        let installationId = installationId()
        let challenge = try await requestChallenge(baseURL: baseURL, installationId: installationId, purpose: "token")
        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = """
        {"challenge":"\(challenge)","installationId":"\(installationId)","timestamp":\(timestamp)}
        """
        let payloadData = Data(payload.utf8)
        let payloadHash = Data(SHA256.hash(data: payloadData))
        let assertionData = try await service.generateAssertion(keyId, clientDataHash: payloadHash)

        let request = AssertRequest(
            installationId: installationId,
            keyId: keyId,
            challenge: challenge,
            payload: payload,
            assertion: assertionData.base64EncodedString()
        )

        let tokenResponse = try await postJSON(
            url: baseURL.appendingPathComponent("assert"),
            payload: request,
            responseType: TokenResponse.self
        )
        storeToken(tokenResponse)
        #if DEBUG
        print("🔐 AppAttestAuth: assert succeeded, token refreshed")
        #endif
        return tokenResponse.token
    }

    private func requestChallenge(baseURL: URL, installationId: String, purpose: String) async throws -> String {
        struct ChallengeRequest: Codable {
            let installationId: String
            let purpose: String
        }

        let response = try await postJSON(
            url: baseURL.appendingPathComponent("challenge"),
            payload: ChallengeRequest(installationId: installationId, purpose: purpose),
            responseType: ChallengeResponse.self
        )
        return response.challenge
    }

    private func postJSON<Payload: Encodable, Response: Decodable>(
        url: URL,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        return try decoder.decode(responseType, from: data)
    }

    private var storedKeyId: String? {
        UserDefaults.standard.string(forKey: keyIdStorageKey)
    }

    private func storeKeyId(_ keyId: String) {
        UserDefaults.standard.set(keyId, forKey: keyIdStorageKey)
    }

    private func storeToken(_ response: TokenResponse) {
        cachedToken = response.token
        cachedTokenExpiry = parseExpiryDate(response.expiresAt)
        UserDefaults.standard.set(response.token, forKey: tokenStorageKey)
        UserDefaults.standard.set(response.expiresAt, forKey: tokenExpiryStorageKey)
    }

    private func parseExpiryDate(_ value: String) -> Date? {
        if let parsed = dateFormatterWithFractionalSeconds.date(from: value) {
            return parsed
        }
        return dateFormatterInternet.date(from: value)
    }

    private func clearKeyAndToken() {
        cachedToken = nil
        cachedTokenExpiry = nil
        UserDefaults.standard.removeObject(forKey: keyIdStorageKey)
        UserDefaults.standard.removeObject(forKey: tokenStorageKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryStorageKey)
    }

    private func installationId() -> String {
        if let existing = UserDefaults.standard.string(forKey: installationStorageKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(created, forKey: installationStorageKey)
        return created
    }
}
