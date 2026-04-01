import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class GuruManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = GuruManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentScript: MeditationScript?
    private var currentStepIndex = 0
    private var isPlaying = false
    private var timer: Timer?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func play(script: MeditationScript) {
        stop()
        self.currentScript = script
        self.currentStepIndex = 0
        self.isPlaying = true
        
        // Wait 2 seconds before the first phrase to allow for centering
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.speakNextStep()
            }
        }
    }

    func previewVoice(identifier: String) {
        stop()
        let utterance = AVSpeechUtterance(string: "Hello, I am Kai. This is my voice. I look forward to our practice together.")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 0.9
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        isPlaying = false
        synthesizer.stopSpeaking(at: .immediate)
        timer?.invalidate()
        timer = nil
    }

    func findBestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let enVoices = allVoices.filter { $0.language.contains("en") } // en-US, en-GB, etc.
        
        // Priority 1: Premium Female
        if let premiumFemale = enVoices.first(where: { $0.quality == .premium && $0.gender == .female }) {
            return premiumFemale
        }
        
        // Priority 2: Enhanced Female (e.g. Samantha Enhanced)
        if let enhancedFemale = enVoices.first(where: { $0.quality == .enhanced && $0.gender == .female }) {
            return enhancedFemale
        }
        
        // Priority 3: Any Premium
        if let premium = enVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        
        // Priority 4: Any Enhanced
        if let enhanced = enVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        
        return enVoices.first // Fallback
    }

    var availableHighQualityVoices: [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.contains("en") && $0.quality != .default }
            .sorted { v1, v2 in
                if v1.quality != v2.quality {
                    return v1.quality.rawValue > v2.quality.rawValue // Premium first
                }
                return v1.name < v2.name
            }
    }
    
    private func speakNextStep() {
        guard let script = currentScript, isPlaying else { return }
        guard currentStepIndex < script.steps.count else {
            isPlaying = false
            return 
        }
        
        let step = script.steps[currentStepIndex]
        let utterance = AVSpeechUtterance(string: step.text)
        
        MeditationManager.shared.updateLiveActivity(phrase: step.text)
        
        // Zen voice settings
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 0.9 // Grounded and deep
        utterance.volume = 1.0
        
        // Select the chosen voice via MeditationManager
        let voiceId = MeditationManager.shared.kaiVoiceIdentifier
        if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else if let bestVoice = findBestAvailableVoice() {
            utterance.voice = bestVoice
        }
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self = self, self.isPlaying, let script = self.currentScript else { return }
            
            let currentStep = script.steps[self.currentStepIndex]
            self.currentStepIndex += 1
            
            // Wait for the step's specified pause duration before proceeding
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: currentStep.pauseDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.speakNextStep()
                }
            }
        }
    }
}
