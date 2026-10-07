import AVFoundation
import CryptoKit

/// Plays local files only. There is no generation service or network fallback.
@MainActor
final class ZenRecordedVoice: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var meter: Timer?
    private var onLevel: ((Float) -> Void)?
    private var onPose: ((ZenMouthPose?) -> Void)?
    private var completion: ((Bool) -> Void)?
    private var playbackID = UUID()

    @discardableResult
    func play(_ clip: ZenVoiceLibrary.Clip, volume: Float,
              onLevel: @escaping (Float) -> Void, completion: @escaping (Bool) -> Void) -> Bool {
        guard let url = clip.url else { stop(); return false }
        return play(url: url, volume: volume, onLevel: onLevel, completion: completion)
    }

    @discardableResult
    func play(url: URL, endingAfter duration: TimeInterval? = nil, metersAudio: Bool = true, volume: Float,
              onLevel: @escaping (Float) -> Void, onPose: ((ZenMouthPose?) -> Void)? = nil,
              completion: @escaping (Bool) -> Void) -> Bool {
        stop()
        guard let audio = try? AVAudioPlayer(contentsOf: url) else { return false }
        if let duration {
            guard duration.isFinite, duration > 0, duration <= audio.duration else { return false }
            audio.currentTime = audio.duration - duration
        }
        audio.delegate = self
        audio.volume = volume
        audio.isMeteringEnabled = metersAudio
        audio.prepareToPlay()
        self.player = audio
        self.onLevel = onLevel
        self.onPose = onPose
        self.completion = completion
        let track = metersAudio && onPose != nil ? Self.lipSync(for: url, duration: audio.duration) : nil
        guard audio.play() else { stop(); return false }
        #if DEBUG
        print("Local guide voice: \(url.lastPathComponent), face: \(track == nil ? "meter" : "timed visemes")")
        #endif
        guard metersAudio else { return true }
        let playbackID = self.playbackID
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackID == playbackID, let audio = self.player else { return }
                audio.updateMeters()
                // Gate background noise and keep the jaw at rest in real silence.
                let db = audio.averagePower(forChannel: 0)
                let level: Float = db < -42 ? 0 : min(1, pow(10, (db + 8) / 30))
                self.onLevel?(level)
                self.onPose?(track?.pose(at: audio.currentTime))
            }
        }
        meter = timer
        RunLoop.main.add(timer, forMode: .common)
        return true
    }

    func stop() {
        playbackID = UUID()
        meter?.invalidate()
        meter = nil
        player?.stop()
        player = nil
        onLevel?(0)
        onLevel = nil
        onPose?(nil)
        onPose = nil
        completion = nil
    }

    private static func lipSync(for url: URL, duration: TimeInterval) -> GuideLipSyncTrack? {
        let sidecar = url.deletingPathExtension().appendingPathExtension("lipsync.json")
        guard url.isFileURL, let data = try? Data(contentsOf: sidecar), data.count < 2_000_000,
              let track = try? JSONDecoder().decode(GuideLipSyncTrack.self, from: data),
              track.isValid, abs(track.duration - duration) < 0.05,
              let audio = try? Data(contentsOf: url),
              SHA256.hash(data: audio).map({ String(format: "%02x", $0) }).joined() == track.audioSHA256 else { return nil }
        return track
    }

    private func finish(_ audio: AVAudioPlayer, successfully: Bool) {
        guard player === audio else { return }
        let callback = completion
        stop()
        callback?(successfully)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finish(player, successfully: flag) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in self?.finish(player, successfully: false) }
    }
}
