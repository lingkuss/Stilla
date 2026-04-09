import AppIntents
import Foundation

/// Siri intent: Stop the current meditation session.
/// Triggered by: "Hey Siri, stop Vindla"
struct StopMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.stop_meditation.title"
    static var description: IntentDescription = IntentDescription("intent.stop_meditation.description")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared
        manager.stop()
        return .result(dialog: IntentDialog("intent.stop_meditation.dialog.stopped"))
    }
}
