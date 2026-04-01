import Foundation

enum Secrets {
    /// Production builds should point this at your own backend, which keeps provider keys server-side.
    static var kaiBackendURL: URL? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "KAIBackendURL") as? String,
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
}
