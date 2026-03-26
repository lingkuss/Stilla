import SwiftUI
import AppIntents
import AVFoundation

@main
struct MeditationTimerApp: App {
    @State private var manager = MeditationManager.shared

    init() {
        configureAudioSession()
        
        // Force iOS to refresh Siri shortcuts to catch any new additions
        Task {
            MeditationShortcuts.updateAppShortcutParameters()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}
