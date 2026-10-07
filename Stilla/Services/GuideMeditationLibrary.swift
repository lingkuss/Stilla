import Foundation

/// Authored English practices with measured local narration. Never generates online.
enum GuideMeditationLibrary {
    /// Finite silent media used for real pauses between recorded phrases.
    static var pauseURL: URL? {
        Bundle.main.url(forResource: "pause", withExtension: "m4a", subdirectory: "GuideMeditations")
    }
    struct Cue: Decodable {
        let id: String
        let phase: String
        let pauseWeight: Double
        let text: String
    }
    struct Practice: Decodable {
        let id: String
        let minutes: Int
        let title: String
        let summary: String
        let cueIDs: [String]
    }
    struct Guide: Decodable {
        let id: String
        let name: String
        let cues: [Cue]
        let sessions: [Practice]
    }
    struct Catalog: Decodable {
        let version: Int
        let language: String
        let durations: [Int]
        let guides: [Guide]
    }
    struct Recording: Decodable {
        let cueID: String
        let guideID: String
        let language: String
        let text: String
        let file: String
        let duration: TimeInterval
        var url: URL? { Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "GuideMeditations") }
    }
    private struct AudioManifest: Decodable { let clips: [Recording] }
    static let catalog: Catalog? = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "GuideMeditations"),
              let data = try? Data(contentsOf: url), let result = try? JSONDecoder().decode(Catalog.self, from: data),
              result.version == 1, result.language == "en", result.durations == [5,10,15,20,25,30],
              Set(result.guides.map(\.id)).count == result.guides.count else { return nil }
        for guide in result.guides {
            let cueIDs = Set(guide.cues.map(\.id))
            guard cueIDs.count == guide.cues.count,
                  guide.cues.allSatisfy({ !$0.text.isEmpty && $0.pauseWeight.isFinite && $0.pauseWeight > 0 }),
                  Set(guide.sessions.map(\.minutes)) == Set(result.durations),
                  Set(guide.sessions.map(\.id)).count == guide.sessions.count,
                  guide.sessions.allSatisfy({ !$0.cueIDs.isEmpty && Set($0.cueIDs).isSubset(of: cueIDs) }) else { return nil }
        }
        return result
    }()
    private static let recordings: [Recording] = {
        guard let url = Bundle.main.url(forResource: "audio", withExtension: "json", subdirectory: "GuideMeditations"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(AudioManifest.self, from: data) else { return [] }
        return manifest.clips.filter {
            $0.language == "en" && !$0.file.contains("/") && $0.duration.isFinite && $0.duration > 0 && $0.url != nil
        }
    }()

    static func practice(minutes: Int, guideID: String) -> Practice? {
        catalog?.guides.first(where: { $0.id == guideID })?.sessions.first(where: { $0.minutes == minutes })
    }

    static func script(minutes: Int, personality: KaiPersonality) -> MeditationScript? {
        guard let guide = catalog?.guides.first(where: { $0.id == personality.id }),
              let practice = practice(minutes: minutes, guideID: personality.id) else { return nil }
        let cues = practice.cueIDs.compactMap { id in guide.cues.first(where: { $0.id == id }) }
        guard cues.count == practice.cueIDs.count else { return nil }
        let script = MeditationScript(title: practice.title, durationMinutes: minutes,
            steps: cues.map { ScriptStep(text: $0.text, pauseDuration: $0.pauseWeight) },
            tags: ["English", "Guided Practice"], kaiPersonalityID: personality.id,
            kaiPersonalityName: personality.localizedName, guidanceHeader: practice.title,
            guidanceBody: practice.summary, narrationLanguage: "en", localNarrationID: practice.id)
        return timedScript(script)
    }

    private static func matchingCues(_ script: MeditationScript) -> [Cue]? {
        guard !script.isSleepStory, script.narrationLanguage == "en",
              let guide = catalog?.guides.first(where: { $0.id == script.kaiPersonalityID }),
              let practice = guide.sessions.first(where: { $0.id == script.localNarrationID && $0.minutes == script.durationMinutes }) else { return nil }
        let cues = practice.cueIDs.compactMap { id in guide.cues.first(where: { $0.id == id }) }
        guard cues.count == script.steps.count, cues.map(\.text) == script.steps.map(\.text) else { return nil }
        return cues
    }

    static func recording(for script: MeditationScript, step: Int) -> Recording? {
        guard let cues = matchingCues(script), cues.indices.contains(step) else { return nil }
        let cue = cues[step]
        return recordings.first {
            $0.guideID == script.kaiPersonalityID && $0.cueID == cue.id && $0.text == cue.text
        }
    }

    static func hasCompleteRecording(_ script: MeditationScript) -> Bool {
        guard matchingCues(script) != nil, pauseURL != nil else { return false }
        let clips = script.steps.indices.compactMap { recording(for: script, step: $0) }
        return clips.count == script.steps.count
            && clips.reduce(2.0, { $0 + $1.duration }) + Double(clips.count) * 2 < Double(script.durationMinutes * 60)
    }

    /// Preserve the editorial pause proportions, using real audio lengths when
    /// available. Leave a small final pause so scheduler jitter never cuts closing words.
    static func timedScript(_ script: MeditationScript) -> MeditationScript {
        guard let cues = matchingCues(script) else { return script }
        let recorded = hasCompleteRecording(script)
        let speaking = script.steps.indices.reduce(0.0) { total, index in
            total + (recorded ? recording(for: script, step: index)!.duration : Double(script.steps[index].text.count) * 0.07)
        }
        let silence = max(Double(cues.count) * 2, Double(script.durationMinutes * 60) - 2 - speaking)
        let reserved = Double(cues.count) * 2
        let totalWeight = cues.reduce(0.0) { $0 + $1.pauseWeight }
        var result = script
        for index in result.steps.indices {
            result.steps[index].pauseDuration = 2 + (silence - reserved) * cues[index].pauseWeight / totalWeight
        }
        return result
    }
}
