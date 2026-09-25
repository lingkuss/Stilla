import Foundation

/// A bundled, intentionally sparse meditation. No generation request or subscription is needed.
enum DestinationMeditationContent {
    static let durations = [5, 10, 15, 20]

    static func script(minutes: Int, destination: JourneyDestination) -> MeditationScript {
        let phrases = (1...5).map { NSLocalizedString("journey.guidance.\($0)", comment: "") }
        // Leave a generous speech allowance; the remainder belongs to quiet practice.
        let silence = max(0, Double(minutes * 60) - 95)
        let weights = [0.12, 0.28, 0.30, 0.25, 0.05]
        return MeditationScript(
            title: String(format: NSLocalizedString("journey.meditation_title", comment: ""), destination.name),
            durationMinutes: minutes,
            steps: zip(phrases, weights).map { ScriptStep(text: $0.0, pauseDuration: silence * $0.1) },
            kaiPersonalityID: KaiPersonality.zenMinimalist.id,
            kaiPersonalityName: KaiPersonality.zenMinimalist.localizedName)
    }
}
