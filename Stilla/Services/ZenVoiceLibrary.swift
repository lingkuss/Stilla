import Foundation

/// Prerecorded development voice pack. Exact text matching prevents stale audio
/// from being used after the fixture or a translation changes.
enum ZenVoiceLibrary {
    struct Clip: Decodable {
        let key: String
        let language: String
        let text: String
        let file: String
        let duration: TimeInterval

        var url: URL? { Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "ZenVoice") }
    }

    private struct Manifest: Decodable { let clips: [Clip] }
    private static let clips: [Clip] = {
        #if DEBUG
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "ZenVoice"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return [] }
        return manifest.clips.filter {
            ["sv", "en"].contains($0.language) && $0.duration.isFinite && $0.duration > 0
                && !$0.file.contains("/") && $0.url != nil
        }
        #else
        return []
        #endif
    }()

    static func clip(for text: String) -> Clip? {
        clips.first { $0.text == text.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    static func supports(_ script: MeditationScript) -> Bool {
        guard script.kaiPersonalityID == KaiPersonality.zenMinimalist.id, !script.isSleepStory,
              !script.steps.isEmpty, script.steps.allSatisfy({ clip(for: $0.text) != nil }) else { return false }
        // Do not select slower recordings for a session that would cut them off.
        let speech = script.steps.reduce(0.0) { $0 + (clip(for: $1.text)?.duration ?? 0) }
        return speech + 2 < Double(script.durationMinutes * 60)
    }

    /// The session's silence is based on measured clip lengths, not the old
    /// Apple-voice character estimate. The first phrase still starts at +2s.
    static func timedScript(_ script: MeditationScript) -> MeditationScript {
        guard supports(script) else { return script }
        let speakingTime = script.steps.reduce(0.0) { $0 + (clip(for: $1.text)?.duration ?? 0) }
        let silence = max(0, Double(script.durationMinutes * 60) - 2 - speakingTime)
        let weights = script.steps.map { max(0, $0.pauseDuration) }
        let totalWeight = weights.reduce(0, +)
        var result = script
        for index in result.steps.indices {
            result.steps[index].pauseDuration = totalWeight > 0
                ? silence * weights[index] / totalWeight : silence / Double(result.steps.count)
        }
        return result
    }
}
