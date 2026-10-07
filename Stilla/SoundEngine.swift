import AVFoundation
import Foundation
import UIKit

/// Procedurally generates peaceful meditation sounds using AVAudioEngine.
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let toneNode = AVAudioPlayerNode()
    private let loopNode = AVAudioPlayerNode()
    private let breathNode = AVAudioPlayerNode()
    private let ambientMixerNode = AVAudioMixerNode()
    private var ambientSourceNode: AVAudioSourceNode?
    private var currentAmbientSound: AmbientSound = .none
    private var nextAmbientSound: AmbientSound = .none
    private var transitionFrames: Double = 0
    private let totalTransitionFrames: Double = 0.5 * 44100 // 500ms crossfade
    private var isTransitioning: Bool = false
    private var ambientEnvelope: Float = 1.0
    private var ambientFadeTimer: Timer?
    private let defaultAmbientFadeIn: TimeInterval = 3.0
    private let defaultAmbientFadeOut: TimeInterval = 3.0
    private var playbackGenerations: [ObjectIdentifier: UUID] = [:]

    
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
        set {
            toneNode.volume = newValue
            breathNode.volume = newValue
        }
    }
    
    var ambientVolume: Float = 0.5 {
        didSet {
            applyAmbientMixVolume()
        }
    }

    init() {
        configureAudioSession()
        engine.attach(toneNode)
        engine.attach(breathNode)
        engine.attach(loopNode)
        engine.attach(ambientMixerNode)
        setupAmbientSourceNode()

        // Build the graph once. Adding a chime or breathing cue must not
        // reconnect an already-running graph underneath the ambience.
        let cueFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(toneNode, to: engine.mainMixerNode, format: cueFormat)
        engine.connect(breathNode, to: engine.mainMixerNode, format: cueFormat)

        engine.connect(loopNode, to: ambientMixerNode, format: nil)
        engine.connect(ambientMixerNode, to: engine.mainMixerNode, format: nil)
        loopNode.volume = 1.0
        applyAmbientMixVolume()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--mountain-audio-diagnostics") {
            installAudioDiagnostics()
        }
        #endif
    }


    private func setupAmbientSourceNode() {
        // The procedural oscillators and crossfade use this sample rate.
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
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
        engine.connect(sourceNode, to: ambientMixerNode, format: format)
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
        let volume = 0.2
        
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
            // Narration and ambience share this playback session. Ducking applies
            // only to audio from other apps, not our own ambient mixer.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Public API

    /// Guide previews use an ambient audio session. Restore background playback
    /// for meditation, including sessions with no spoken guide.
    func prepareMeditationAudio(toneVolume: Float, ambientVolume: Float) {
        configureAudioSession()
        self.toneVolume = toneVolume
        self.ambientVolume = ambientVolume
    }

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
        if sound == .none {
            stopAmbientSoundWithFadeOut()
            return
        }

        ambientFadeTimer?.invalidate()

        let wasRunning = engine.isRunning
        guard startEngineIfNeeded() else { return }
        if !wasRunning {
            currentAmbientSound = sound
            nextAmbientSound = .none
            isTransitioning = false
            handleLoopPlayback(for: sound)
            if sound != .none {
                ambientEnvelope = 0
                applyAmbientMixVolume()
                rampAmbientEnvelope(to: 1.0, duration: defaultAmbientFadeIn)
            }
        } else if sound != currentAmbientSound {
            nextAmbientSound = sound
            transitionFrames = 0
            isTransitioning = true
            handleLoopPlayback(for: sound)
        }
        // Also recover when the same ambience is selected during its fade-out.
        if ambientEnvelope < 1.0 {
            rampAmbientEnvelope(to: 1.0, duration: defaultAmbientFadeIn)
        }
    }

    func stopAmbientSoundWithFadeOut(duration: TimeInterval? = nil) {
        let fadeDuration = duration ?? defaultAmbientFadeOut
        guard currentAmbientSound != .none || nextAmbientSound != .none || isTransitioning || loopNode.isPlaying else {
            stopEngineIfIdle()
            return
        }

        rampAmbientEnvelope(to: 0.0, duration: fadeDuration) { [weak self] in
            guard let self = self else { return }
            self.currentAmbientSound = .none
            self.nextAmbientSound = .none
            self.isTransitioning = false
            self.transitionFrames = 0
            self.loopNode.stop()
            self.stopEngineIfIdle()
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
        playbackGenerations.removeAll()
        ambientFadeTimer?.invalidate()
        toneNode.stop()
        breathNode.stop()
        loopNode.stop()
        currentAmbientSound = .none
        nextAmbientSound = .none
        isTransitioning = false
        transitionFrames = 0
        ambientEnvelope = 1.0
        applyAmbientMixVolume()
        
        // Reset phases to avoid clicks on restart
        phase = 0
        leftPhase = 0
        rightPhase = 0

        if engine.isRunning {
            engine.stop()
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

    /// Schedule one full technique cycle in the engine, with silence during
    /// holds. Playback continues when the world or phone screen is inactive.
    func startBreathingLoop(technique: BreathingTechnique = .defaultTechnique) {
        stopBreathingSounds()
        let durations = technique.phaseDurations
        let sampleRate = 44100.0
        let frameCounts = durations.map { Int(($0 * sampleRate).rounded()) }
        let totalFrames = frameCounts.reduce(0, +)
        guard totalFrames > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let cycle = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)),
              let output = cycle.floatChannelData?[0] else { return }
        cycle.frameLength = cycle.frameCapacity
        output.update(repeating: 0, count: totalFrames)
        var offset = 0
        for index in durations.indices {
            if (index == 0 || index == 2), frameCounts[index] > 0,
               let breath = makeBreathBuffer(duration: durations[index], isInhale: index == 0),
               let input = breath.floatChannelData?[0] {
                output.advanced(by: offset).update(from: input, count: min(frameCounts[index], Int(breath.frameLength)))
            }
            offset += frameCounts[index]
        }
        playBufferLooping(cycle, format: cycle.format, on: breathNode)
        #if DEBUG
        print("Mountain audio: breathing loop, technique=\(technique.id), phases=\(durations), playing=\(breathNode.isPlaying)")
        #endif
    }

    func stopBreathingSounds() {
        playbackGenerations.removeValue(forKey: ObjectIdentifier(breathNode))
        breathNode.stop()
    }

    func stopMeditationSignals() {
        stopBreathingSounds()
        playbackGenerations.removeValue(forKey: ObjectIdentifier(toneNode))
        toneNode.stop()
    }

    private func makeBreathBuffer(duration: Double, isInhale: Bool) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let clampedDuration = max(0.5, duration)
        let frameCount = Int(sampleRate * clampedDuration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let data = buffer.floatChannelData![0]

        // Simple low-pass filter state
        var filtered: Double = 0
        // Breathing cues follow the same mix as chimes/signals (toneVolume).
        // Apply the user's level on the node so an already-scheduled loop can
        // respond to volume changes without regenerating eight seconds of PCM.
        let volume: Double = 0.16

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

        return buffer
    }

    private func playBreathSound(duration: Double, isInhale: Bool) {
        guard let buffer = makeBreathBuffer(duration: duration, isInhale: isInhale) else { return }
        playBuffer(buffer, format: buffer.format, on: breathNode)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--zen-avatar-breath-diagnostics") {
            let data = buffer.floatChannelData![0]
            let peak = (0..<Int(buffer.frameLength)).reduce(Float(0)) { max($0, abs(data[$1])) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self else { return }
                let renderedFrames = self.breathNode.lastRenderTime
                    .flatMap { self.breathNode.playerTime(forNodeTime: $0)?.sampleTime } ?? 0
                print("Zen breath audio: \(isInhale ? "Inhale" : "Exhale"), peak=\(peak), playing=\(self.breathNode.isPlaying), renderedFrames=\(renderedFrames), outputVolume=\(AVAudioSession.sharedInstance().outputVolume)")
            }
        }
        #endif
    }

    // MARK: - Playback Helpers

    private func playBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, on node: AVAudioPlayerNode) {
        guard startEngineIfNeeded() else { return }

        let key = ObjectIdentifier(node)
        let generation = UUID()
        playbackGenerations[key] = generation
        node.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self, weak node] _ in
            DispatchQueue.main.async {
                guard let self, let node, self.playbackGenerations[key] == generation else { return }
                self.playbackGenerations.removeValue(forKey: key)
                node.stop()
                self.stopEngineIfIdle()
            }
        }
        node.play()
    }

    private func playBufferLooping(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, on node: AVAudioPlayerNode) {
        playbackGenerations.removeValue(forKey: ObjectIdentifier(node))
        guard startEngineIfNeeded() else { return }

        node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        node.play()
    }

    private func startEngineIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            print("Failed to start audio engine: \(error)")
            return false
        }
    }
}

