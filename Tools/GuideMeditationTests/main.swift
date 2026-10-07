import Foundation

@main struct GuideMeditationChecks {
    static func main() throws {
        let expectRecordings = CommandLine.arguments.contains("--recordings")
        precondition(GuideMeditationLibrary.catalog != nil)
        var identities = Set<String>()
        for guide in KaiPersonality.all {
            var previousCount = 0
            for minutes in [5,10,15,20,25,30] {
                guard let script = GuideMeditationLibrary.script(minutes: minutes, personality: guide) else {
                    preconditionFailure("Missing \(guide.id)/\(minutes)")
                }
                precondition(script.kaiPersonalityID == guide.id && script.narrationLanguage == "en")
                precondition(script.durationMinutes == minutes && !script.isSleepStory)
                precondition(identities.insert(script.localNarrationID!).inserted)
                precondition(script.steps.count >= previousCount)
                previousCount = script.steps.count
                precondition(Set(script.steps.map(\.text)).count == script.steps.count, "No repeated padding passages")
                precondition(script.steps.allSatisfy { !$0.text.isEmpty && $0.pauseDuration.isFinite && (2..<180).contains($0.pauseDuration) })
                let complete = GuideMeditationLibrary.hasCompleteRecording(script)
                let timedAgain = GuideMeditationLibrary.timedScript(script)
                precondition(timedAgain.steps.map(\.pauseDuration) == script.steps.map(\.pauseDuration),
                             "Repeated preparation must not change the pause allocation")
                if expectRecordings { precondition(complete, "Missing audio for \(script.localNarrationID!)") }
                let total = script.steps.indices.reduce(2.0) { total, index in
                    total + script.steps[index].pauseDuration + (complete
                        ? GuideMeditationLibrary.recording(for: script, step: index)!.duration
                        : Double(script.steps[index].text.count) * 0.07)
                }
                precondition(abs(total - Double(minutes * 60)) < 0.001, "Wrong duration: \(total)")
                let roundTrip = try JSONDecoder().decode(MeditationScript.self, from: JSONEncoder().encode(script))
                precondition(roundTrip.localNarrationID == script.localNarrationID && roundTrip.narrationLanguage == "en")
                var changed = script
                changed.steps[0] = ScriptStep(text: "Changed wording.", pauseDuration: 3)
                precondition(!GuideMeditationLibrary.hasCompleteRecording(changed))
                precondition(GuideMeditationLibrary.recording(for: changed, step: 0) == nil)
                changed = script; changed.kaiPersonalityID = guide.id == "ra" ? "zen_minimalist" : "ra"
                precondition(!GuideMeditationLibrary.hasCompleteRecording(changed), "Wrong persona must never play another voice")
                changed = script; changed.contentType = .sleepStory
                precondition(!GuideMeditationLibrary.hasCompleteRecording(changed))
                changed = script; changed.narrationLanguage = "sv"
                precondition(!GuideMeditationLibrary.hasCompleteRecording(changed))
                changed = script; changed.localNarrationID = "unknown.practice"
                precondition(!GuideMeditationLibrary.hasCompleteRecording(changed))
                precondition(GuideMeditationLibrary.recording(for: script, step: -1) == nil)
                precondition(GuideMeditationLibrary.recording(for: script, step: script.steps.count) == nil)
            }
        }
        precondition(identities.count == 24)
        precondition(GuideMeditationLibrary.script(minutes: 7, personality: .zenMinimalist) == nil)
        precondition(GuideMeditationLibrary.script(minutes: 10, personality: .cosmicSage) == nil)
        let legacy = Data(#"{"title":"Saved practice","durationMinutes":10,"steps":[{"text":"Rest.","pauseDuration":20}]}"#.utf8)
        let restored = try JSONDecoder().decode(MeditationScript.self, from: legacy)
        precondition(restored.localNarrationID == nil && restored.narrationLanguage == nil)
        print("PASS: 24 distinct practices, growing guidance, no repeated filler, exact timing, persona/text/language isolation, saved-script compatibility")
        if expectRecordings { print("PASS: all 24 practices have complete local recordings") }
    }
}
