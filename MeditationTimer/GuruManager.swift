import Foundation
import AVFoundation

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
        speakNextStep()
    }
    
    func stop() {
        isPlaying = false
        synthesizer.stopSpeaking(at: .immediate)
        timer?.invalidate()
        timer = nil
    }
    
    private func speakNextStep() {
        guard let script = currentScript, isPlaying else { return }
        guard currentStepIndex < script.steps.count else {
            isPlaying = false
            return 
        }
        
        let step = script.steps[currentStepIndex]
        let utterance = AVSpeechUtterance(string: step.text)
        
        // Zen voice settings
        utterance.rate = 0.35 // Slow and calm
        utterance.pitchMultiplier = 0.9 // Grounded and deep
        utterance.volume = 1.0
        
        // Select a preferred natural voice if available
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
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
