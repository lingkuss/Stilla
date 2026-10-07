import Foundation
import CryptoKit

enum CustomGuideLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case english = "en", swedish = "sv", spanish = "es", french = "fr", norwegian = "nb", danish = "da"
    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .swedish: return "Svenska"
        case .spanish: return "Español"
        case .french: return "Français"
        case .norwegian: return "Norsk bokmål"
        case .danish: return "Dansk"
        }
    }
    static func preferred(for code: String?) -> Self {
        if code == "no" { return .norwegian }
        return code.flatMap(Self.init(rawValue:)) ?? .english
    }
}

/// A creation brief and its generated artwork. Voice synthesis is a separate step.
struct CustomGuideDraft: Codable, Equatable {
    var version = 1
    var id = UUID()
    var name = ""
    var language: CustomGuideLanguage
    var personality = ""
    var voiceID: String?
    var voiceName: String?
    var voicePreviewURL: URL?
    var voiceDescription = ""
    var referenceImage: Data?
    var imageDescription = ""
    var generatedImage: Data?
    var generatedImageFingerprint: String?

    init(language: CustomGuideLanguage = .english) { self.language = language }

    private enum CodingKeys: String, CodingKey {
        case version, id, name, language, personality, voiceID, voiceName, voicePreviewURL, voiceDescription, referenceImage, imageDescription, generatedImage, generatedImageFingerprint
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        // Earlier drafts only offered English samples, even in the Swedish UI.
        language = try values.decodeIfPresent(CustomGuideLanguage.self, forKey: .language) ?? .english
        personality = try values.decode(String.self, forKey: .personality)
        voiceID = try values.decodeIfPresent(String.self, forKey: .voiceID)
        voiceName = try values.decodeIfPresent(String.self, forKey: .voiceName)
        voicePreviewURL = try values.decodeIfPresent(URL.self, forKey: .voicePreviewURL)
        voiceDescription = try values.decodeIfPresent(String.self, forKey: .voiceDescription) ?? ""
        referenceImage = try values.decodeIfPresent(Data.self, forKey: .referenceImage)
        imageDescription = try values.decodeIfPresent(String.self, forKey: .imageDescription) ?? ""
        generatedImage = try values.decodeIfPresent(Data.self, forKey: .generatedImage)
        generatedImageFingerprint = try values.decodeIfPresent(String.self, forKey: .generatedImageFingerprint)
    }

    mutating func selectLanguage(_ value: CustomGuideLanguage) {
        guard value != language else { return }
        language = value
        voiceID = nil
        voiceName = nil
        voicePreviewURL = nil
        // Keep the user's written personality and image when changing language.
    }

    var hasContent: Bool {
        !name.isEmpty || !personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || voiceID != nil || referenceImage != nil || !voiceDescription.isEmpty
            || !imageDescription.isEmpty || generatedImage != nil
    }

    var guideID: String { "custom-\(id.uuidString.lowercased())" }
    var imageFingerprint: String {
        var hash = SHA256()
        hash.update(data: Data("\(imageDescription.utf8.count):\(imageDescription)".utf8))
        hash.update(data: referenceImage ?? Data())
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    var hasCurrentImage: Bool { generatedImage != nil && generatedImageFingerprint == imageFingerprint }
}

enum CustomGuideDraftStore {
    static func load(from url: URL = location, defaultLanguage: CustomGuideLanguage = .english) throws -> CustomGuideDraft {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init(language: defaultLanguage) }
        let draft = try JSONDecoder().decode(CustomGuideDraft.self, from: Data(contentsOf: url))
        guard draft.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return draft
    }

    static func save(_ draft: CustomGuideDraft, to url: URL = location) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: url, options: .atomic)
    }

    private static var location: URL {
        URL.applicationSupportDirectory.appending(path: "GuideCreator/draft.json")
    }
}

/// Offline prototype: combines compatible traits into an editable brief.
/// It does not imply a request to an AI service or spend generation credits.
enum GuidePersonalityGenerator {
    static func generate(swedish: Bool, excluding previous: String) -> String {
        var random = SystemRandomNumberGenerator()
        return generate(swedish: swedish, excluding: previous, using: &random)
    }

    static func generate<R: RandomNumberGenerator>(swedish: Bool, excluding previous: String, using random: inout R) -> String {
        let presence = swedish ? [
            "En varm och jordnära guide som får mig att känna mig välkommen precis som jag är.",
            "En stillsam och eftertänksam guide som låter tystnaden ta plats.",
            "En vänlig och nyfiken guide som hjälper mig att möta mig själv utan att döma.",
            "En trygg och mjuk guide med en lätt glimt av humor.",
            "En varsam och poetisk guide som gör det vardagliga vackert.",
            "En tydlig och omtänksam guide som hjälper mig att landa när tankarna snurrar."
        ] : [
            "A warm, grounded guide who welcomes me exactly as I am.",
            "A quiet, thoughtful guide who leaves room for silence.",
            "A kind, curious guide who helps me meet myself without judgment.",
            "A reassuring, gentle guide with a subtle sense of humour.",
            "A tender, poetic guide who finds beauty in ordinary things.",
            "A clear, caring guide who helps me settle when my thoughts are busy."
        ]
        let approach = swedish ? [
            "Utgå från andetaget och kroppens kontakt med marken.",
            "Använd enkla bilder av havet, vinden och det som får ta sin tid.",
            "Bjud in mig att lägga märke till känslor utan att behöva förändra dem.",
            "Hjälp mig att lyssna på kroppen och mjukna där jag håller spänning.",
            "Låt ljuden omkring mig bli en väg tillbaka till nuet.",
            "Påminn mig varsamt om att jag får börja om, så många gånger jag behöver."
        ] : [
            "Begin with the breath and the feeling of the ground beneath me.",
            "Use simple images of the sea, the wind, and things that take their time.",
            "Invite me to notice feelings without needing to change them.",
            "Help me listen to my body and soften where I hold tension.",
            "Let the sounds around me become a way back to the present.",
            "Gently remind me that I can begin again as often as I need."
        ]
        let delivery = swedish ? [
            "Tala enkelt, med korta meningar och gott om luft mellan orden.",
            "Ge vänliga förslag och låt mig välja det som känns rätt.",
            "Håll språket mjukt och konkret, med få men meningsfulla ord.",
            "Var personlig och lugn, som en vän som sitter bredvid mig."
        ] : [
            "Speak simply, with short sentences and plenty of space between words.",
            "Offer gentle invitations and let me choose what feels right.",
            "Keep the language soft and concrete, with few but meaningful words.",
            "Be personal and calm, like a friend sitting beside me."
        ]
        // Choose among distinct combinations, including when a seeded RNG is used.
        let options = presence.flatMap { p in approach.flatMap { a in delivery.map { "\(p) \(a) \($0)" } } }
            .filter { $0 != previous }
        return options.randomElement(using: &random) ?? presence[0]
    }
}

