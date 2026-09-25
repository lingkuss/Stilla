import AVFoundation

/// Plays local files only. There is no generation service or network fallback.
@MainActor
final class ZenRecordedVoice: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var meter: Timer?
    private var onLevel: ((Float) -> Void)?
    private var completion: ((Bool) -> Void)?
    private var playbackID = UUID()

    @discardableResult
    func play(_ clip: ZenVoiceLibrary.Clip, volume: Float,
              onLevel: @escaping (Float) -> Void, completion: @escaping (Bool) -> Void) -> Bool {
        stop()
        guard let url = clip.url, let audio = try? AVAudioPlayer(contentsOf: url) else { return false }
        audio.delegate = self
        audio.volume = volume
        audio.isMeteringEnabled = true
        audio.prepareToPlay()
        self.player = audio
        self.onLevel = onLevel
        self.completion = completion
        guard audio.play() else { stop(); return false }
        #if DEBUG
        print("Zen local voice: \(clip.file)")
        #endif
        let playbackID = self.playbackID
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackID == playbackID, let audio = self.player else { return }
                audio.updateMeters()
                // Gate background noise and keep the jaw at rest in real silence.
                let db = audio.averagePower(forChannel: 0)
                let level: Float = db < -42 ? 0 : min(1, pow(10, (db + 8) / 30))
                self.onLevel?(level)
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
        completion = nil
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
