import Foundation
import SwiftUI
import AVFoundation
import UIKit
import UserNotifications
import Observation
import HealthKit
import ActivityKit

enum HomeViewMode: String, Codable {
    case hero
    case timer
}

/// Central state manager for the meditation timer.
@MainActor
@Observable
final class MeditationManager {
    /// Shared instance for Siri intents to access.
    @MainActor
    static let shared = MeditationManager()

    // MARK: - Timer State

    enum TimerState {
        case idle
        case meditating
        case complete
    }

    enum BreathingCueMode: String, CaseIterable {
        case off = "Off"
        case haptic = "Haptic"
        case sound = "Sound"
        case both = "Both"
    }

    private(set) var state: TimerState = .idle
    private(set) var remainingSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var elapsedSeconds: Int = 0

    var isOpenEnded: Bool {
        durationMinutes == 0
    }

    // MARK: - Settings (Stored & Persisted)

    var durationMinutes: Int {
        didSet { UserDefaults.standard.set(durationMinutes, forKey: "durationMinutes") }
    }

    var startSound: SoundEngine.Sound {
        didSet { UserDefaults.standard.set(startSound.rawValue, forKey: "startSound") }
    }

    var endSound: SoundEngine.Sound {
        didSet { UserDefaults.standard.set(endSound.rawValue, forKey: "endSound") }
    }

    var ambientSound: SoundEngine.AmbientSound {
        didSet {
            UserDefaults.standard.set(ambientSound.rawValue, forKey: "ambientSound")
            if state == .meditating {
                soundEngine.startAmbientSound(ambientSound)
            }
        }
    }
    
    var ambientVolume: Float {
        didSet {
            UserDefaults.standard.set(ambientVolume, forKey: "ambientVolume")
            soundEngine.ambientVolume = ambientVolume
        }
    }
    
    var toneVolume: Float {
        didSet {
            UserDefaults.standard.set(toneVolume, forKey: "toneVolume")
            soundEngine.toneVolume = toneVolume
        }
    }

