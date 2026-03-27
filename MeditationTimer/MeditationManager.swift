import Foundation
import SwiftUI
import UIKit
import UserNotifications

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

    // MARK: - Settings (persisted)

    var durationMinutes: Int {
        get {
            access(keyPath: \.durationMinutes)
            return UserDefaults.standard.integer(forKey: "durationMinutes").clamped(to: 0...180)
        }
        set {
            withMutation(keyPath: \.durationMinutes) {
                UserDefaults.standard.set(newValue, forKey: "durationMinutes")
            }
        }
    }

    var startSound: SoundEngine.Sound {
        get {
            access(keyPath: \.startSound)
            let raw = UserDefaults.standard.string(forKey: "startSound") ?? SoundEngine.Sound.singingBowl.rawValue
            return SoundEngine.Sound(rawValue: raw) ?? .singingBowl
        }
        set {
            withMutation(keyPath: \.startSound) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "startSound")
            }
        }
    }

    var endSound: SoundEngine.Sound {
        get {
            access(keyPath: \.endSound)
            let raw = UserDefaults.standard.string(forKey: "endSound") ?? SoundEngine.Sound.gentleChime.rawValue
            return SoundEngine.Sound(rawValue: raw) ?? .gentleChime
        }
        set {
            withMutation(keyPath: \.endSound) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "endSound")
            }
        }
    }

    var ambientRainEnabled: Bool {
        get {
            access(keyPath: \.ambientRainEnabled)
            return UserDefaults.standard.bool(forKey: "ambientRainEnabled")
        }
        set {
            withMutation(keyPath: \.ambientRainEnabled) {
                UserDefaults.standard.set(newValue, forKey: "ambientRainEnabled")
            }
        }
    }

    var hapticEnabled: Bool {
        get {
            access(keyPath: \.hapticEnabled)
            if UserDefaults.standard.object(forKey: "hapticEnabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "hapticEnabled")
        }
        set {
            withMutation(keyPath: \.hapticEnabled) {
                UserDefaults.standard.set(newValue, forKey: "hapticEnabled")
            }
        }
    }

    var breathingCueMode: BreathingCueMode {
        get {
            access(keyPath: \.breathingCueMode)
            let raw = UserDefaults.standard.string(forKey: "breathingCueMode") ?? BreathingCueMode.off.rawValue
            return BreathingCueMode(rawValue: raw) ?? .off
        }
        set {
            withMutation(keyPath: \.breathingCueMode) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "breathingCueMode")
            }
        }
    }

    var dailyReminderEnabled: Bool {
        get {
            access(keyPath: \.dailyReminderEnabled)
            return UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        }
        set {
            withMutation(keyPath: \.dailyReminderEnabled) {
                UserDefaults.standard.set(newValue, forKey: "dailyReminderEnabled")
            }
        }
    }

    var dailyReminderTime: Date {
        get {
            access(keyPath: \.dailyReminderTime)
            let raw = UserDefaults.standard.double(forKey: "dailyReminderTime")
            if raw == 0 {
                // Default to 8:00 AM
                var components = DateComponents()
                components.hour = 8
                components.minute = 0
                return Calendar.current.date(from: components) ?? Date()
            }
            return Date(timeIntervalSince1970: raw)
        }
        set {
            withMutation(keyPath: \.dailyReminderTime) {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "dailyReminderTime")
            }
        }
    }

    var hasSeenOnboarding: Bool {
        get {
            access(keyPath: \.hasSeenOnboarding)
            return UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        }
        set {
            withMutation(keyPath: \.hasSeenOnboarding) {
                UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding")
            }
        }
    }

    func updateDailyReminder() {
        if dailyReminderEnabled {
            NotificationManager.shared.scheduleDailyReminder(at: dailyReminderTime)
        } else {
            NotificationManager.shared.cancelAllReminders()
        }
    }

    func playBreathingCue(phase: String, duration: Double) {
        let hasSoundAccess = StoreKitManager.shared.isPurchased(StoreKitManager.techniqueLibraryID)

        switch breathingCueMode {
        case .off:
            break
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

    // MARK: - History (persisted)

    var meditationHistory: [String: Int] {
        get {
            access(keyPath: \.meditationHistory)
            return (UserDefaults.standard.dictionary(forKey: "meditationHistory") as? [String: Int]) ?? [:]
        }
        set {
            withMutation(keyPath: \.meditationHistory) {
                UserDefaults.standard.set(newValue, forKey: "meditationHistory")
            }
        }
    }

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

    /// Returns (dayLabel, seconds) for the last 7 days, Mon–Sun aligned to current week
    var weeklyData: [(label: String, seconds: Int)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        let today = calendar.startOfDay(for: Date())
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday == 1) ? -6 : -(weekday - 2)
        guard let monday = calendar.date(byAdding: .day, value: mondayOffset, to: today) else { return [] }

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            let key = formatter.string(from: date)
            return (label: dayLabels[offset], seconds: meditationHistory[key] ?? 0)
        }
    }

    // MARK: - Techniques (persisted)

    var selectedTechnique: BreathingTechnique {
        get {
            access(keyPath: \.selectedTechnique)
            if let data = UserDefaults.standard.data(forKey: "selectedTechnique"),
               let technique = try? JSONDecoder().decode(BreathingTechnique.self, from: data) {
                return technique
            }
            return .defaultTechnique
        }
        set {
            withMutation(keyPath: \.selectedTechnique) {
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: "selectedTechnique")
                }
            }
        }
    }

    var userCustomTechniques: [BreathingTechnique] {
        get {
            access(keyPath: \.userCustomTechniques)
            guard let data = UserDefaults.standard.data(forKey: "userCustomTechniques") else { return [] }
            let decoded: [BreathingTechnique]? = try? JSONDecoder().decode([BreathingTechnique].self, from: data)
            return decoded ?? []
        }
        set {
            withMutation(keyPath: \.userCustomTechniques) {
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: "userCustomTechniques")
                }
            }
        }
    }

    func addCustomTechnique(_ technique: BreathingTechnique) {
        var techniques = userCustomTechniques
        techniques.append(technique)
        userCustomTechniques = techniques
    }

    func removeCustomTechnique(_ id: String) {
        userCustomTechniques = userCustomTechniques.filter { $0.id != id }
        if selectedTechnique.id == id {
            selectedTechnique = .defaultTechnique
        }
    }

    // MARK: - Durations

    static let builtInDurations = [1, 3, 5, 10, 15, 20, 30]

    var customDurations: [Int] {
        get {
            access(keyPath: \.customDurations)
            return (UserDefaults.standard.array(forKey: "customDurations") as? [Int]) ?? []
        }
        set {
            withMutation(keyPath: \.customDurations) {
                UserDefaults.standard.set(newValue, forKey: "customDurations")
            }
        }
    }

    /// All durations (built-in + custom), sorted and deduplicated.
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
        // If the deleted duration was the selected one, fall back to 10
        if durationMinutes == minutes {
            durationMinutes = 10
        }
    }

    func isCustomDuration(_ minutes: Int) -> Bool {
        customDurations.contains(minutes)
    }

    // MARK: - Private

    private let soundEngine = SoundEngine()
    private var timer: Timer?

    init() {
        // Set default duration if not set
        if UserDefaults.standard.integer(forKey: "durationMinutes") == 0 {
            UserDefaults.standard.set(10, forKey: "durationMinutes")
        }
    }

    // MARK: - Public API

    /// Start meditation with the configured duration.
    func start() {
        start(durationMinutes: durationMinutes)
    }

    /// Start meditation with a specific duration in minutes.
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

        // Play start sound
        soundEngine.playSound(startSound)

        // Start ambient rain after a brief delay
        if ambientRainEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard self?.state == .meditating else { return }
                self?.soundEngine.startAmbientRain()
            }
        }

        // Haptic
        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // Timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Stop meditation early.
    func stop() {
        guard state == .meditating else { return }
        finish()
    }

    /// Dismiss the completion state and return to idle.
    func reset() {
        state = .idle
        remainingSeconds = 0
        elapsedSeconds = 0
        soundEngine.stopAll()
    }

    // MARK: - Formatted Time

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

    // MARK: - Private

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
        
        if !isOpenEnded {
            remainingSeconds = 0
        }

        // Stop ambient, play end sound
        soundEngine.stopAll()
        soundEngine.playSound(endSound)

        // Haptic
        if hapticEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - Helpers

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

// MARK: - Notification Manager

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorization()
    }
    
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
        // Cancel existing
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
