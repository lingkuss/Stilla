import AppIntents

/// Registers Siri Shortcuts so users can invoke them without manual setup.
struct MeditationShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMeditationIntent(),
            phrases: [
                "Begin \(.applicationName)",
                "Begin meditating with \(.applicationName)",
                "Begin meditation with \(.applicationName)",
                "Meditate with \(.applicationName)",
                "Meditate for \(\.$duration) with \(.applicationName)",
            ],
            shortTitle: "Begin Meditation",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: StartOpenEndedMeditationIntent(),
            phrases: [
                "Begin limitless meditation with \(.applicationName)",
                "Begin limitless with \(.applicationName)"
            ],
            shortTitle: "Begin Limitless Meditation",
            systemImageName: "stopwatch"
        )

        AppShortcut(
            intent: StopMeditationIntent(),
            phrases: [
                "End \(.applicationName)",
                "End meditating with \(.applicationName)",
                "End meditation with \(.applicationName)"
            ],
            shortTitle: "End Meditation",
            systemImageName: "stop.circle"
        )
        
        AppShortcut(
            intent: StartKaiMeditationIntent(),
            phrases: [
                "Ask Mimir for a meditation in \(.applicationName)",
                "Ask Mimir for a \(\.$duration) meditation in \(.applicationName)",
                "Generate a meditation with Mimir in \(.applicationName)"
            ],
            shortTitle: "Ask Mimir",
            systemImageName: "sparkles"
        )
    }
}
