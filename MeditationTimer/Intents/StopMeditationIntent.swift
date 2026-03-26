import AppIntents
import Foundation

/// Siri intent: Stop the current meditation session.
/// Triggered by: "Hey Siri, stop MeditationTimer"
struct StopMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "End Meditation"
    static var description: IntentDescription = "End the current meditation session"

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared
        manager.stop()
        return .result(dialog: "Meditation ended. Namaste. 🙏")
    }
}
