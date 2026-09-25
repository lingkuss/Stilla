import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class GuruManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = GuruManager()

    private enum NarrationMode {
        case meditation
        case sleepStory
        case preview
        case standalone
    }

    private struct VoiceProfile {
        let rate: Float
        let pitch: Float
        let preUtteranceDelay: TimeInterval

        static func profile(for mode: NarrationMode) -> VoiceProfile {
            // Apple's neural voices retain their natural prosody closest to the
            // default rate. The longer silences in a meditation should come from
            // the script, rather than from stretching every spoken phoneme.
            let rateMultiplier: Float
            switch mode {
            case .sleepStory:
                rateMultiplier = 0.92
            case .meditation, .preview:
                rateMultiplier = 0.96
            case .standalone:
                rateMultiplier = 1.0
            }

            return VoiceProfile(
                rate: AVSpeechUtteranceDefaultSpeechRate * rateMultiplier,
                pitch: 1.0,
                preUtteranceDelay: 0.04
            )
        }
    }
    
    private let synthesizer = AVSpeechSynthesizer()
    private let recordedVoice = ZenRecordedVoice()
    private var playbackID = UUID()
    private var currentScript: MeditationScript?
    public var currentStepIndex = 0
    public var currentWordRange: NSRange?
    private(set) var avatarSpeech = ZenSpeechMotion()
    private var isPlaying = false
    private var timer: Timer?
    private var currentUtterance: AVSpeechUtterance?
    private var lastMappedSourceOffset = 0
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func play(script: MeditationScript) {
        stop()
        self.currentScript = ZenVoiceLibrary.timedScript(script)
        self.currentStepIndex = 0
        self.isPlaying = true
        
        // Wait 2 seconds before the first phrase to allow for centering
        let playbackID = self.playbackID
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackID == playbackID else { return }
                self.speakNextStep()
            }
        }
    }

    func previewVoice(identifier: String) {
        stop()
        let previewText: String
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            let langCode = Locale(identifier: voice.language).language.languageCode?.identifier.lowercased() ?? "en"
            switch langCode {
            case "es":
                previewText = "Inhala lentamente. Deja que tus hombros se relajen. No hay nada que tengas que resolver ahora mismo."
            case "sv":
                previewText = "Ta ett långsamt andetag in. Låt axlarna mjukna. Det finns ingenting du behöver lösa just nu."
            case "fr":
                previewText = "Inspirez lentement. Laissez vos épaules se relâcher. Vous n'avez rien à résoudre maintenant."
            case "nb", "no":
                previewText = "Pust rolig inn. La skuldrene mykne. Det er ingenting du trenger å løse akkurat nå."
            case "da":
                previewText = "Træk vejret langsomt ind. Lad skuldrene blive bløde. Der er ikke noget, du behøver at løse lige nu."
            default:
                previewText = "Take a slow breath in. Let your shoulders soften. There is nothing you need to solve right now."
            }
        } else {
            previewText = "Take a slow breath in. Let your shoulders soften. There is nothing you need to solve right now."
        }
        let voice = AVSpeechSynthesisVoice(identifier: identifier)
        let utterance = makeUtterance(text: previewText, voice: voice, mode: .preview)
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    func stop() {
        playbackID = UUID()
        recordedVoice.stop()
        isPlaying = false
        currentWordRange = nil
        avatarSpeech.stop()
        currentUtterance = nil
        lastMappedSourceOffset = 0
        synthesizer.stopSpeaking(at: .immediate)
        timer?.invalidate()
        timer = nil
    }

    func speak(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        let utterance = makeUtterance(text: trimmed, voice: selectedVoice(), mode: .standalone)
        currentUtterance = utterance
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
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) }
        let preferredCodes = preferredVoiceLanguages

        func voiceLanguageCode(_ voice: AVSpeechSynthesisVoice) -> String {
            Locale(identifier: voice.language).language.languageCode?.identifier.lowercased() ?? ""
        }

        func chooseBest(in voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
            voices.sorted { lhs, rhs in
                let lhsIsPersonal = lhs.voiceTraits.contains(.isPersonalVoice)
                let rhsIsPersonal = rhs.voiceTraits.contains(.isPersonalVoice)
                if lhsIsPersonal != rhsIsPersonal {
                    return !lhsIsPersonal
                }
                if lhs.quality != rhs.quality {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }.first
        }

        for code in preferredCodes {
            let localizedVoices = allVoices.filter { voiceLanguageCode($0) == code }
            if let best = chooseBest(in: localizedVoices) {
                return best
            }
        }

        return chooseBest(in: allVoices)
    }

    var availableHighQualityVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.quality != .default && !$0.voiceTraits.contains(.isNoveltyVoice) }
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
        lastMappedSourceOffset = 0
        let step = script.steps[currentStepIndex]
        MeditationManager.shared.updateLiveActivity(phrase: step.text)
        if ZenVoiceLibrary.supports(script), let clip = ZenVoiceLibrary.clip(for: step.text) {
            let playbackID = self.playbackID
            if recordedVoice.play(clip, volume: MeditationManager.shared.mimirVoiceVolume,
                onLevel: { [weak self] level in self?.avatarSpeech.speak(level: level) },
                completion: { [weak self] _ in
                    guard let self, self.playbackID == playbackID else { return }
                    self.finishStep()
                }) { return }
        }
        let mode: NarrationMode = script.isSleepStory ? .sleepStory : .meditation
        let utterance = makeUtterance(text: step.text, voice: selectedVoice(), mode: mode)
        currentUtterance = utterance
        
        synthesizer.speak(utterance)
    }

    private func finishStep() {
        avatarSpeech.stop()
        currentWordRange = nil
        currentUtterance = nil
        guard isPlaying, let script = currentScript, currentStepIndex < script.steps.count else { return }
        let pause = script.steps[currentStepIndex].pauseDuration
        let playbackID = self.playbackID
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(0.001, pause), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying, self.playbackID == playbackID else { return }
                self.currentStepIndex += 1
                self.speakNextStep()
            }
        }
    }

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        let primaryLanguage = preferredVoiceLanguages.first
        let voiceId = MeditationManager.shared.kaiVoiceIdentifier
        let savedVoice = AVSpeechSynthesisVoice(identifier: voiceId)
        let savedLanguage = savedVoice.map {
            Locale(identifier: $0.language).language.languageCode?.identifier.lowercased() ?? ""
        }

        if let savedVoice,
           !savedVoice.voiceTraits.contains(.isNoveltyVoice),
           savedLanguage == primaryLanguage,
           savedVoice.quality != .default {
            return savedVoice
        }

        if let bestVoice = findBestAvailableVoice() {
            // Upgrade an automatically selected default voice when the user has
            // since downloaded an enhanced/premium voice. Also keep narration in
            // the app's current language after a language change.
            MeditationManager.shared.kaiVoiceIdentifier = bestVoice.identifier
            return bestVoice
        }

        return savedVoice
    }

    private func makeUtterance(
        text: String,
        voice: AVSpeechSynthesisVoice?,
        mode: NarrationMode
    ) -> AVSpeechUtterance {
        let languageCode = voice.map {
            Locale(identifier: $0.language).language.languageCode?.identifier.lowercased() ?? "en"
        } ?? preferredVoiceLanguages.first ?? "en"
        let spokenText = NarrationTextFormatter.prepare(text, languageCode: languageCode)
        let profile = VoiceProfile.profile(for: mode)
        let utterance = AVSpeechUtterance(string: spokenText)
        utterance.voice = voice
        utterance.rate = profile.rate
        utterance.pitchMultiplier = profile.pitch
        utterance.volume = MeditationManager.shared.mimirVoiceVolume
        utterance.preUtteranceDelay = profile.preUtteranceDelay
        utterance.prefersAssistiveTechnologySettings = false
        return utterance
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            let spoken = utterance.speechString as NSString
            if NSMaxRange(characterRange) <= spoken.length {
                self.avatarSpeech.speak(word: spoken.substring(with: characterRange))
            }
            guard self.isPlaying, let script = self.currentScript,
                  self.currentStepIndex < script.steps.count else { return }
            let sourceText = script.steps[self.currentStepIndex].text
            self.currentWordRange = self.sourceRange(
                for: characterRange,
                spokenText: utterance.speechString,
                sourceText: sourceText
            )
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.finishStep()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.avatarSpeech.begin()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {
        guard marker.mark == .phoneme else { return }
        let phoneme = marker.phoneme
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.avatarSpeech.speak(phoneme: phoneme)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        resetAvatar(for: utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        resetAvatar(for: utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.avatarSpeech.begin()
        }
    }

    nonisolated private func resetAvatar(for utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.avatarSpeech.stop()
        }
    }

    private func sourceRange(
        for spokenRange: NSRange,
        spokenText: String,
        sourceText: String
    ) -> NSRange? {
        let spokenNSString = spokenText as NSString
        guard NSMaxRange(spokenRange) <= spokenNSString.length else { return nil }

        let token = spokenNSString.substring(with: spokenRange)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !token.isEmpty else { return nil }

        let sourceNSString = sourceText as NSString
        let searchStart = min(lastMappedSourceOffset, sourceNSString.length)
        let forwardRange = NSRange(location: searchStart, length: sourceNSString.length - searchStart)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        let match = sourceNSString.range(of: token, options: options, range: forwardRange)
        guard match.location != NSNotFound else { return nil }

        lastMappedSourceOffset = NSMaxRange(match)
        return match
    }
}

