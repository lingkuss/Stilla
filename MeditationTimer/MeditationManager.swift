import Foundation
import SwiftUI
import UIKit

/// Central state manager for the meditation timer.
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
