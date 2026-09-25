import Foundation

/// Deliberately local routing. The original request is also passed to the script
/// generator; these rules only choose a session type and a reviewable duration.
struct ZenSessionRequest: Equatable {
    enum Kind: String { case meditation, sleepStory }
    enum Focus: String { case rest, stress, focus, sleep }

    let input: String
    var kind: Kind
    var minutes: Int
    let focus: Focus
    let durationWasClamped: Bool

    static func parse(_ input: String, maximumMinutes: Int = 30) -> Self {
        let normalized = input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "sv_SE"))
        let words = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let tokens = Set(words)
        let explicitMeditation = words.contains { $0.hasPrefix("medit") }
        let story = words.contains { $0.hasPrefix("somnberatt") || $0.hasPrefix("sovhistori") }
            || normalized.contains("sleep story") || normalized.contains("bedtime story")
        let sleep = !tokens.isDisjoint(with: ["sova", "somn", "somna", "sleep", "dormir", "sove", "sovn", "dormire"])
        let kind: Kind = story || (sleep && !explicitMeditation) ? .sleepStory : .meditation
        let focus: Focus = kind == .sleepStory ? .sleep
            : words.contains(where: { $0.hasPrefix("stress") || $0.hasPrefix("orol") || $0.hasPrefix("anx") }) ? .stress
            : words.contains(where: { $0.hasPrefix("fokus") || $0.hasPrefix("focus") || $0.hasPrefix("koncentr") }) ? .focus
            : .rest
        let numberWords = ["en": 1, "ett": 1, "one": 1, "tva": 2, "two": 2, "tre": 3, "three": 3,
                           "fyra": 4, "four": 4, "fem": 5, "five": 5, "sex": 6, "six": 6,
                           "sju": 7, "seven": 7, "atta": 8, "eight": 8, "nio": 9, "nine": 9,
                           "tio": 10, "ten": 10, "elva": 11, "eleven": 11, "tolv": 12, "twelve": 12,
                           "femton": 15, "fifteen": 15, "tjugo": 20, "twenty": 20,
                           "tjugofem": 25, "trettio": 30, "thirty": 30, "fyrtio": 40, "sextio": 60]
        var requested: Int?
        // Only numbers followed by a time unit count: “jag är 20 och stressad”
        // must not accidentally request a twenty-minute session.
        for (index, word) in words.enumerated() where index + 1 < words.count {
            let unit = words[index + 1]
            if unit.hasPrefix("min") || unit == "m" {
                requested = Int(word) ?? numberWords[word]
            } else if unit.hasPrefix("timm") || unit.hasPrefix("hour") {
                if let hours = Int(word) ?? numberWords[word] { requested = min(hours, 24) * 60 }
            }
        }
        // Speech recognition and keyboards may produce “10min” without a space.
        if requested == nil,
           let range = normalized.range(of: #"\b[0-9]+(?=min(?:ut(?:er|es)?)?\b)"#, options: .regularExpression) {
            requested = Int(normalized[range])
        }
        if normalized.contains("halvtimme") || normalized.contains("halv timme") || normalized.contains("half an hour") {
            requested = 30
        } else if normalized.contains("en kvart") || normalized.contains("a quarter of an hour") {
            requested = 15
        }
        let raw = requested ?? (kind == .sleepStory ? 20 : 10)
        let minutes = min(maximumMinutes, max(1, raw))
        return Self(input: input.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind,
                    minutes: minutes, focus: focus, durationWasClamped: minutes != raw)
    }
}
