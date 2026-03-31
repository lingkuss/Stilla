import Foundation
import SwiftUI
import AVFoundation
import UIKit
import UserNotifications
import Observation

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

    var ambientRainEnabled: Bool {
        didSet { UserDefaults.standard.set(ambientRainEnabled, forKey: "ambientRainEnabled") }
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

    var kaiVoiceIdentifier: String {
        didSet { UserDefaults.standard.set(kaiVoiceIdentifier, forKey: "kaiVoiceIdentifier") }
    }

    var meditationHistory: [String: Int] {
        didSet { UserDefaults.standard.set(meditationHistory, forKey: "meditationHistory") }
    }

    var selectedTechnique: BreathingTechnique {
        didSet {
            if let data = try? JSONEncoder().encode(selectedTechnique) {
                UserDefaults.standard.set(data, forKey: "selectedTechnique")
            }
        }
    }

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

    /// The script currently being played (or just finished). 
    /// Used for the "Save" feature at the end of a session.
    var currentScript: MeditationScript?

    var isCurrentScriptSaved: Bool {
        guard let current = currentScript else { return false }
        return savedMeditations.contains(where: { $0.id == current.id })
    }

    func saveCurrentScript() {
        guard let current = currentScript, !isCurrentScriptSaved else { return }
        savedMeditations.append(current)
    }

    func removeSavedMeditation(_ id: UUID) {
        savedMeditations.removeAll(where: { $0.id == id })
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
    private let soundEngine = SoundEngine()
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
        self.ambientRainEnabled = UserDefaults.standard.bool(forKey: "ambientRainEnabled")
        
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
        self.isGuruEnabled = UserDefaults.standard.bool(forKey: "isGuruEnabled")
        
        self.kaiVoiceIdentifier = UserDefaults.standard.string(forKey: "kaiVoiceIdentifier") ?? ""
        
        self.meditationHistory = (UserDefaults.standard.dictionary(forKey: "meditationHistory") as? [String: Int]) ?? [:]
        
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

    func start(durationMinutes minutes: Int) {
        guard state != .meditating else { return }
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
        soundEngine.playSound(startSound)
        if ambientRainEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard self?.state == .meditating else { return }
                self?.soundEngine.startAmbientRain()
            }
        }
        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if isGuruEnabled {
            let script = currentScript ?? MeditationScript.sample(for: minutes)
            GuruManager.shared.play(script: script)
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        guard state == .meditating else { return }
        finish()
    }

    func reset() {
        state = .idle
        remainingSeconds = 0
        elapsedSeconds = 0
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
        logMeditationSession(seconds: sessionSeconds)
        timer?.invalidate()
        timer = nil
        state = .complete
        if !isOpenEnded { remainingSeconds = 0 }
        soundEngine.stopAll()
        soundEngine.playSound(endSound)
        GuruManager.shared.stop()
        if hapticEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
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
        content.body = "Take a few minutes for yourself with MeditationTimer."
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
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }
}
