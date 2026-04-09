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
                "Starta \(.applicationName)",
                "Starta meditation med \(.applicationName)",
                "Meditera med \(.applicationName)",
                "Meditera i \(\.$duration) med \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.start.short_title",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: StartOpenEndedMeditationIntent(),
            phrases: [
                "Begin limitless meditation with \(.applicationName)",
                "Begin limitless with \(.applicationName)",
                "Starta obegransad meditation med \(.applicationName)",
                "Starta obegransad med \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.start_open_ended.short_title",
            systemImageName: "stopwatch"
        )

        AppShortcut(
            intent: StopMeditationIntent(),
            phrases: [
                "End \(.applicationName)",
                "End meditating with \(.applicationName)",
                "End meditation with \(.applicationName)",
                "Stoppa \(.applicationName)",
                "Stoppa meditation med \(.applicationName)",
                "Avsluta meditation med \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.stop.short_title",
            systemImageName: "stop.circle"
        )

        AppShortcut(
            intent: StartKaiMeditationIntent(),
            phrases: [
                "Ask Mimir for a meditation in \(.applicationName)",
                "Ask Mimir for a \(\.$duration) meditation in \(.applicationName)",
                "Generate a meditation with Mimir in \(.applicationName)",
                "Be Mimir om en meditation i \(.applicationName)",
                "Be Mimir om en \(\.$duration) meditation i \(.applicationName)",
                "Skapa en meditation med Mimir i \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.start_kai.short_title",
            systemImageName: "sparkles"
        )
    }
}
