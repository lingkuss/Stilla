import SwiftUI
import AppIntents
import AVFoundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["open_kai"] as? Bool == true {
            Task { @MainActor in
                MeditationManager.shared.isSiriTriggeredKai = true
            }
        }
        completionHandler()
    }
}

@main
struct StillaApp: App {
    @State private var manager = MeditationManager.shared
    @UIApplicationDelegateAdaptor private var notificationDelegate: AppNotificationDelegate

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

final class AppNotificationDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