private enum NarrationTextFormatter {
    static func prepare(_ rawText: String, languageCode: String) -> String {
        var text = rawText.precomposedStringWithCanonicalMapping

        // Convert common AI/script pause annotations into punctuation the Apple
        // voices understand, instead of risking that the annotation is spoken.
        text = replacingRegex(
            #"(?i)[\[\(]\s*(?:\.{3}|…|pause|paus|silence|tystnad|silencio|silence)\s*[\]\)]"#,
            in: text,
            with: "…"
        )
        text = text.replacingOccurrences(of: "[...]", with: "…")
        text = replacingRegex(#"\.{3,}"#, in: text, with: "…")

        // Markdown is useful in generated text but creates audible artifacts.
        text = replacingRegex(#"[*_`]"#, in: text, with: "")
        text = replacingRegex(#"(?m)^\s*[-•]\s+"#, in: text, with: "")

        for (abbreviation, spokenForm) in abbreviationReplacements(for: languageCode) {
            text = text.replacingOccurrences(
                of: abbreviation,
                with: spokenForm,
                options: [.caseInsensitive]
            )
        }

        text = replacingRegex(#"\s+"#, in: text, with: " ")
        text = replacingRegex(#"\s+([,.;:!?…])"#, in: text, with: "$1")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return rawText }
        if let last = text.last, !".!?…".contains(last) {
            if ",;:".contains(last) {
                text.removeLast()
            }
            text.append(".")
        }
        return text
    }

    private static func abbreviationReplacements(for languageCode: String) -> [(String, String)] {
        switch languageCode {
        case "sv":
            return [("t.ex.", "till exempel"), ("d.v.s.", "det vill säga")]
        case "nb", "no":
            return [("f.eks.", "for eksempel"), ("dvs.", "det vil si")]
        case "da":
            return [("f.eks.", "for eksempel"), ("dvs.", "det vil sige")]
        case "es":
            return [("p. ej.", "por ejemplo")]
        case "fr":
            return [("par ex.", "par exemple")]
        default:
            return [("e.g.", "for example"), ("i.e.", "that is")]
        }
    }

    private static func replacingRegex(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
