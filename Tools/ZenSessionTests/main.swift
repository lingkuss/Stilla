import Foundation

// App-shell dependencies are intentionally traps. The actual service, parser,
// fixture builder and data models below are compiled without any substitutions.
struct Secrets {
    static var kaiBackendURL: URL? { fatalError("A local test accessed the generation endpoint") }
    static var kaiSleepStoryBackendURL: URL? { fatalError("A local test accessed the sleep endpoint") }
}
@main struct LocalGenerationChecks {
    static func verifyRetiredFeatureMigration() throws {
        let suite = "vindla.retired-practice-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let script = MeditationScript(title: "Saved meditation", durationMinutes: 10,
            steps: [ScriptStep(text: "Rest with your breath.", pauseDuration: 12)],
            isFavorite: true, tags: ["Daily Path", "Day 3"],
            narrationLanguage: "en", localNarrationID: "saved-narration")
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(script)) as! [String: Any]
        legacy["practiceJourneyPlanID"] = UUID().uuidString
        legacy["practiceJourneyStepID"] = UUID().uuidString
        legacy["practiceJourneyDayNumber"] = 3
        legacy["practiceJourneyCycleNumber"] = 1
        legacy["practiceJourneyTitle"] = "Legacy path"
        let savedScripts = try JSONSerialization.data(withJSONObject: [legacy])
        let memories = try JSONEncoder().encode([SessionMemory(startedAt: Date(),
            durationSeconds: 600, reflection: "A calm moment")])
        defaults.set(savedScripts, forKey: "savedMeditations")
        defaults.set(memories, forKey: "recentSessionMemories")
        defaults.set(["2026-10-01": 3000], forKey: "meditationHistory")
        defaults.set(Data("preserved garden ledger".utf8), forKey: "vindla.stillnessGarden.v1")
        defaults.set(Data("preserved sound choices".utf8), forKey: "mountain.prototype.meditation.preferences.v1")
        defaults.set(Data("preserved mountain progress".utf8), forKey: "mountainJourney.region.preview.v1")
        defaults.set(10, forKey: "durationMinutes")
        let preserved = defaults.persistentDomain(forName: suite)!
        let retiredKeys = ["activePracticeJourneyPlan", "completedPracticeJourneyPlans",
            "practiceJourneyPrimaryGoal", "practiceJourneyMainObstacle", "practiceJourneyPreferredStyle",
            "destinationJourney.progress.v1", "destinationJourney.selectedID"]
        for key in retiredKeys { defaults.set(Data("old or malformed plan data".utf8), forKey: key) }

        RetiredFeatureData.remove(from: defaults)
        RetiredFeatureData.remove(from: defaults)
        precondition(retiredKeys.allSatisfy { defaults.object(forKey: $0) == nil })
        precondition(NSDictionary(dictionary: preserved).isEqual(to: defaults.persistentDomain(forName: suite)!))
        let restored = try JSONDecoder().decode([MeditationScript].self, from: defaults.data(forKey: "savedMeditations")!)
        precondition(restored.count == 1 && restored[0].id == script.id)
        precondition(restored[0].title == script.title && restored[0].isFavorite)
        precondition(restored[0].steps[0].text == script.steps[0].text && restored[0].tags == script.tags)
        precondition(restored[0].localNarrationID == script.localNarrationID && restored[0].narrationLanguage == "en")
        let reencoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(restored[0])) as! [String: Any]
        precondition(!reencoded.keys.contains(where: { $0.hasPrefix("practiceJourney") }))
        print("PASS: retired plan/destination cleanup is idempotent; saved scripts, session history, mountain progress, audio and rewards survive unchanged")
    }

    static func main() async throws {
        try verifyRetiredFeatureMigration()
        let cases: [(String, ZenSessionRequest.Kind, Int)] = [
            ("Jag vill sova", .sleepStory, 20),
            ("ge mig en avslappnad sömnberättelse", .sleepStory, 20),
            ("jag vill meditera i tio minuter", .meditation, 10),
            ("jag vill ha en guidad meditation i 20 minuter", .meditation, 20),
            ("Jag är stressad", .meditation, 10),
            ("Meditera en halvtimme", .meditation, 30),
            ("Meditera i en kvart", .meditation, 15),
            ("Guidad meditation 10min", .meditation, 10),
            ("Jag är 20 och vill meditera", .meditation, 10),
            ("Jag vill inte sova, jag vill meditera i fem minuter", .meditation, 5),
            ("I want a sleep story for twenty minutes", .sleepStory, 20),
            ("Meditate for five minutes", .meditation, 5),
            ("Quiero dormir", .sleepStory, 20),
            ("Je veux dormir", .sleepStory, 20),
            ("Jag vill meditera i 90 minuter", .meditation, 30),
            ("Meditera i en timme", .meditation, 30),
            ("Meditera i 0 minuter", .meditation, 1)
        ]
        for (input, kind, minutes) in cases {
            let parsed = ZenSessionRequest.parse(input)
            precondition(parsed.kind == kind && parsed.minutes == minutes, "Wrong interpretation: \(input)")
        }
        precondition(ZenSessionRequest.parse("90 minuter").durationWasClamped)
        precondition(!ZenSessionRequest.parse("tio minuter").durationWasClamped)
        precondition(ZenSessionRequest.parse("Jag är stressad").focus == .stress)
        precondition(ZenSessionRequest.parse("Jag behöver fokus").focus == .focus)
        precondition(KaiBrainService.usesLocalScripts)
        let brain = KaiBrainService.shared
        let previousCredits = brain.freeCreditsRemaining
        let previousCount = UserDefaults.standard.object(forKey: "kai.free_gen_count") as? Int
        for _ in 0..<10 { brain.recordFreeGeneration() }
        precondition(brain.freeCreditsRemaining == previousCredits)
        precondition(UserDefaults.standard.object(forKey: "kai.free_gen_count") as? Int == previousCount)
        for minutes in [1, 10, 20, 30, 90] {
            let script = try await brain.generateScript(mood: "Jag är stressad", durationMinutes: minutes,
                                                       personality: .zenMinimalist, stillnessRatio: 0.5)
            precondition(script.durationMinutes == min(30, minutes))
            precondition(!script.isSleepStory && !script.steps.isEmpty)
            precondition(script.steps.allSatisfy { !$0.text.isEmpty && !$0.text.hasPrefix("zen.mock.") && $0.pauseDuration.isFinite && $0.pauseDuration >= 0 })
            precondition(script.kaiPersonalityID == KaiPersonality.zenMinimalist.id)
            let encoded = try JSONEncoder().encode(script)
            let decoded = try JSONDecoder().decode(MeditationScript.self, from: encoded)
            precondition(decoded.durationMinutes == script.durationMinutes)
        }
        let sleep = try await brain.generateSleepStory(themeTitle: "Sömnberättelse", themeSubtitle: nil,
                                                       durationMinutes: 20, excluding: [])
        precondition(sleep.script.isSleepStory && sleep.script.durationMinutes == 20)
        precondition(sleep.script.steps.allSatisfy { $0.pauseDuration < 2 })
        precondition(!sleep.nextHeaders.isEmpty)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await brain.generateScript(mood: "", durationMinutes: 10, personality: .zenMinimalist, stillnessRatio: 0.5)
        }
        do { _ = try await cancelled.value; preconditionFailure("Cancellation was ignored") }
        catch is CancellationError { }
        let fixture = try await brain.generateScript(mood: "rest", durationMinutes: 10,
            personality: .zenMinimalist, stillnessRatio: 0.5)
        precondition(ZenVoiceLibrary.supports(fixture), "Incomplete English voice pack")
        let timed = ZenVoiceLibrary.timedScript(fixture)
        let actualDuration = 2 + timed.steps.reduce(0.0) {
            $0 + $1.pauseDuration + ZenVoiceLibrary.clip(for: $1.text)!.duration
        }
        precondition(abs(actualDuration - 600) < 0.01, "Recorded clips must retain the ten-minute session")
        precondition(ZenVoiceLibrary.clip(for: "Ska vi börja med tio lugna minuter, bara för dig?") != nil)
        var changed = fixture
        changed.steps[0] = ScriptStep(text: changed.steps[0].text + " Updated text.", pauseDuration: 10)
        precondition(!ZenVoiceLibrary.supports(changed), "Never play stale audio")
        changed = fixture
        changed.kaiPersonalityID = "warm_guardian"
        precondition(!ZenVoiceLibrary.supports(changed), "Never use Zen's voice for another persona")
        precondition(!ZenVoiceLibrary.supports(sleep.script))
        changed = fixture
        changed.steps = Array(repeating: fixture.steps, count: 20).flatMap { $0 }
        changed.durationMinutes = 1
        precondition(!ZenVoiceLibrary.supports(changed), "Do not truncate long recordings in short sessions")
        print("PASS: local voice lookup, persona/text isolation and measured ten-minute duration")
        print("PASS: 17 requests, duration bounds, focus, both local generators, cancellation, unchanged credits and JSON round-trip. Endpoint traps were never accessed.")
    }
}
