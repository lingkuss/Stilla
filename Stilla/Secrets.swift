import Foundation

enum Secrets {
    /// Production builds should point this at your own backend, which keeps provider keys server-side.
    static var kaiBackendURL: URL? {
        urlValue(forInfoDictionaryKey: "KAIBackendURL")
    }

    /// Endpoint used to persist and fetch shared sessions.
    /// Defaults to the same host as `KAIBackendURL`, with `/kai/share` path.
    static var kaiShareBackendURL: URL? {
        if let explicit = urlValue(forInfoDictionaryKey: "KAIShareBackendURL") {
            return explicit
        }

        guard let generateURL = kaiBackendURL else { return nil }
        var components = URLComponents(url: generateURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        components?.path = "/kai/share"
        return components?.url
    }

    /// Base URL used to build user-facing share links, e.g. `<base>/share?id=...`.
    static var kaiShareWebBaseURL: URL? {
        urlValue(forInfoDictionaryKey: "KAIShareWebBaseURL")
    }

    /// Optional endpoint used to generate full sleep stories.
    static var kaiSleepStoryBackendURL: URL? {
        urlValue(forInfoDictionaryKey: "KAISleepStoryBackendURL")
    }

    /// Optional endpoint used to obtain App Attest challenges and token exchange.
    /// Defaults to the same host as `KAIBackendURL`, with `/attest` path.
    static var kaiAttestBaseURL: URL? {
        if let explicit = urlValue(forInfoDictionaryKey: "KAIAttestBaseURL") {
            return explicit
        }

        guard let generateURL = kaiBackendURL else { return nil }
        var components = URLComponents(url: generateURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        components?.path = "/attest"
        return components?.url
    }

    /// Optional shared secret forwarded to your proxy. This is not a substitute for server-side auth,
    /// but it provides a simple first gate while you stand up proper protection and rate limiting.
    static var kaiBackendToken: String? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "KAIBackendToken") as? String,
            !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return rawValue
    }

    private static func urlValue(forInfoDictionaryKey key: String) -> URL? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let cleaned = rawValue.unicodeScalars
            .filter { !$0.properties.isWhitespace && !$0.properties.isDefaultIgnorableCodePoint }
            .map(String.init)
            .joined()

        return URL(string: cleaned)
    }
}
