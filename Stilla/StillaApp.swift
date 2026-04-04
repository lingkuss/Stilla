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
                .onOpenURL { url in
                    handleIncomingShare(url)
                }
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

    private func handleIncomingShare(_ url: URL) {
        print("🔗 KAI: Received Deep Link: \(url.absoluteString)")
        guard manager.state != .meditating else { 
            print("⚠️ KAI: Ignoring link because already meditating.")
            return 
        }
        
        guard let id = extractShareID(from: url) else { 
            print("❌ KAI: No 'id' found in URL.")
            return 
        }
        
        Task {
            print("📥 KAI: Fetching payload for ID: \(id)")
            if let payload = await fetchSessionPayload(id: id) {
                let script = payload.script.toFullScript()
                print("✅ KAI: Payload received. Title: \(script.title)")
                
                await MainActor.run {
                    // Force dismiss everything to show the session
                    manager.shouldDismissSheets = true
                    
                    print("🚀 KAI: Atomic start for shared script: \(script.title)")
                    manager.startSharedSession(script: script)
                }
            } else {
                print("❌ KAI: Failed to fetch payload from backend.")
            }
        }
    }

    private func fetchSessionPayload(id: String) async -> ShareSessionPayload? {
        let url = URL(string: "https://stilla-api.vercel.app/kai/share?id=\(id)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            return try decoder.decode(ShareSessionPayload.self, from: data)
        } catch {
            print("Failed to fetch shared session: \(error)")
            return nil
        }
    }

    private func extractShareID(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "id" })?.value
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