struct CustomGuideVoice: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let language: CustomGuideLanguage
    let previewURL: URL
    var detail = ""
    var accent = ""
    var category: String?
    var gender: String?

    init(id: String, name: String, language: CustomGuideLanguage, previewURL: URL, detail: String = "", accent: String = "", category: String? = nil, gender: String? = nil) {
        self.id = id
        self.name = name
        self.language = language
        self.previewURL = previewURL
        self.detail = detail
        self.accent = accent
        self.category = category
        self.gender = gender
    }

    static func examples(for language: CustomGuideLanguage) -> [Self] {
        catalog.filter { $0.language == language }
    }

    // Curated prototype auditions, not the full Voice Library. Public, pre-rendered
    // samples from ElevenLabs' Voice Picker / Get Voice docs (English) and
    // https://elevenlabs.io/text-to-speech/{swedish,spanish,french,norwegian,danish}.
    // Observed 2026-10-01. No API key or synthesis request. Production should use
    // verified_languages + its language-specific preview_url from the Voices API.
    private static let catalog: [Self] = [
        .init(id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", language: .english,
              path: "premade/voices/21m00Tcm4TlvDq8ikWAM/b4928a68-c03b-411f-8533-3d5c299fd451.mp3"),
        .init(id: "29vD33N1CtxCmqQRPOHJ", name: "Drew", language: .english,
              path: "premade/voices/29vD33N1CtxCmqQRPOHJ/b99fc51d-12d3-4312-b480-a8a45a7d51ef.mp3"),
        .init(id: "9BWtsMINqrJLrRacOk9x", name: "Aria", language: .english,
              path: "premade/voices/9BWtsMINqrJLrRacOk9x/405766b8-1f4e-4d3c-aba1-6f25333823ec.mp3"),
        .init(id: "2EiwWnXFnvU5JabPnv8n", name: "Clyde", language: .english,
              path: "premade/voices/2EiwWnXFnvU5JabPnv8n/65d80f52-703f-4cae-a91d-75d4e200ed02.mp3"),
        .init(id: "aSLKtNoVBZlxQEMsnGL2", name: "Sanna Hartfield", language: .swedish,
              path: "custom/voices/aSLKtNoVBZlxQEMsnGL2/g7yysxvG83AAWczMihDs.mp3"),
        .init(id: "kkwvaJeTPw4KK0sBdyvD", name: "Bengt", language: .swedish,
              path: "database/user/V3Gpka2WxEYJYHlfzaeGy6jy6lQ2/voices/kkwvaJeTPw4KK0sBdyvD/47jpMs5V1lj0sfieKg0D.mp3"),
        .init(id: "Nh2zY9kknu6z4pZy6FhD", name: "David Martin", language: .spanish,
              path: "database/user/8RYUsFHsalUXjwVG0LjhNwH1j022/voices/Nh2zY9kknu6z4pZy6FhD/5VD3I67SoLbajJEbw7rH.mp3"),
        .init(id: "l1zE9xgNpUTaQCZzpNJa", name: "Alberto Rodríguez", language: .spanish,
              path: "custom/voices/l1zE9xgNpUTaQCZzpNJa/sF0SJSVjERJtMSqfZLPN.mp3"),
        .init(id: "aQROLel5sQbj1vuIVi6B", name: "Nicolas", language: .french,
              path: "database/workspace/7593eab373974d1db7d45255c5986d46/voices/aQROLel5sQbj1vuIVi6B/shwzqRrR51OISZWUl7EN.mp3"),
        .init(id: "a5n9pJUnAhX4fn7lx3uo", name: "Martin Dupont", language: .french,
              path: "custom/voices/a5n9pJUnAhX4fn7lx3uo/I5TRksrWlXu6l80nTPu2.mp3"),
        .init(id: "BGEU6wFi2uNm6Kje1Yhk", name: "Maja", language: .norwegian,
              path: "database/workspace/ed9b05e6324c457685490352e9a1ec90/voices/BGEU6wFi2uNm6Kje1Yhk/gCIHS9pPkrtwiAjN4VgG.mp3"),
        .init(id: "Hp07ONf6C5qlCKOeB4oo", name: "Constantin Birkedal", language: .danish,
              path: "custom/voices/Hp07ONf6C5qlCKOeB4oo/C96hZPXoNWAzYw5L7Dg6.mp3")
    ]

    private init(id: String, name: String, language: CustomGuideLanguage, path: String) {
        self.id = id
        self.name = name
        self.language = language
        previewURL = URL(string: "https://storage.googleapis.com/eleven-public-prod/\(path)")!
    }
}
