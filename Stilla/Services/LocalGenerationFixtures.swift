import Foundation

/// Bundled examples for development. No credentials, attestation or network.
/// Kept out of Release builds so a development preference cannot leak to users.
#if DEBUG
enum LocalGenerationFixtures {
    static func script(input: String, minutes: Int, personality: KaiPersonality,
                       kind: ZenSessionRequest.Kind, stillnessRatio: Double = 0.5) -> MeditationScript {
        let duration = min(30, max(1, minutes))
        let request = ZenSessionRequest.parse(input)
        let prefix = kind == .sleepStory ? "zen.mock.story" : "zen.mock.meditation"
        let focusKey = "zen.mock.focus.\(request.focus.rawValue)"
        var texts = [localized("\(prefix).opening")]
        if kind == .meditation { texts.append(localized(focusKey)) }
        texts += (1...4).map { localized("\(prefix).\($0)") }
        texts.append(localized("\(prefix).closing"))

        // Longer story fixtures repeat the quiet middle passages to exercise
        // continuous narration. This is intentionally not a generated story.
        if kind == .sleepStory {
            let middle = Array(texts.dropFirst().dropLast())
            let estimatedSeconds = texts.reduce(0.0) { $0 + Double($1.count) * 0.07 + 1.2 }
            let loops = max(1, Int(Double(duration * 60) / max(1, estimatedSeconds)))
            texts = [texts[0]] + Array(repeating: middle, count: loops).flatMap { $0 } + [texts.last!]
        } else if stillnessRatio > 0.7 {
            texts = [texts[0], texts[1], texts[3], texts.last!]
        }
        let script = MeditationScript(
            title: localized("\(prefix).title"), durationMinutes: duration,
            steps: texts.map { ScriptStep(text: $0, pauseDuration: kind == .sleepStory ? 1.2 : 10) },
            tags: ["Local Preview"], kaiPersonalityID: personality.id,
            kaiPersonalityName: personality.localizedName,
            guidanceHeader: localized("\(prefix).title"),
            guidanceBody: localized(focusKey),
            contentType: kind == .sleepStory ? .sleepStory : .meditation
        )
        return kind == .sleepStory ? script : KaiBrainService.shared.normalizeScriptDuration(script)
    }

    private static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}
#endif