    var hapticEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticEnabled, forKey: "hapticEnabled") }
    }

    var breathingCueMode: BreathingCueMode {
        didSet { UserDefaults.standard.set(breathingCueMode.rawValue, forKey: "breathingCueMode") }
    }

    var dailyReminderEnabled: Bool {
        didSet { 
            UserDefaults.standard.set(dailyReminderEnabled, forKey: "dailyReminderEnabled")
            updateDailyReminder()
        }
    }

    var dailyReminderTime: Date {
        didSet { 
            UserDefaults.standard.set(dailyReminderTime.timeIntervalSince1970, forKey: "dailyReminderTime")
            updateDailyReminder()
        }
    }

    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding") }
    }

    var isGuruEnabled: Bool {
        didSet { UserDefaults.standard.set(isGuruEnabled, forKey: "isGuruEnabled") }
    }

    var preferredStillnessRatio: Double {
        didSet { UserDefaults.standard.set(preferredStillnessRatio, forKey: "preferredStillnessRatio") }
    }

    var kaiVoiceIdentifier: String {
        didSet { UserDefaults.standard.set(kaiVoiceIdentifier, forKey: "kaiVoiceIdentifier") }
    }

    var selectedKaiPersonalityID: String {
        didSet { UserDefaults.standard.set(selectedKaiPersonalityID, forKey: "selectedKaiPersonalityID") }
    }

    var meditationHistory: [String: Int] {
        didSet { UserDefaults.standard.set(meditationHistory, forKey: "meditationHistory") }
    }

    var recentSessionMemories: [SessionMemory] {
        didSet {
            if let data = try? JSONEncoder().encode(recentSessionMemories) {
                UserDefaults.standard.set(data, forKey: "recentSessionMemories")
            }
        }
    }

    var lastCompletedSessionID: UUID?

    var selectedTechnique: BreathingTechnique {
        didSet {
            if let data = try? JSONEncoder().encode(selectedTechnique) {
                UserDefaults.standard.set(data, forKey: "selectedTechnique")
            }
        }
    }

    /// The current sentence being spoken by Kai (for in-app display)
    private(set) var currentKaiPhrase: String = ""

    var userCustomTechniques: [BreathingTechnique] {
        didSet {
            if let data = try? JSONEncoder().encode(userCustomTechniques) {
                UserDefaults.standard.set(data, forKey: "userCustomTechniques")
            }
        }
    }

    var customDurations: [Int] {
        didSet { UserDefaults.standard.set(customDurations, forKey: "customDurations") }
    }

    var savedMeditations: [MeditationScript] {
        didSet {
            if let data = try? JSONEncoder().encode(savedMeditations) {
                UserDefaults.standard.set(data, forKey: "savedMeditations")
            }
        }
    }

    /// For deep linking: tells views to dismiss themselves to show the meditation.
    var shouldDismissSheets: Bool = false
    
    /// The script currently being played (or just finished). 
    var currentScript: MeditationScript?

    /// Siri Handoff State
    var isSiriTriggeredKai: Bool = false
    
    /// Tracks if the current session was loaded via a share link.
    /// Shared sessions skip memory logging and the reflection prompt.
    private(set) var isSharedSession: Bool = false
    
    var siriPendingMood: String?
    var siriPendingDuration: Int?

    var pendingKaiMoodSummary: String?
    var pendingKaiIntention: String?

    var isCurrentScriptSaved: Bool {
        guard let current = currentScript else { return false }
        return savedMeditations.contains(where: { $0.id == current.id })
    }

    var selectedKaiPersonality: KaiPersonality {
        KaiPersonality.personality(for: selectedKaiPersonalityID)
    }

    func saveCurrentScript() {
        guard let current = currentScript, !isCurrentScriptSaved else { return }
        savedMeditations.append(current)
    }

    func removeSavedMeditation(_ id: UUID) {
        savedMeditations.removeAll(where: { $0.id == id })
    }

    func toggleFavoriteSavedMeditation(_ id: UUID) {
        guard let index = savedMeditations.firstIndex(where: { $0.id == id }) else { return }
        savedMeditations[index].isFavorite.toggle()
    }

    func addTag(_ tag: String, toSavedMeditation id: UUID) {
        let normalized = normalizedTag(tag)
        guard !normalized.isEmpty,
              let index = savedMeditations.firstIndex(where: { $0.id == id }) else { return }

        let existingTags = savedMeditations[index].tags.map { $0.lowercased() }
        guard !existingTags.contains(normalized.lowercased()) else { return }
        savedMeditations[index].tags.append(normalized)
        savedMeditations[index].tags.sort()
    }

    func renameSavedMeditation(_ id: UUID, to newTitle: String) {
        let normalized = normalizedTitle(newTitle)
        guard !normalized.isEmpty,
              let index = savedMeditations.firstIndex(where: { $0.id == id }) else { return }
        savedMeditations[index].title = normalized
    }

    func removeTag(_ tag: String, fromSavedMeditation id: UUID) {
        guard let index = savedMeditations.firstIndex(where: { $0.id == id }) else { return }
        savedMeditations[index].tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    private func normalizedTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func normalizedTag(_ rawTag: String) -> String {
        let trimmed = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(collapsed.prefix(18))
    }

    // MARK: - Computed Properties

    var totalSecondsMeditated: Int {
        meditationHistory.values.reduce(0, +)
    }

    var todaySecondsMeditated: Int {
        meditationHistory[todayKey] ?? 0
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func secondsMeditated(on date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return meditationHistory[key] ?? 0
    }

    private func logMeditationSession(seconds: Int) {
        guard seconds > 0 else { return }
        var history = meditationHistory
        let today = todayKey
        history[today] = (history[today] ?? 0) + seconds
        meditationHistory = history
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let key = formatter.string(from: checkDate)
            if (meditationHistory[key] ?? 0) > 0 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    var averageSessionSeconds: Int {
        let activeDays = meditationHistory.values.filter { $0 > 0 }.count
        guard activeDays > 0 else { return 0 }
        return totalSecondsMeditated / activeDays
    }

    var bestSessionSeconds: Int {
        meditationHistory.values.max() ?? 0
    }

    var bestStreakDays: Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let sortedDates = meditationHistory
            .filter { $0.value > 0 }
            .keys
            .compactMap { formatter.date(from: $0) }
            .sorted()

        guard !sortedDates.isEmpty else { return 0 }

        var best = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    var weeklyData: [(label: String, seconds: Int)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday == 1) ? -6 : -(weekday - 2)
        guard let monday = calendar.date(byAdding: .day, value: mondayOffset, to: today) else { return [] }

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            let key = formatter.string(from: date)
            return (label: dayLabels[offset], seconds: meditationHistory[key] ?? 0)
        }
    }

    // MARK: - Techniques

    func addCustomTechnique(_ technique: BreathingTechnique) {
        userCustomTechniques.append(technique)
    }

    func removeCustomTechnique(_ id: String) {
        userCustomTechniques = userCustomTechniques.filter { $0.id != id }
        if selectedTechnique.id == id {
            selectedTechnique = .defaultTechnique
        }
    }

    // MARK: - Durations

    private var currentActivity: Activity<LiveTimerAttributes>?

    static let builtInDurations = [1, 3, 5, 10, 15, 20, 30]

    var allDurations: [Int] {
        let merged = Set(Self.builtInDurations).union(customDurations)
        return merged.sorted()
    }

    func addCustomDuration(_ minutes: Int) {
        let clamped = minutes.clamped(to: 1...180)
        guard !Self.builtInDurations.contains(clamped),
              !customDurations.contains(clamped) else { return }
        customDurations = (customDurations + [clamped]).sorted()
    }

    func removeCustomDuration(_ minutes: Int) {
        customDurations = customDurations.filter { $0 != minutes }
        if durationMinutes == minutes {
            durationMinutes = 10
        }
    }

    func isCustomDuration(_ minutes: Int) -> Bool {
        customDurations.contains(minutes)
    }

    // MARK: - Private state
    let soundEngine = SoundEngine()
    private var timer: Timer?

    init() {
        // Load duration
        let duration = UserDefaults.standard.integer(forKey: "durationMinutes")
        self.durationMinutes = (duration == 0) ? 10 : duration.clamped(to: 0...180)
        
        // Load sounds
        let sSound = UserDefaults.standard.string(forKey: "startSound") ?? SoundEngine.Sound.singingBowl.rawValue
        self.startSound = SoundEngine.Sound(rawValue: sSound) ?? .singingBowl
        
        let eSound = UserDefaults.standard.string(forKey: "endSound") ?? SoundEngine.Sound.gentleChime.rawValue
        self.endSound = SoundEngine.Sound(rawValue: eSound) ?? .gentleChime
        
        // Load other settings
        let aSound = UserDefaults.standard.string(forKey: "ambientSound") ?? SoundEngine.AmbientSound.none.rawValue
        self.ambientSound = SoundEngine.AmbientSound(rawValue: aSound) ?? .none
        
        if UserDefaults.standard.object(forKey: "ambientVolume") == nil {
            self.ambientVolume = 0.5
        } else {
            self.ambientVolume = UserDefaults.standard.float(forKey: "ambientVolume")
        }
        
        if UserDefaults.standard.object(forKey: "toneVolume") == nil {
            self.toneVolume = 0.5
        } else {
            self.toneVolume = UserDefaults.standard.float(forKey: "toneVolume")
        }
        
        if UserDefaults.standard.object(forKey: "hapticEnabled") == nil {
            self.hapticEnabled = true
        } else {
            self.hapticEnabled = UserDefaults.standard.bool(forKey: "hapticEnabled")
        }
        
        let bcMode = UserDefaults.standard.string(forKey: "breathingCueMode") ?? BreathingCueMode.off.rawValue
        self.breathingCueMode = BreathingCueMode(rawValue: bcMode) ?? .off
        
        self.dailyReminderEnabled = UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        
        let drTime = UserDefaults.standard.double(forKey: "dailyReminderTime")
        if drTime == 0 {
            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            self.dailyReminderTime = Calendar.current.date(from: components) ?? Date()
        } else {
            self.dailyReminderTime = Date(timeIntervalSince1970: drTime)
        }
        
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        self.isGuruEnabled = UserDefaults.standard.object(forKey: "isGuruEnabled") as? Bool ?? true
        self.preferredStillnessRatio = UserDefaults.standard.double(forKey: "preferredStillnessRatio") == 0 ? 0.5 : UserDefaults.standard.double(forKey: "preferredStillnessRatio")
        self.kaiVoiceIdentifier = UserDefaults.standard.string(forKey: "kaiVoiceIdentifier") ?? "com.apple.voice.compact.en-US.Samantha"
        self.selectedKaiPersonalityID = UserDefaults.standard.string(forKey: "selectedKaiPersonalityID") ?? KaiPersonality.default.id
        
        self.meditationHistory = (UserDefaults.standard.dictionary(forKey: "meditationHistory") as? [String: Int]) ?? [:]

        if let data = UserDefaults.standard.data(forKey: "recentSessionMemories"),
           let decoded = try? JSONDecoder().decode([SessionMemory].self, from: data) {
            self.recentSessionMemories = decoded
        } else {
            self.recentSessionMemories = []
        }
        
        // Load techniques
        if let data = UserDefaults.standard.data(forKey: "selectedTechnique"),
           let technique = try? JSONDecoder().decode(BreathingTechnique.self, from: data) {
            self.selectedTechnique = technique
        } else {
            self.selectedTechnique = .defaultTechnique
        }
        
        if let data = UserDefaults.standard.data(forKey: "userCustomTechniques"),
           let decoded = try? JSONDecoder().decode([BreathingTechnique].self, from: data) {
            self.userCustomTechniques = decoded
        } else {
            self.userCustomTechniques = []
        }
        
        self.customDurations = (UserDefaults.standard.array(forKey: "customDurations") as? [Int]) ?? []
        
        if let data = UserDefaults.standard.data(forKey: "savedMeditations"),
           let decoded = try? JSONDecoder().decode([MeditationScript].self, from: data) {
            self.savedMeditations = decoded
        } else {
            self.savedMeditations = []
        }
        
        // One-time auto-select voice if empty
        if self.kaiVoiceIdentifier.isEmpty {
            self.kaiVoiceIdentifier = GuruManager.shared.findBestAvailableVoice()?.identifier ?? ""
        }
        
        // Pass volume directly to engine setup
        soundEngine.ambientVolume = self.ambientVolume
        soundEngine.toneVolume = self.toneVolume
    }

    // MARK: - Public API

    func updateDailyReminder() {
        if dailyReminderEnabled {
            NotificationManager.shared.scheduleDailyReminder(at: dailyReminderTime)
        } else {
            NotificationManager.shared.cancelAllReminders()
        }
    }

    func start() {
        start(durationMinutes: durationMinutes)
    }

    func start(durationMinutes minutes: Int, isShared: Bool = false) {
        guard state != .meditating else { return }
        self.isSharedSession = isShared
        self.durationMinutes = minutes
        if minutes == 0 {
            totalSeconds = 0
            remainingSeconds = 0
            elapsedSeconds = 0
        } else {
            let mins = max(1, minutes)
            totalSeconds = mins * 60
            remainingSeconds = totalSeconds
            elapsedSeconds = 0
        }
        state = .meditating
        sessionStartDate = Date()
        lastSessionStartDate = sessionStartDate
        activeSessionMoodSummary = normalizedMemoryText(pendingKaiMoodSummary)
        activeSessionIntention = normalizedMemoryText(pendingKaiIntention)
        pendingKaiMoodSummary = nil
        pendingKaiIntention = nil
        soundEngine.playSound(startSound)
        if ambientSound != .none {
            soundEngine.startAmbientSound(ambientSound)
        }
        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        if let script = currentScript {
            // Start Live Activity before speech begins so updates find an active activity
            startLiveActivity(initialPhrase: script.steps.first?.text ?? "Focusing inward...")
            if isGuruEnabled {
                GuruManager.shared.play(script: script)
            }
        } else {
            startLiveActivity(initialPhrase: "Focusing inward...")
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    /// Explicitly starts a session from a shared script, ensuring exact settings match.
    func startSharedSession(script: MeditationScript) {
        // Reset state if needed
        if state == .meditating {
            stop()
        }
        
        // Match the shared session exactly
        self.currentScript = script
        self.isGuruEnabled = true
        self.durationMinutes = script.durationMinutes
        self.isSharedSession = true // Mark as shared
        
        // Sync the persona for the UI (image/name)
        if let sharedID = script.kaiPersonalityID {
            self.selectedKaiPersonalityID = sharedID
        }
        
        print("🚀 KAI: Replicating shared session: '\(script.title)' with \(script.durationMinutes)m length.")
        
        // Start using the matched duration and explicit shared flag
        start(durationMinutes: script.durationMinutes, isShared: true)
    }
    
    // MARK: - Live Activities
    
    private var activeActivityEndTime: Date?
    private var activeKaiPersonaImageName: String?
    private var activeKaiPersonaName: String?

    private func startLiveActivity(initialPhrase: String = "Focusing inward...") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let title = currentScript?.title ?? "Meditation Journey"
        let personality = currentScript?.generatedPersonality
            ?? {
                guard currentScript != nil, isGuruEnabled else { return nil }
                return selectedKaiPersonality
            }()
        let attributes = LiveTimerAttributes(
            title: title,
            personaImageName: personality?.imageName,
            personaName: personality?.name
        )
        
        let endSeconds = isOpenEnded ? 0 : totalSeconds
        let endDate = Date().addingTimeInterval(TimeInterval(endSeconds))
        self.activeActivityEndTime = endDate
        self.currentKaiPhrase = initialPhrase
        self.activeKaiPersonaImageName = personality?.imageName
        self.activeKaiPersonaName = personality?.name
        let liveActivityPhrase = shortenedLiveActivityPhrase(from: initialPhrase)
        
        let contentState = LiveTimerAttributes.ContentState(
            currentPhrase: liveActivityPhrase,
            estimatedEndTime: endDate,
            personaImageName: personality?.imageName,
            personaName: personality?.name
        )
        
        do {
            // Clean up any existing stale activities of this type first
            for activity in Activity<LiveTimerAttributes>.activities {
                Task { await activity.end(dismissalPolicy: .immediate) }
            }
            
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil)
                currentActivity = try Activity.request(attributes: attributes, content: content)
            } else {
                currentActivity = try Activity.request(attributes: attributes, contentState: contentState, pushType: nil)
            }
            print("🚀 Started Live Activity: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    func updateLiveActivity(phrase: String) {
        // Stabilize end time: use the one we calculated at the start
        let endDate = activeActivityEndTime ?? Date()
        self.currentKaiPhrase = phrase
        let liveActivityPhrase = shortenedLiveActivityPhrase(from: phrase)
        
        let contentState = LiveTimerAttributes.ContentState(
            currentPhrase: liveActivityPhrase,
            estimatedEndTime: endDate,
            personaImageName: activeKaiPersonaImageName,
            personaName: activeKaiPersonaName
        )
        
        // Re-attachment Logic: If currentActivity is nil or lost, find it in the global list
        if currentActivity == nil {
            currentActivity = Activity<LiveTimerAttributes>.activities.first
        }
        
        guard let activity = currentActivity else { 
            print("⚠️ No Live Activity found to update.")
            return 
        }
        
        Task.detached(priority: .userInitiated) {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: contentState)
            }
            print("📝 Updated Live Activity with phrase: \(phrase.prefix(20))...")
        }
    }
    
    private func endLiveActivity() {
        activeActivityEndTime = nil
        currentKaiPhrase = ""
        activeKaiPersonaImageName = nil
        activeKaiPersonaName = nil
        
        // End ALL active activities of this type to be safe
        for activity in Activity<LiveTimerAttributes>.activities {
            let finalState = LiveTimerAttributes.ContentState(
                currentPhrase: "",
                estimatedEndTime: Date(),
                personaImageName: nil,
                personaName: nil
            )
            
            Task {
                if #available(iOS 16.2, *) {
                    await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: finalState, dismissalPolicy: .immediate)
                }
            }
        }
        currentActivity = nil
    }

    private func shortenedLiveActivityPhrase(from phrase: String) -> String {
        let trimmed = phrase
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 72 { return trimmed }

        let prefix = trimmed.prefix(69).trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix + "..."
    }

    func stop() {
        guard state == .meditating else { return }
        finish()
    }

    func reset() {
        state = .idle
        remainingSeconds = 0
        elapsedSeconds = 0
        sessionStartDate = nil
        isSharedSession = false // Ensure we return to personal mode
        currentScript = nil // Clear the shared script content
        endLiveActivity()
        soundEngine.stopAll()
        GuruManager.shared.stop()
    }

    var formattedTime: String {
        if isOpenEnded {
            let mins = elapsedSeconds / 60
            let secs = elapsedSeconds % 60
            return String(format: "%02d:%02d", mins, secs)
        } else {
            let mins = remainingSeconds / 60
            let secs = remainingSeconds % 60
            return String(format: "%02d:%02d", mins, secs)
        }
    }

    var progress: Double {
        if isOpenEnded { return 0.0 }
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    func playBreathingCue(phase: String, duration: Double) {
        let hasSoundAccess = StoreKitManager.shared.isPurchased(StoreKitManager.techniqueLibraryID)
        switch breathingCueMode {
        case .off: break
        case .haptic:
            if phase == "Inhale" || phase == "Exhale" {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        case .sound:
            guard hasSoundAccess else { return }
            if phase == "Inhale" {
                soundEngine.playInhaleBreath(duration: duration)
            } else if phase == "Exhale" {
                soundEngine.playExhaleBreath(duration: duration)
            }
        case .both:
            if phase == "Inhale" || phase == "Exhale" {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            if hasSoundAccess {
                if phase == "Inhale" {
                    soundEngine.playInhaleBreath(duration: duration)
                } else if phase == "Exhale" {
                    soundEngine.playExhaleBreath(duration: duration)
                }
            }
        }
    }

    private var sessionStartDate: Date?
    private var lastSessionStartDate: Date?
    private var activeSessionMoodSummary: String?
    private var activeSessionIntention: String?
    
    private func tick() {
        guard state == .meditating else {
            timer?.invalidate()
            return
        }
        if isOpenEnded {
            elapsedSeconds += 1
        } else {
            remainingSeconds -= 1
            if remainingSeconds <= 0 {
                finish()
            }
        }
    }

    private func finish() {
        let sessionSeconds = isOpenEnded ? elapsedSeconds : (totalSeconds - remainingSeconds)
        if let startDate = sessionStartDate,
           sessionSeconds > 0,
           !isSharedSession, // Skip memory logging for shared sessions
           (currentScript != nil || activeSessionMoodSummary != nil || activeSessionIntention != nil) {
            let memory = SessionMemory(
                startedAt: startDate,
                durationSeconds: sessionSeconds,
                moodSummary: activeSessionMoodSummary,
                intention: activeSessionIntention,
                proactiveHeader: currentScript?.guidanceHeader,
                proactiveBody: currentScript?.guidanceBody,
                suggestionOptions: currentScript?.suggestionOptions ?? []
            )
            recentSessionMemories = Array(([memory] + recentSessionMemories).prefix(3))
            lastCompletedSessionID = memory.id
        } else {
            lastCompletedSessionID = nil
        }
        logMeditationSession(seconds: sessionSeconds)
        timer?.invalidate()
        timer = nil
        state = .complete
        if !isOpenEnded { remainingSeconds = 0 }
        soundEngine.stopAll()
        soundEngine.playSound(endSound)
        GuruManager.shared.stop()
        endLiveActivity()
        if hapticEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        
        // Finalize HealthKit session record
        if let startDate = sessionStartDate, sessionSeconds > 0 {
            let endDate = Date()
            HealthManager.shared.saveMindfulMinute(startDate: startDate, endDate: endDate)
        }
        activeSessionMoodSummary = nil
        activeSessionIntention = nil
        sessionStartDate = nil
    }
}

extension MeditationManager {
    var latestSessionMemory: SessionMemory? {
        recentSessionMemories.first
    }

    var lastSessionStartTime: Date? {
        lastSessionStartDate
    }

    func attachReflection(_ reflection: String, to sessionID: UUID) {
        let trimmed = normalizedMemoryText(reflection)
        guard let trimmed, !trimmed.isEmpty else { return }
        guard let index = recentSessionMemories.firstIndex(where: { $0.id == sessionID }) else { return }
        var memories = recentSessionMemories
        var updated = memories[index]
        updated.reflection = trimmed
        updated.reflectionDate = Date()
        memories[index] = updated
        recentSessionMemories = memories
    }

    func defaultNextSessionReminderTime() -> Date {
        guard let lastSessionStartDate else { return Date() }
        let components = Calendar.current.dateComponents([.hour, .minute], from: lastSessionStartDate)
        return Calendar.current.date(from: components) ?? lastSessionStartDate
    }

    private func normalizedMemoryText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var isAuthorized = false
    private init() { checkAuthorization() }
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    func scheduleDailyReminder(at date: Date) {
        cancelAllReminders()
        let content = UNMutableNotificationContent()
        content.title = "Time for your breath"
        content.body = "Take a few minutes for yourself with Stilla."
        content.sound = .default
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    func scheduleNextSessionReminder(
        at date: Date,
        suggestionText: String? = nil,
        personaName: String? = nil
    ) {
        cancelNextSessionReminder()
        let content = UNMutableNotificationContent()
        let trimmedPersona = personaName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        content.title = trimmedPersona.isEmpty ? "See you soon" : "Kai • \(trimmedPersona)"
        let trimmedSuggestion = suggestionText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        content.body = trimmedSuggestion.isEmpty
            ? "Ready for another moment of calm?"
            : "Ready to \(trimmedSuggestion)?"
        content.sound = .default
        content.userInfo = ["open_kai": true]
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "next_session_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling next session reminder: \(error)")
            }
        }
    }

    func cancelNextSessionReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["next_session_reminder"])
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }
}

// MARK: - HealthKit Integration

@MainActor
class HealthManager {
    static let shared = HealthManager()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return false }
        
        do {
            try await healthStore.requestAuthorization(toShare: [mindfulType], read: [mindfulType])
            return true
        } catch {
            print("❌ HealthKit Authorization Failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func saveMindfulMinute(startDate: Date, endDate: Date) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        Task {
            let authorized = await requestAuthorization()
            guard authorized else { return }
            
            guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
            
            let mindfulSample = HKCategorySample(
                type: mindfulType,
                value: HKCategoryValue.notApplicable.rawValue,
                start: startDate,
                end: endDate
            )
            
            do {
                try await healthStore.save(mindfulSample)
                print("✅ Mindful minutes successfully saved to Apple Health (\(startDate) - \(endDate)).")
            } catch {
                print("❌ Failed to save mindful minutes: \(error.localizedDescription)")
            }
        }
    }
}
