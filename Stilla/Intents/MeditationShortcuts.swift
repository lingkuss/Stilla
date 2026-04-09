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
                "Inicia \(.applicationName)",
                "Inicia meditación con \(.applicationName)",
                "Meditar con \(.applicationName)",
                "Meditar \(\.$duration) con \(.applicationName)",
                "Lance \(.applicationName)",
                "Commence la méditation avec \(.applicationName)",
                "Méditer avec \(.applicationName)",
                "Start meditasjon med \(.applicationName)",
                "Mediter med \(.applicationName)",
                "Start meditation med \(.applicationName)",
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
                "Inicia meditación ilimitada con \(.applicationName)",
                "Inicia ilimitada con \(.applicationName)",
                "Lance une méditation illimitée avec \(.applicationName)",
                "Start ubegrenset meditasjon med \(.applicationName)",
                "Start ubegrænset meditation med \(.applicationName)",
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
                "Termina \(.applicationName)",
                "Termina meditación con \(.applicationName)",
                "Detener meditación con \(.applicationName)",
                "Arrête \(.applicationName)",
                "Termine la méditation avec \(.applicationName)",
                "Avslutt meditasjon med \(.applicationName)",
                "Afslut meditation med \(.applicationName)",
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
                "Pide a Mimir una meditación en \(.applicationName)",
                "Pide a Mimir una meditación de \(\.$duration) en \(.applicationName)",
                "Genera una meditación con Mimir en \(.applicationName)",
                "Demande à Mimir une méditation dans \(.applicationName)",
                "Be Mimir om en meditasjon i \(.applicationName)",
                "Bed Mimir om en meditation i \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.start_kai.short_title",
            systemImageName: "sparkles"
        )
    }
}
