import AppIntents
import Foundation
import SwiftUI

/// Siri intent: Ask Kai for a personalized meditation.
/// This intent is conversational and will prompt for mood and duration if missing.
struct StartKaiMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Mimir for Meditation"
    static var description: IntentDescription = "Ask Mimir to craft a personalized meditation for you."

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Mood", requestValueDialog: "How are you feeling right now?")
    var mood: String

    @Parameter(title: "Duration", requestValueDialog: "How long would you like to meditate for?")
    var duration: DurationOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared
        
        // 1. Hand off to the app UI
        manager.siriPendingMood = mood
        manager.siriPendingDuration = duration.minutes
        manager.isSiriTriggeredKai = true
        
        return .result(dialog: "Opening Vindla... Mimir is aligning your path now.")
    }
}
