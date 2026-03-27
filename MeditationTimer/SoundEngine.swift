import AVFoundation
import Foundation

/// Procedurally generates peaceful meditation sounds using AVAudioEngine.
final class SoundEngine {
    private let engine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private var isRunning = false

    enum Sound: String, CaseIterable, Codable {
        case singingBowl = "Singing Bowl"
        case gentleChime = "Gentle Chime"
        case none = "None"
    }

    init() {}

    // MARK: - Public API

    func playSound(_ sound: Sound) {
        guard sound != .none else { return }
        stopAll()

        switch sound {
        case .singingBowl:
            playSingingBowl()
        case .gentleChime:
            playGentleChime()
        case .none:
            break
        }
    }

    func startAmbientRain() {
        stopAll()
        playRainAmbience()
    }

    func stopAll() {
        for node in playerNodes {
            node.stop()
        }
        playerNodes.removeAll()

        if isRunning {
            engine.stop()
            engine.reset()
            isRunning = false
        }
    }

    // MARK: - Singing Bowl

    private func playSingingBowl() {
        let sampleRate: Double = 44100
        let duration: Double = 6.0
        let frameCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let data = buffer.floatChannelData![0]

        // Singing bowl: fundamental + harmonics with slow decay
        let fundamentalFreq: Double = 220.0
        let harmonics: [(freq: Double, amp: Double)] = [
            (fundamentalFreq, 0.4),
            (fundamentalFreq * 2.0, 0.25),
            (fundamentalFreq * 3.0, 0.15),
            (fundamentalFreq * 4.76, 0.1),  // Inharmonic partial for metallic quality
            (fundamentalFreq * 6.2, 0.05),
        ]

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            for harmonic in harmonics {
                let envelope = exp(-t * (0.3 + harmonic.freq * 0.001))
                sample += sin(2.0 * .pi * harmonic.freq * t) * harmonic.amp * envelope
            }

            // Gentle amplitude wobble (beating effect)
            let wobble = 1.0 + 0.05 * sin(2.0 * .pi * 1.5 * t)
            sample *= wobble

            // Fade in for the first 20ms to avoid click
            let fadeIn = min(1.0, t / 0.02)

            data[i] = Float(sample * fadeIn * 0.5)
        }

        playBuffer(buffer, format: format)
    }

    // MARK: - Gentle Chime

    private func playGentleChime() {
        let sampleRate: Double = 44100
        let duration: Double = 4.0
        let frameCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let data = buffer.floatChannelData![0]

        // Three chime strikes with slight delays
        let strikes: [(delay: Double, freq: Double, amp: Double)] = [
            (0.0, 1200.0, 0.35),
            (0.6, 1500.0, 0.25),
            (1.4, 1800.0, 0.20),
        ]

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            for strike in strikes {
                let strikeT = t - strike.delay
                guard strikeT >= 0 else { continue }

                let envelope = exp(-strikeT * 2.5)
                let tone = sin(2.0 * .pi * strike.freq * strikeT)
                let overtone = sin(2.0 * .pi * strike.freq * 2.76 * strikeT) * 0.15
                sample += (tone + overtone) * strike.amp * envelope
            }

            // Fade in
            let fadeIn = min(1.0, t / 0.005)

            data[i] = Float(sample * fadeIn * 0.5)
        }

        playBuffer(buffer, format: format)
    }

    // MARK: - Breathing Cue Sounds

    /// Play a rising breath-like whoosh for inhale phase
    func playInhaleBreath(duration: Double) {
        playBreathSound(duration: duration, isInhale: true)
    }

    /// Play a falling breath-like whoosh for exhale phase
    func playExhaleBreath(duration: Double) {
        playBreathSound(duration: duration, isInhale: false)
    }

    private func playBreathSound(duration: Double, isInhale: Bool) {
        let sampleRate: Double = 44100
        let clampedDuration = max(0.5, duration)
        let frameCount = Int(sampleRate * clampedDuration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let data = buffer.floatChannelData![0]

        // Simple low-pass filter state
        var filtered: Double = 0
        let volume: Double = 0.08

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let progress = t / clampedDuration  // 0.0 -> 1.0

            // White noise source
            let white = Double.random(in: -1.0...1.0)

            // Envelope: inhale rises then fades, exhale starts strong then fades
            let envelope: Double
            if isInhale {
                // Gentle rise to peak at ~70%, then soft fade
                envelope = sin(progress * .pi) * pow(progress, 0.3)
            } else {
                // Starts strong, gentle fall
                envelope = sin(progress * .pi) * pow(1.0 - progress, 0.3)
            }

            // Filter cutoff shifts: inhale goes higher pitch, exhale goes lower
            let cutoff: Double
            if isInhale {
                cutoff = 0.02 + progress * 0.08  // Low to mid
            } else {
                cutoff = 0.10 - progress * 0.07  // Mid to low
            }

            // Simple one-pole low-pass filter
            filtered = filtered + cutoff * (white - filtered)

            // Fade edges to avoid clicks
            let fadeIn = min(1.0, t / 0.03)
            let fadeOut = min(1.0, (clampedDuration - t) / 0.03)

            data[i] = Float(filtered * envelope * volume * fadeIn * fadeOut)
        }

        playBuffer(buffer, format: format)
    }

    // MARK: - Rain Ambience

    private func playRainAmbience() {
        let sampleRate: Double = 44100
        let duration: Double = 10.0  // Loop length
        let frameCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let data = buffer.floatChannelData![0]

        // Brown noise (integrated white noise) for a warm rain sound
        var brownNoise: Double = 0
        for i in 0..<frameCount {
            let white = Double.random(in: -1.0...1.0)
            brownNoise += white * 0.02
            brownNoise = max(-1.0, min(1.0, brownNoise))

            // Mix brown and white noise for rain texture
            let sample = brownNoise * 0.6 + white * 0.08

            // Crossfade at loop boundaries for seamless looping
            let t = Double(i) / Double(frameCount)
            let crossfade: Double
            let fadeLen = 0.05
            if t < fadeLen {
                crossfade = t / fadeLen
            } else if t > (1.0 - fadeLen) {
                crossfade = (1.0 - t) / fadeLen
            } else {
                crossfade = 1.0
            }

            data[i] = Float(sample * crossfade * 0.3)
        }

        playBufferLooping(buffer, format: format)
    }

    // MARK: - Playback Helpers

    private func playBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        do {
            if !isRunning {
                try engine.start()
                isRunning = true
            }
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }

        playerNodes.append(playerNode)
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        playerNode.play()
    }

    private func playBufferLooping(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        do {
            if !isRunning {
                try engine.start()
                isRunning = true
            }
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }

        playerNodes.append(playerNode)
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        playerNode.play()
    }
}