private extension SoundEngine {
    func applyAmbientMixVolume() {
        ambientMixerNode.outputVolume = max(0, min(1, ambientVolume * ambientEnvelope))
    }

    func rampAmbientEnvelope(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        ambientFadeTimer?.invalidate()

        let start = ambientEnvelope
        if duration <= 0 || abs(start - target) < 0.001 {
            ambientEnvelope = target
            applyAmbientMixVolume()
            completion?()
            return
        }

        let interval: TimeInterval = 1.0 / 60.0
        let steps = max(1, Int(ceil(duration / interval)))
        var stepIndex = 0

        ambientFadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            stepIndex += 1
            let progress = min(1.0, Float(stepIndex) / Float(steps))
            self.ambientEnvelope = start + (target - start) * progress
            self.applyAmbientMixVolume()

            if stepIndex >= steps {
                timer.invalidate()
                self.ambientFadeTimer = nil
                self.ambientEnvelope = target
                self.applyAmbientMixVolume()
                completion?()
            }
        }
        if let fadeTimer = ambientFadeTimer {
            RunLoop.main.add(fadeTimer, forMode: .common)
        }
    }

    func stopEngineIfIdle() {
        guard engine.isRunning else { return }
        let hasAmbient = currentAmbientSound != .none || nextAmbientSound != .none || isTransitioning
        let hasActiveNodes = toneNode.isPlaying || breathNode.isPlaying || loopNode.isPlaying
        guard !hasAmbient && !hasActiveNodes else { return }
        engine.stop()
    }
}

