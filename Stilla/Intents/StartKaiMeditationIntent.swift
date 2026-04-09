import AppIntents
import Foundation
import SwiftUI

/// Siri intent: Ask Kai for a personalized meditation.
/// This intent is conversational and will prompt for mood and duration if missing.
struct StartKaiMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.start_kai.title"
    static var description: IntentDescription = IntentDescription("intent.start_kai.description")

    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "intent.start_kai.parameter.mood.title",
        requestValueDialog: "intent.start_kai.parameter.mood.prompt"
    )
    var mood: String

    @Parameter(
        title: "intent.common.duration",
        requestValueDialog: "intent.start_kai.parameter.duration.prompt"
    )
    var duration: DurationOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared

        // 1. Hand off to the app UI
        manager.siriPendingMood = mood
        manager.siriPendingDuration = duration.minutes
        manager.isSiriTriggeredKai = true

        return .result(dialog: IntentDialog("intent.start_kai.dialog.opening"))
    }
}
