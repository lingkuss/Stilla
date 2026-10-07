import Foundation

/// A metadata-only Voice Library snapshot. Preview browsing does not generate audio.
/// Selected voices are synthesized through the authenticated backend during guide creation.
enum CustomGuideVoiceCatalog {
    struct Snapshot: Codable {
        let updatedAt: String
        let voices: [CustomGuideVoice]
    }

    static let voices: [CustomGuideVoice] = {
        guard let url = Bundle.main.url(forResource: "guide-voice-previews", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return [] }
        var seen = Set<String>()
        return snapshot.voices.filter { isEligible($0) && seen.insert(key($0)).inserted }
    }()

    static func key(_ voice: CustomGuideVoice) -> String { "\(voice.language.rawValue):\(voice.id)" }

    private static func isEligible(_ voice: CustomGuideVoice) -> Bool {
        ["high_quality", "premade"].contains(voice.category ?? "") && isExistingPreviewURL(voice.previewURL)
    }

    static func favorites(_ saved: [CustomGuideVoice], in voices: [CustomGuideVoice]) -> [CustomGuideVoice] {
        // Older favourites lack quality and gender metadata. Resolve them against
        // the current catalogue instead of trusting their saved descriptions.
        let keys = Set(saved.map(key))
        return voices.filter { isEligible($0) && keys.contains(key($0)) }
    }

    static func isExistingPreviewURL(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        if url.host == "storage.googleapis.com" {
            return url.path.hasPrefix("/eleven-public-prod/")
                && ["mp3", "wav", "m4a"].contains(url.pathExtension.lowercased())
        }
        guard ["api.elevenlabs.io", "api.us.elevenlabs.io", "api.eu.residency.elevenlabs.io",
               "api.in.residency.elevenlabs.io", "api.sg.residency.elevenlabs.io"].contains(url.host ?? "") else { return false }
        let path = url.path.split(separator: "/")
        return path.count == 5 && path[0] == "v1" && path[1] == "voices"
            && !path[2].isEmpty && path[3] == "previews" && path[4] == "audio"
    }

    enum Tone: String, CaseIterable, Identifiable, Sendable {
        case all, calm, warm, deep, soft
        var id: String { rawValue }
        var terms: [String] {
            switch self {
            case .all: return []
            case .calm: return ["calm", "soothing", "relax", "lugn"]
            case .warm: return ["warm", "friendly", "varm"]
            case .deep: return ["deep", "resonant", "djup", "mörk"]
            case .soft: return ["soft", "gentle", "mjuk", "varsam"]
            }
        }
    }

    enum Gender: String, CaseIterable, Identifiable, Sendable {
        case all, female, male
        var id: String { rawValue }
    }

    static func search(_ voices: [CustomGuideVoice], language: CustomGuideLanguage, text: String, tone: Tone, gender: Gender = .all) -> [CustomGuideVoice] {
        let terms = text.split(whereSeparator: \.isWhitespace).map(String.init)
        return voices.filter { voice in
            guard voice.language == language, isEligible(voice),
                  gender == .all || voice.gender == gender.rawValue else { return false }
            let content = "\(voice.name) \(voice.detail) \(voice.accent)"
            return terms.allSatisfy { content.localizedStandardContains($0) }
                && (tone == .all || tone.terms.contains { content.localizedStandardContains($0) })
        }
    }
}
