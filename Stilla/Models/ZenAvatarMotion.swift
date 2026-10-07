import Foundation

struct ZenMouthPose: Equatable {
    var opening: Float = 0
    var rounding: Float = 0
    /// Positive values spread the corners; negative values tuck the lower lip
    /// towards the upper incisors (F/V). Independent of jaw opening.
    var lipShape: Float = 0

    func blended(toward other: Self, amount: Float) -> Self {
        Self(opening: opening + (other.opening - opening) * amount,
             rounding: rounding + (other.rounding - rounding) * amount,
             lipShape: lipShape + (other.lipShape - lipShape) * amount)
    }
}

/// Offline audio analysis, sampled against AVAudioPlayer.currentTime. No model,
/// phoneme recognition or network work runs on the phone.
struct GuideLipSyncTrack: Decodable {
    struct Cue: Decodable {
        let start: TimeInterval
        let end: TimeInterval
        let value: String
    }
    let version: Int
    let audioSHA256: String
    let duration: TimeInterval
    let mouthCues: [Cue]

    var isValid: Bool {
        guard version == 1, duration.isFinite, duration > 0,
              !mouthCues.isEmpty, mouthCues.count < 20_000 else { return false }
        var end: TimeInterval = 0
        for cue in mouthCues {
            guard cue.start.isFinite, cue.end.isFinite, cue.start >= 0,
                  abs(cue.start - end) < 0.011, cue.end > cue.start,
                  cue.end <= duration + 0.02,
                  ["A", "B", "C", "D", "E", "F", "G", "H", "X"].contains(cue.value) else { return false }
            end = cue.end
        }
        return abs(end - duration) < 0.03
    }

    func pose(at time: TimeInterval) -> ZenMouthPose {
        guard time.isFinite, time >= 0, time < duration else { return .init() }
        // Binary search permits scrubbing/late timer callbacks without accumulating
        // drift. Anticipation and neighbouring shapes provide coarticulation.
        let sample = min(duration - 0.0001, time + 0.020)
        var low = 0, high = mouthCues.count
        while low < high {
            let mid = (low + high) / 2
            if mouthCues[mid].end <= sample { low = mid + 1 } else { high = mid }
        }
        guard low < mouthCues.count else { return .init() }
        let cue = mouthCues[low]
        let current = Self.pose(for: cue.value)
        let previousDuration = low > 0 ? mouthCues[low-1].end - mouthCues[low-1].start : 0
        let nextDuration = low+1 < mouthCues.count ? mouthCues[low+1].end - mouthCues[low+1].start : 0
        let lead = min(0.045, min(cue.end - cue.start, previousDuration) * 0.3)
        let tail = min(0.045, min(cue.end - cue.start, nextDuration) * 0.3)
        if sample < cue.start + lead, low > 0 {
            let t = Float((sample - cue.start + lead) / (2 * lead))
            return Self.pose(for: mouthCues[low - 1].value).blended(toward: current, amount: t * t * (3 - 2 * t))
        }
        if sample > cue.end - tail, low + 1 < mouthCues.count {
            let t = Float((sample - cue.end + tail) / (2 * tail))
            return current.blended(toward: Self.pose(for: mouthCues[low + 1].value), amount: t * t * (3 - 2 * t))
        }
        return current
    }

    private static func pose(for value: String) -> ZenMouthPose {
        switch value {
        case "A", "X": return .init() // P/B/M seal, or silence
        case "B": return .init(opening: 0.13, lipShape: 0.45)
        case "C": return .init(opening: 0.46, lipShape: 0.3)
        case "D": return .init(opening: 0.82, lipShape: 0.12)
        case "E": return .init(opening: 0.40, rounding: 0.5)
        case "F": return .init(opening: 0.24, rounding: 1)
        case "G": return .init(opening: 0.10, lipShape: -1)
        case "H": return .init(opening: 0.36, lipShape: 0.2)
        default: return .init()
        }
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
    private var articulation: ZenMouthPose?
    private var articulationAt: TimeInterval = -.infinity

    mutating func begin() { isSpeaking = true }
    mutating func stop() { self = Self() }

    /// File playback has no Apple phoneme callbacks. Use the actual audio meter
    /// for approximate jaw movement, including silence inside each recording.
    mutating func speak(level: Float, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        isSpeaking = true
        audioLevel = level.isFinite ? min(1, max(0, level)) : 0
        audioSampleAt = time
    }

    mutating func speak(pose: ZenMouthPose?, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        articulation = pose
        articulationAt = time
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
        if let articulation, time >= articulationAt, time - articulationAt < 0.15 {
            return articulation
        }
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
        if sound.contains(where: { "eɛəiɪé".contains($0) }) { return .init(opening: 0.45, lipShape: 0.4) }
        if sound.contains(where: { "fv".contains($0) }) { return .init(opening: 0.12, lipShape: -1) }
        return .init(opening: 0.23)
    }
}

enum GuideEyeMotion {
    static func blinkClosure(age: Float) -> Float {
        func ease(_ x: Float) -> Float { let t = min(1, max(0, x)); return t * t * (3 - 2 * t) }
        guard age >= 0, age < 0.25 else { return 0 }
        if age < 0.065 { return ease(age / 0.065) }
        if age < 0.09 { return 1 }
        return 1 - ease((age - 0.09) / 0.16)
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
        let durations = technique.phaseDurations
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
