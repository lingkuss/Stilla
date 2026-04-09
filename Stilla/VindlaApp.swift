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
struct VindlaApp: App {
    @State private var manager = MeditationManager.shared
    @AppStorage("app.language.override") private var appLanguageOverride = AppLocalization.LanguageOption.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor private var notificationDelegate: AppNotificationDelegate

    init() {
        AppLocalization.applyLanguageOverrideOnLaunch()
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
                .environment(\.locale, AppLocalization.locale(forRawValue: appLanguageOverride))
                .task {
                    await StoreKitManager.shared.updateCustomerProductStatus()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await StoreKitManager.shared.updateCustomerProductStatus()
                    }
                }
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
        print("🔗 MIMIR: Received Deep Link: \(url.absoluteString)")
        guard manager.state != .meditating else { 
            print("⚠️ MIMIR: Ignoring link because already meditating.")
            return 
        }
        
        guard let id = extractShareID(from: url) else { 
            print("❌ MIMIR: No 'id' found in URL.")
            return 
        }
        
        Task {
            print("📥 MIMIR: Fetching payload for ID: \(id)")
            if let payload = await fetchSessionPayload(id: id) {
                let script = payload.script.toFullScript()
                print("✅ MIMIR: Payload received. Title: \(script.title)")
                
                await MainActor.run {
                    // Force dismiss everything to show the session
                    manager.shouldDismissSheets = true
                    
                    print("🚀 MIMIR: Atomic start for shared script: \(script.title)")
                    manager.startSharedSession(script: script)
                }
            } else {
                print("❌ MIMIR: Failed to fetch payload from backend.")
            }
        }
    }

    private func fetchSessionPayload(id: String) async -> ShareSessionPayload? {
        guard let shareURL = Secrets.kaiShareBackendURL else {
            print("Failed to fetch shared session: missing KAIShareBackendURL/KAIBackendURL")
            return nil
        }

        let url = shareURL.appending(queryItems: [URLQueryItem(name: "id", value: id)])
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
