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
        if let routineID = userInfo["routine_id"] as? String {
            Task { @MainActor in
                await RoutineManager.shared.applyRoutineFromNotification(id: routineID)
            }
        } else if userInfo["open_kai"] as? Bool == true {
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
    #if DEBUG
    @State private var gardenPreviewVisible = true
    #endif

    init() {
        AppLocalization.applyLanguageOverrideOnLaunch()
        configureAudioSession()
        #if DEBUG
        configureGardenTestProfile()
        configureMountainTestAudio()
        Secrets.debugPrintResolvedConfig()
        #endif
        
        // Force iOS to refresh Siri shortcuts to catch any new additions
        Task {
            MeditationShortcuts.updateAppShortcutParameters()
        }
    }

    #if DEBUG
    /// Explicit device-test setup; normal launches preserve every sound choice.
    private func configureMountainTestAudio() {
        guard ProcessInfo.processInfo.arguments.contains("--mountain-enable-test-audio") else { return }
        let defaults = UserDefaults.standard
        let key = "mountain.prototype.meditation.preferences.v1"
        let saved = defaults.data(forKey: key) ?? Data()
        let backup = URL.documentsDirectory.appending(path: "MountainAudioBeforeTest.json")
        if !saved.isEmpty && !FileManager.default.fileExists(atPath: backup.path) {
            do { try saved.write(to: backup, options: .atomic) }
            catch { print("Could not back up mountain audio: \(error)"); return }
        }
        var preferences = MountainMeditationPreferences.restore(saved)
        let previousAmbience = SoundEngine.AmbientSound(rawValue: defaults.string(forKey: "ambientSound") ?? "") ?? .rain
        for mode in MountainSessionContext.Mode.allCases {
            preferences[mode].ambience = (previousAmbience == .none ? SoundEngine.AmbientSound.rain : previousAmbience).rawValue
            preferences[mode].breathingCues = true
            preferences[mode].ambienceVolume = 0.5
            preferences[mode].cueVolume = 0.5
        }
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: key) }
    }

    private func configureGardenTestProfile() {
        let args = ProcessInfo.processInfo.arguments
        let restore = args.contains("--garden-restore-profile")
        let count = args.firstIndex(of: "--garden-mock-count").flatMap { args.indices.contains($0+1) ? Int(args[$0+1]) : nil }
        guard restore || count != nil else { return }
        do {
            let store = StillnessGardenStore.shared
            if restore { try store.restoreBeforeMock() }
            else if let count {
                try store.setMockMeditations(count,backupURL: URL.documentsDirectory.appending(path: "GardenProfileBeforeMock.json"))
            }
            let receipt: [String: Any] = ["mode": restore ? "restored" : "mock",
                "meditations": store.meditationCount,"flowers": store.flowers.count,
                "crystals": store.crystals.count,"trees": store.trees.count,
                "updatedAt": Date().ISO8601Format()]
            try JSONSerialization.data(withJSONObject: receipt,options: [.prettyPrinted,.sortedKeys])
                .write(to: URL.documentsDirectory.appending(path: "GardenTestProfileReceipt.json"),options: .atomic)
        } catch { print("Garden test profile could not be applied: \(error)") }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--garden-preview") && gardenPreviewVisible {
                GardenPreviewHost { gardenPreviewVisible = false }
            } else if ProcessInfo.processInfo.arguments.contains("--guide-face-review") {
                GuideFaceReviewView()
            } else {
                appContent
            }
            #else
            appContent
            #endif
        }
    }

    private var appContent: some View {
            ContentView()
                .environment(manager)
                .environment(\.locale, AppLocalization.locale(forRawValue: appLanguageOverride))
                .task {
                    await StoreKitManager.shared.updateCustomerProductStatus()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    manager.refreshMountainTimer()
                    Task {
                        await StoreKitManager.shared.updateCustomerProductStatus()
                    }
                }
                .onOpenURL { url in
                    handleIncomingShare(url)
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

#if DEBUG
private struct GardenPreviewHost: View {
    let onClose: () -> Void
    @State private var store: StillnessGardenStore = {
        let args = ProcessInfo.processInfo.arguments
        let count = args.firstIndex(of: "--garden-count").flatMap { args.indices.contains($0+1) ? Int(args[$0+1]) : nil } ?? 100
        return .preview(count: count)
    }()
    var body: some View {
        StillnessGardenView(store: store,onClose: onClose)
            .task {
                if ProcessInfo.processInfo.arguments.contains("--garden-atlas") {
                    await GardenVisualReview.export()
                }
            }
    }
}
#endif
