import Foundation

func voice(_ id: String, language: CustomGuideLanguage = .swedish,
           category: String? = "high_quality", gender: String? = nil,
           detail: String = "", url: String = "https://storage.googleapis.com/eleven-public-prod/test.mp3") -> CustomGuideVoice {
    .init(id: id, name: id, language: language, previewURL: URL(string: url)!,
          detail: detail, category: category, gender: gender)
}

let woman = voice("woman", gender: "female", detail: "A warm, calm voice")
let man = voice("man", gender: "male", detail: "A deep voice")
let neutral = voice("neutral", gender: "neutral")
let unknown = voice("unknown")
let english = voice("woman", language: .english, gender: "female", detail: "A warm, calm voice")
let unverified = voice("unverified", category: nil, gender: "female", detail: "High quality calm voice")
let professional = voice("professional", category: "professional", gender: "female")
let invalidURL = voice("invalid", gender: "female", url: "https://api.elevenlabs.io/v1/text-to-speech/example")
let catalog = [woman, man, neutral, unknown, english, unverified, professional, invalidURL]

func results(language: CustomGuideLanguage = .swedish, text: String = "",
             tone: CustomGuideVoiceCatalog.Tone = .all,
             gender: CustomGuideVoiceCatalog.Gender = .all) -> [CustomGuideVoice] {
    CustomGuideVoiceCatalog.search(catalog, language: language, text: text, tone: tone, gender: gender)
}

precondition(results() == [woman, man, neutral, unknown], "Only high-quality, safe previews in the chosen language")
precondition(results(gender: .female) == [woman], "Gender must come from metadata")
precondition(results(gender: .male) == [man])
precondition(results(language: .english, gender: .female) == [english], "Language-specific sample for a shared voice ID")
precondition(results(text: "WARM woman", tone: .calm, gender: .female) == [woman], "All filters combine")
precondition(results(tone: .calm, gender: .male).isEmpty, "Do not broaden filters on an empty result")

// The existing favourites format has neither category nor gender. It must still
// decode and use current metadata, including the correct language-specific URL.
let oldJSON = Data(#"[{"id":"woman","name":"Old name","language":"sv","previewURL":"https://storage.googleapis.com/eleven-public-prod/old.mp3","detail":"","accent":""},{"id":"unverified","name":"Saved low quality","language":"sv","previewURL":"https://storage.googleapis.com/eleven-public-prod/test.mp3","detail":"","accent":""}]"#.utf8)
let saved = try JSONDecoder().decode([CustomGuideVoice].self, from: oldJSON)
precondition(saved[0].category == nil && saved[0].gender == nil)
let favorites = CustomGuideVoiceCatalog.favorites(saved, in: catalog)
precondition(favorites == [woman], "Hydrate old favourites and exclude ineligible voices without crossing languages")
precondition(CustomGuideVoiceCatalog.search(favorites, language: .swedish, text: "", tone: .all, gender: .female) == [woman])
let roundTrip = try JSONDecoder().decode([CustomGuideVoice].self, from: JSONEncoder().encode(favorites))
precondition(roundTrip == favorites, "Preserve quality and gender when saving favourites")

var draft = CustomGuideDraft(language: .swedish)
draft.personality = "Warm and calm"
draft.voiceID = woman.id
draft.voiceName = woman.name
draft.voicePreviewURL = woman.previewURL
draft.selectLanguage(.english)
precondition(draft.voiceID == nil && draft.voiceName == nil && draft.voicePreviewURL == nil)
precondition(draft.personality == "Warm and calm")

// Validate the real bundled snapshot using the same Codable model as the app.
let snapshotURL = URL(fileURLWithPath: CommandLine.arguments[1])
let snapshot = try JSONDecoder().decode(CustomGuideVoiceCatalog.Snapshot.self, from: Data(contentsOf: snapshotURL))
precondition(!snapshot.voices.isEmpty)
precondition(snapshot.voices.allSatisfy { ["high_quality", "premade"].contains($0.category ?? "") && CustomGuideVoiceCatalog.isExistingPreviewURL($0.previewURL) })
precondition(Set(snapshot.voices.map(CustomGuideVoiceCatalog.key)).count == snapshot.voices.count)
for language in CustomGuideLanguage.allCases {
    let matching = CustomGuideVoiceCatalog.search(snapshot.voices, language: language, text: "", tone: .all)
    precondition(!matching.isEmpty, "Each supported language needs previews")
    for gender in [CustomGuideVoiceCatalog.Gender.female, .male] {
        precondition(!CustomGuideVoiceCatalog.search(matching, language: language, text: "", tone: .all, gender: gender).isEmpty)
    }
}
print("Voice catalogue checks passed: quality, language, gender, combined filters, legacy favourites and bundled snapshot (\(snapshot.voices.count) previews).")

let standard = voice("standard", category: "premade", gender: "female")
precondition(CustomGuideVoiceCatalog.search([standard, professional], language: .swedish, text: "", tone: .all) == [standard])
