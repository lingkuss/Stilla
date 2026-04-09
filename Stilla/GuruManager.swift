import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class GuruManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = GuruManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentScript: MeditationScript?
    public var currentStepIndex = 0
    public var currentWordRange: NSRange?
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
        let utterance = AVSpeechUtterance(string: "Hello, I am Mimir. This is my voice. I look forward to our practice together.")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 0.9
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        isPlaying = false
        currentWordRange = nil
        synthesizer.stopSpeaking(at: .immediate)
        timer?.invalidate()
        timer = nil
    }

    func speak(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 0.9
        utterance.volume = 1.0
        let voiceId = MeditationManager.shared.kaiVoiceIdentifier
        if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else if let bestVoice = findBestAvailableVoice() {
            utterance.voice = bestVoice
        }
        synthesizer.speak(utterance)
    }

    private var preferredVoiceLanguages: [String] {
        AppLocalization.preferredLanguageCodes
    }

    private func isPreferredLanguage(_ voice: AVSpeechSynthesisVoice) -> Bool {
        let code = Locale(identifier: voice.language).language.languageCode?.identifier.lowercased() ?? ""
        return preferredVoiceLanguages.contains(code)
    }

    func findBestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let candidateVoices = allVoices.filter { isPreferredLanguage($0) }
        let preferredPool = candidateVoices.isEmpty ? allVoices : candidateVoices

        if let premiumFemale = preferredPool.first(where: { $0.quality == .premium && $0.gender == .female }) {
            return premiumFemale
        }

        if let enhancedFemale = preferredPool.first(where: { $0.quality == .enhanced && $0.gender == .female }) {
            return enhancedFemale
        }

        if let premium = preferredPool.first(where: { $0.quality == .premium }) {
            return premium
        }

        if let enhanced = preferredPool.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }

        return preferredPool.first
    }

    var availableHighQualityVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.quality != .default }
            .sorted { v1, v2 in
                let v1Preferred = isPreferredLanguage(v1)
                let v2Preferred = isPreferredLanguage(v2)
                if v1Preferred != v2Preferred {
                    return v1Preferred && !v2Preferred
                }
                if v1.quality != v2.quality {
                    return v1.quality.rawValue > v2.quality.rawValue
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

        currentWordRange = nil
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
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self = self, self.isPlaying, let script = self.currentScript else { return }
            guard self.currentStepIndex < script.steps.count else { return }
            let currentText = script.steps[self.currentStepIndex].text
            guard utterance.speechString == currentText else { return }
            self.currentWordRange = characterRange
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self = self, self.isPlaying, let script = self.currentScript else { return }
            guard self.currentStepIndex < script.steps.count else { return }

            let currentStep = script.steps[self.currentStepIndex]
            guard utterance.speechString == currentStep.text else { return }

            self.currentWordRange = nil

            // Wait for the step's specified pause duration, then advance.
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: currentStep.pauseDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.currentStepIndex += 1
                    self.speakNextStep()
                }
            }
        }
    }
}
