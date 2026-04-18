import AVFoundation
import Foundation
import UIKit

/// Procedurally generates peaceful meditation sounds using AVAudioEngine.
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let toneNode = AVAudioPlayerNode()
    private let loopNode = AVAudioPlayerNode()
    private let breathNode = AVAudioPlayerNode()
    private var isRunning = false
    private var ambientSourceNode: AVAudioSourceNode?
    private var currentAmbientSound: AmbientSound = .none
    private var nextAmbientSound: AmbientSound = .none
    private var transitionFrames: Double = 0
    private let totalTransitionFrames: Double = 0.5 * 44100 // 500ms crossfade
    private var isTransitioning: Bool = false

    
    // Generator states
    private var phase: Double = 0
    private var leftPhase: Double = 0
    private var rightPhase: Double = 0
    private var brownNoiseState: Double = 0
    private var pinkNoiseState: [Double] = [0, 0, 0, 0, 0, 0, 0]


    enum Sound: String, CaseIterable, Codable {
        case singingBowl = "Singing Bowl"
        case gentleChime = "Gentle Chime"
        case zenWoodblock = "Zen Woodblock"
        case bambooChime = "Bamboo Chime"
        case templeBell = "Temple Bell"
        case none = "None"
    }

    enum AmbientSound: String, CaseIterable, Codable {
        case none = "None"
        case rain = "Rain Ambience"
        case whiteNoise = "White Noise"
        case pinkNoise = "Pink Noise"
        case brownNoise = "Brown Noise"
        case delta = "Deep Sleep (Delta)"
        case alpha = "Creativity (Alpha)"
        case beta = "Focus (Beta)"
        case solfeggioLove = "Love Frequency (528 Hz)"
        case solfeggioNature = "Nature's Pitch (432 Hz)"
        case ancientFlora = "Ancient Flora"
        case greenCanopy = "Green Canopy"
    }


    var toneVolume: Float {
        get { toneNode.volume }
        set { toneNode.volume = newValue }
    }
    
    var ambientVolume: Float = 0.5 {
        didSet {
            loopNode.volume = ambientVolume
        }
    }

    init() {
        engine.attach(toneNode)
        engine.attach(breathNode)
        engine.attach(loopNode)
        setupAmbientSourceNode()
        configureAudioSession()
        
        engine.connect(loopNode, to: engine.mainMixerNode, format: nil)
        loopNode.volume = ambientVolume
    }


    private func setupAmbientSourceNode() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        let sourceNode = AVAudioSourceNode { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = self.generateAmbientSample()
                
                // Assign Left channel
                if ablPointer.count > 0 {
                    let leftBuf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(ablPointer[0])
                    leftBuf[frame] = Float(sample.left)
                }
                
                // Assign Right channel (if exists)
                if ablPointer.count > 1 {
                    let rightBuf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(ablPointer[1])
                    rightBuf[frame] = Float(sample.right)
                }
            }
            return noErr
        }
        
        self.ambientSourceNode = sourceNode
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    
    private func generateSample(for sound: AmbientSound, volume: Double, sampleRate: Double) -> (left: Double, right: Double) {
        switch sound {
        case .none, .ancientFlora, .greenCanopy:
            return (0, 0)
            
        case .whiteNoise:
            let val = Double.random(in: -1.0...1.0) * 0.05 * volume
            return (val, val)
            
        case .pinkNoise:
            let white = Double.random(in: -1.0...1.0)
            pinkNoiseState[0] = 0.99886 * pinkNoiseState[0] + white * 0.0555179
            pinkNoiseState[1] = 0.99332 * pinkNoiseState[1] + white * 0.0750759
            pinkNoiseState[2] = 0.96900 * pinkNoiseState[2] + white * 0.1538520
            pinkNoiseState[3] = 0.86650 * pinkNoiseState[3] + white * 0.3104856
            pinkNoiseState[4] = 0.55000 * pinkNoiseState[4] + white * 0.5329522
            pinkNoiseState[5] = -0.7616 * pinkNoiseState[5] - white * 0.0168980
            let pink = pinkNoiseState[0] + pinkNoiseState[1] + pinkNoiseState[2] + pinkNoiseState[3] + pinkNoiseState[4] + pinkNoiseState[5] + pinkNoiseState[6] + white * 0.5362
            pinkNoiseState[6] = white * 0.115926
            let val = pink * 0.05 * volume
            return (val, val)
            
        case .brownNoise:
            let white = Double.random(in: -1.0...1.0)
            brownNoiseState = (brownNoiseState + (0.02 * white)) / 1.02
            let val = brownNoiseState * 0.5 * volume
            return (val, val)
            
        case .rain:
            let white = Double.random(in: -1.0...1.0)
            brownNoiseState = (brownNoiseState + white * 0.02) / 1.02
            let val = (brownNoiseState * 0.6 + white * 0.08) * 0.4 * volume
            return (val, val)
            
        case .solfeggioLove, .solfeggioNature:
            let freq = (sound == .solfeggioLove) ? 528.0 : 432.0
            phase += (2.0 * .pi * freq) / sampleRate
            if phase > 2.0 * .pi { phase -= 2.0 * .pi }
            let mod = 1.0 + 0.15 * sin(phase * 0.0001) // Very slow modulation
            let val = sin(phase) * mod * 0.3 * volume
            return (val, val)
            
        case .delta, .alpha, .beta:
            let baseFreq = (sound == .delta) ? 150.0 : ((sound == .alpha) ? 200.0 : 250.0)
            let beatFreq = (sound == .delta) ? 2.0 : ((sound == .alpha) ? 10.0 : 15.0)
            leftPhase += (2.0 * .pi * baseFreq) / sampleRate
            rightPhase += (2.0 * .pi * (baseFreq + beatFreq)) / sampleRate
            if leftPhase > 2.0 * .pi { leftPhase -= 2.0 * .pi }
            if rightPhase > 2.0 * .pi { rightPhase -= 2.0 * .pi }
            return (sin(leftPhase) * 0.2 * volume, sin(rightPhase) * 0.2 * volume)
        }
    }

    private func generateAmbientSample() -> (left: Double, right: Double) {
        let sampleRate: Double = 44100
        let volume = Double(ambientVolume) * 0.2
        
        if isTransitioning {
            let s1 = generateSample(for: currentAmbientSound, volume: volume, sampleRate: sampleRate)
            let s2 = generateSample(for: nextAmbientSound, volume: volume, sampleRate: sampleRate)
            
            let t = transitionFrames / totalTransitionFrames
            // Sinusoidal crossfade for equal power
            let mix1 = cos(t * .pi / 2)
            let mix2 = sin(t * .pi / 2)
            
            transitionFrames += 1
            if transitionFrames >= totalTransitionFrames {
                currentAmbientSound = nextAmbientSound
                isTransitioning = false
                transitionFrames = 0
            }
            
            return (s1.left * mix1 + s2.left * mix2, s1.right * mix1 + s2.right * mix2)
        } else {
            return generateSample(for: currentAmbientSound, volume: volume, sampleRate: sampleRate)
        }
    }
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .mixWithOthers allows us to play ambient sounds alongside the Guru's voice.
            // .duckOthers lowers the volume of other sounds (like our own ambient loops) when the Guru speaks.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Public API

    func playSound(_ sound: Sound) {
        guard sound != .none else { return }
        toneNode.stop()

        switch sound {
        case .singingBowl: playSingingBowl()
        case .gentleChime: playGentleChime()
        case .zenWoodblock: playZenWoodblock()
        case .bambooChime: playBambooChime()
        case .templeBell: playTempleBell()
        case .none: break
        }
    }

    func startAmbientSound(_ sound: AmbientSound) {
        if !isRunning {
            currentAmbientSound = sound
            try? engine.start()
            isRunning = true
            handleLoopPlayback(for: sound)
        } else if sound != currentAmbientSound {
            nextAmbientSound = sound
            transitionFrames = 0
            isTransitioning = true
            handleLoopPlayback(for: sound)
        }
    }

    private func handleLoopPlayback(for sound: AmbientSound) {
        if sound == .ancientFlora || sound == .greenCanopy {
            let assetName = sound == .ancientFlora ? "Ancient Flora Audio" : "Green Canopy Audio"
            if let buffer = loadLoopAsset(named: assetName) {
                loopNode.stop()
                loopNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
                loopNode.play()
            }
        } else {
            loopNode.stop()
        }
    }
    
    private func loadLoopAsset(named name: String) -> AVAudioPCMBuffer? {
        guard let dataAsset = NSDataAsset(name: name) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).m4a")
        
        do {
            if !FileManager.default.fileExists(atPath: tempURL.path) {
                try dataAsset.data.write(to: tempURL)
            }
            let file = try AVAudioFile(forReading: tempURL)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            print("Error loading loop asset \(name): \(error)")
            return nil
        }
    }

    func stopAll() {
        toneNode.stop()
        breathNode.stop()
        loopNode.stop()
        currentAmbientSound = .none
        
        // Reset phases to avoid clicks on restart
        phase = 0
        leftPhase = 0
        rightPhase = 0

        if isRunning {
            engine.stop()
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

        playBuffer(buffer, format: format, on: toneNode)
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

        playBuffer(buffer, format: format, on: toneNode)
    }

    // MARK: - Premium Sounds


    private func playZenWoodblock() {
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let frameCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let data = buffer.floatChannelData![0]

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let white = Double.random(in: -1.0...1.0)
            
            // Hard percussive attack, very fast decay
            let env = exp(-t * 25.0)
            
            // Fundamental hollow frequency
            let freq: Double = 600.0
            let tone = sin(2.0 * .pi * freq * t)
            
            // Short burst of filtered noise for wood texture
            let woodNoise = white * exp(-t * 80.0)
            
            data[i] = Float((tone + woodNoise * 0.3) * env * 0.4)
        }
        playBuffer(buffer, format: format, on: toneNode)
    }

    private func playBambooChime() {
        let sampleRate: Double = 44100
        let duration: Double = 3.0
        let frameCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let data = buffer.floatChannelData![0]

        // Sequence of 5 clacks
        let clacks: [(delay: Double, freq: Double)] = [
            (0.0, 1500.0), (0.15, 1800.0), (0.35, 1650.0), (0.6, 2100.0), (0.9, 1750.0)
        ]
        
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample: Double = 0
            
            for c in clacks {
                let ct = t - c.delay
                if ct < 0 { continue }
                let env = exp(-ct * 30.0)
                let tone = sin(2.0 * .pi * c.freq * ct)
                let noise = Double.random(in: -1.0...1.0) * exp(-ct * 60.0)
                sample += (tone + noise * 0.2) * env * 0.3
            }
            
            data[i] = Float(sample * 0.4)
        }
        playBuffer(buffer, format: format, on: toneNode)
    }

    private func playTempleBell() {
        let sampleRate: Double = 44100
        let duration: Double = 7.0
        let frameCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let data = buffer.floatChannelData![0]

        let baseFreq: Double = 200.0
        let partials: [(ratio: Double, amp: Double, decay: Double)] = [
            (1.0, 0.4, 0.5), (2.7, 0.3, 1.2), (4.2, 0.2, 2.0), (5.8, 0.1, 3.0)
        ]
        
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample: Double = 0
            for p in partials {
                let freq = baseFreq * p.ratio
                let envelope = exp(-t * p.decay)
                sample += sin(2.0 * .pi * freq * t) * p.amp * envelope
            }
            
            let fadeIn = min(1.0, t / 0.01)
            let wob = 1.0 + 0.15 * sin(2.0 * .pi * 2.0 * t) * exp(-t * 0.5)
            data[i] = Float(sample * fadeIn * wob * 0.4)
        }
        playBuffer(buffer, format: format, on: toneNode)
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
        // Breathing cues follow the same mix as chimes/signals (toneVolume).
        let volume: Double = Double(toneVolume) * 0.16

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

        playBuffer(buffer, format: format, on: breathNode)
    }

    // MARK: - Playback Helpers

    private func playBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, on node: AVAudioPlayerNode) {
        engine.disconnectNodeInput(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            if !isRunning {
                try engine.start()
                isRunning = true
            }
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }

        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
    }

    private func playBufferLooping(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, on node: AVAudioPlayerNode) {
        engine.disconnectNodeInput(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            if !isRunning {
                try engine.start()
                isRunning = true
            }
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }

        node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        node.play()
    }
}
