import AVFoundation
import Combine
import Observation

/// Bundled auditions, independent of meditation playback, history and credits.
enum GuideIntroductionLibrary {
    struct Clip: Decodable {
        let guideID: String
        let language: String
        let text: String
        let file: String
        let duration: TimeInterval
        var localURL: URL? = nil
        var url: URL? { localURL ?? Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "GuideIntroductions") }
    }
    private struct Manifest: Decodable { let clips: [Clip] }
    private static let clips: [Clip] = {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "GuideIntroductions"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return [] }
        return manifest.clips.filter {
            !$0.file.contains("/") && $0.duration.isFinite && $0.duration > 0 && $0.url != nil
        }
    }()
    static func clip(for guideID: String, language: String? = nil) -> Clip? {
        if let pack = CustomGuideMeditationLibrary.shared.pack(for: guideID),
           let cue = pack.cues.first(where: { $0.id == "introduction" }), let audio = pack.recordings[cue.id] {
            return Clip(guideID: guideID, language: pack.language, text: cue.text, file: "introduction.mp3",
                duration: audio.duration, localURL: CustomGuideMeditationLibrary.audioURL(pack, cueID: cue.id))
        }
        if let language { return clips.first { $0.guideID == guideID && $0.language == language } }
        // Other app languages use the English audition and its visible transcript.
        for language in AppLocalization.preferredLanguageCodes {
            if let clip = clips.first(where: { $0.guideID == guideID && $0.language == language }) { return clip }
        }
        return nil
    }
}

@MainActor @Observable
final class GuideIntroductionPlayer {
    private(set) var speech = ZenSpeechMotion()
    private(set) var isPlaying = false
    private(set) var unavailable = false
    @ObservationIgnored private let voice = ZenRecordedVoice()
    @ObservationIgnored private var interruptions = Set<AnyCancellable>()
    @ObservationIgnored private var ownsAudioSession = false

    init() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .merge(with: NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if notification.name == AVAudioSession.routeChangeNotification {
                    guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                          reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                } else {
                    guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          type == AVAudioSession.InterruptionType.began.rawValue else { return }
                }
                Task { @MainActor in self?.stop() }
            }.store(in: &interruptions)
    }

    func play(guideID: String, language: String? = nil) {
        stop()
        unavailable = false
        guard let clip = GuideIntroductionLibrary.clip(for: guideID, language: language), let url = clip.url else {
            unavailable = true; return
        }
        do {
            // Auditions respect the silent switch and mix with the user's music.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            ownsAudioSession = true
        } catch { unavailable = true; return }
        isPlaying = true
        let started = voice.play(url: url, volume: 0.85, onLevel: { [weak self] level in
            self?.speech.speak(level: level)
        }, onPose: { [weak self] pose in
            self?.speech.speak(pose: pose)
        }, completion: { [weak self] success in
            self?.stop()
            self?.unavailable = !success
        })
        if !started { stop(); unavailable = true }
    }

    func stop() {
        voice.stop()
        speech.stop()
        isPlaying = false
        if ownsAudioSession {
            ownsAudioSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
