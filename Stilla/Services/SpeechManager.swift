import Foundation
import Speech
import AVFoundation
import Observation

@MainActor
@Observable
class SpeechManager {
    static let shared = SpeechManager()

    enum SpeechError: LocalizedError {
        case speechPermissionDenied
        case microphonePermissionDenied
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .speechPermissionDenied:
                return "Speech recognition access is turned off for Vindla. Enable it in Settings to use voice input for Mimir."
            case .microphonePermissionDenied:
                return "Microphone access is turned off for Vindla. Enable it in Settings to speak with Mimir."
            case .recognizerUnavailable:
                return "Speech recognition is currently unavailable on this device."
            }
        }
    }
    
    var transcription: String = ""
    var isRecording: Bool = false
    var speechAuthorized: Bool = false
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    private var preferredSpeechLocale: Locale {
        Locale(identifier: AppLocalization.currentLocaleIdentifier)
    }
    
    func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        speechAuthorized = (speechStatus == .authorized)
        guard speechAuthorized else {
            throw SpeechError.speechPermissionDenied
        }

        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            throw SpeechError.microphonePermissionDenied
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startRecording() throws {
        guard speechAuthorized else {
            throw SpeechError.speechPermissionDenied
        }
        speechRecognizer = SFSpeechRecognizer(locale: preferredSpeechLocale)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        transcription = ""
        isRecording = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcription = result.bestTranscription.formattedString
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine?.prepare()
        try audioEngine?.start()
    }
    
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
        
        // Reset audio session to playback mode
        Task {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
}
