import Foundation

struct ZenMouthPose: Equatable {
    var opening: Float = 0
    var rounding: Float = 0

    func blended(toward other: Self, amount: Float) -> Self {
        Self(opening: opening + (other.opening - opening) * amount,
             rounding: rounding + (other.rounding - rounding) * amount)
    }
}

/// Playback events, rather than a free-running talking animation. Apple's phoneme
/// markers take priority when a voice supplies them; word callbacks are the fallback.
struct ZenSpeechMotion: Equatable {
    private(set) var isSpeaking = false
    private(set) var word = ""
    private(set) var wordStartedAt: TimeInterval = 0
    private var phoneme = ""
    private var phonemeStartedAt: TimeInterval = -.infinity
    private var audioLevel: Float = 0
    private var audioSampleAt: TimeInterval = -.infinity

    mutating func begin() { isSpeaking = true }
    mutating func stop() { self = Self() }

    /// File playback has no Apple phoneme callbacks. Use the actual audio meter
    /// for approximate jaw movement, including silence inside each recording.
    mutating func speak(level: Float, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        isSpeaking = true
        audioLevel = level.isFinite ? min(1, max(0, level)) : 0
        audioSampleAt = time
    }

    mutating func speak(word: String, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        isSpeaking = true
        self.word = word.lowercased()
        wordStartedAt = time
    }

    mutating func speak(phoneme: String, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        isSpeaking = true
        self.phoneme = phoneme.lowercased()
        phonemeStartedAt = time
    }

    private var estimatedWordDuration: TimeInterval {
        min(0.95, max(0.16, Double(word.count) * 0.065))
    }

    func isVoicing(at time: TimeInterval) -> Bool {
        guard isSpeaking else { return false }
        if audioSampleAt.isFinite {
            return time >= audioSampleAt && time - audioSampleAt < 0.12 && audioLevel > 0.04
        }
        return time - phonemeStartedAt < 0.25
            || (!word.isEmpty && time - wordStartedAt < estimatedWordDuration + 0.28)
    }

    func mouthOpening(at time: TimeInterval) -> Float {
        mouthPose(at: time).opening
    }

    func mouthPose(at time: TimeInterval) -> ZenMouthPose {
        guard isSpeaking else { return .init() }
        if audioSampleAt.isFinite {
            guard isVoicing(at: time) else { return .init() }
            return .init(opening: audioLevel * 0.8)
        }
        let phonemeAge = time - phonemeStartedAt
        if phonemeStartedAt >= wordStartedAt, phonemeAge >= 0, phonemeAge < 0.22 {
            return Self.pose(for: phoneme)
        }
        let age = time - wordStartedAt
        guard !word.isEmpty, age >= 0, age < estimatedWordDuration else { return .init() }
        // Blend toward the next articulation instead of mechanically opening
        // and closing once per letter. Playback words keep the estimate in sync.
        let letters = Array(word)
        let position = age / estimatedWordDuration * Double(letters.count)
        let index = min(letters.count - 1, Int(position))
        let current = Self.pose(for: String(letters[index]))
        let next = Self.pose(for: String(letters[min(index + 1, letters.count - 1)]))
        let blend = Self.ease(Float((position - floor(position) - 0.45) / 0.55))
        let pose = current.blended(toward: next, amount: blend)
        let envelope = Self.ease(Float(age / 0.035))
            * Self.ease(Float((estimatedWordDuration - age) / 0.07))
        return ZenMouthPose().blended(toward: pose, amount: envelope)
    }

    private static func ease(_ value: Float) -> Float {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private static func pose(for sound: String) -> ZenMouthPose {
        if sound.isEmpty || sound == "sil" || sound == "pau" { return .init() }
        if sound.allSatisfy({ "mbp .,!?:;".contains($0) }) { return .init(opening: 0.03) }
        if sound.contains(where: { "aɑæäɐʌ".contains($0) }) { return .init(opening: 0.95) }
        if sound.contains(where: { "oɔåuʊyöøœ".contains($0) }) { return .init(opening: 0.60, rounding: 0.8) }
        if sound.contains(where: { "eɛəiɪé".contains($0) }) { return .init(opening: 0.45) }
        if sound.contains(where: { "fv".contains($0) }) { return .init(opening: 0.12) }
        return .init(opening: 0.23)
    }
}

struct ZenBreathMotion {
    struct Sample {
        let expansion: Float
        let phase: String
        let duration: TimeInterval
        let index: Int
    }

    static func sample(at elapsed: TimeInterval, technique: BreathingTechnique) -> Sample {
        let durations = [technique.inhale, technique.holdIn, technique.exhale, technique.holdOut]
            .map { $0.isFinite ? max(0, $0) : 0 }
        let total = durations.reduce(0, +)
        guard total > 0 else { return Sample(expansion: 0, phase: "", duration: 0, index: -1) }
        var position = max(0, elapsed).truncatingRemainder(dividingBy: total)
        for index in durations.indices where durations[index] > 0 {
            let duration = durations[index]
            if position < duration {
                let eased = Float((1 - cos(position / duration * .pi)) / 2)
                let expansion: Float = index == 0 ? eased : index == 1 ? 1 : index == 2 ? 1 - eased : 0
                return Sample(expansion: expansion, phase: index == 0 ? "Inhale" : index == 2 ? "Exhale" : "Hold", duration: duration, index: index)
            }
            position -= duration
        }
        return Sample(expansion: 0, phase: "Inhale", duration: durations[0], index: 0)
    }
}