#if DEBUG
private extension SoundEngine {
    /// Opt-in simulator/device verification of rendered PCM, not just isPlaying.
    /// No taps or metering run during normal use.
    func installAudioDiagnostics() {
        for (name, node) in [("ambience", ambientMixerNode as AVAudioNode),
                             ("breathing", breathNode as AVAudioNode),
                             ("output", engine.mainMixerNode as AVAudioNode)] {
            var frames = 0
            var energy = 0.0
            var samples = 0
            node.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
                guard let channels = buffer.floatChannelData else { return }
                for channel in 0..<Int(buffer.format.channelCount) {
                    for frame in 0..<Int(buffer.frameLength) {
                        let sample = Double(channels[channel][frame])
                        energy += sample * sample
                    }
                }
                frames += Int(buffer.frameLength)
                samples += Int(buffer.frameLength * buffer.format.channelCount)
                guard frames >= Int(buffer.format.sampleRate * 2) else { return }
                let rms = sqrt(energy / Double(max(1, samples)))
                frames = 0; samples = 0; energy = 0
                DispatchQueue.main.async {
                    guard let self else { return }
                    print("Mountain audio PCM: \(name), rms=\(rms), engine=\(self.engine.isRunning), breath=\(self.breathNode.isPlaying)")
                }
            }
        }
    }
}
#endif

extension SoundEngine.AmbientSound {
    /// Single source of truth for ambiences gated by the sound bundle purchase.
    static let premiumForSoundBundle: Set<Self> = [
        .delta, .alpha, .beta,
        .whiteNoise, .pinkNoise, .brownNoise,
        .solfeggioLove, .solfeggioNature,
        .ancientFlora, .greenCanopy
    ]
}
