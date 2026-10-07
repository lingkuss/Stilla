import AVFoundation
import Combine
import Observation

@MainActor @Observable
final class CustomGuidePreviewPlayer {
    private(set) var voiceID: String?
    private(set) var isLoading = false
    private(set) var failed = false
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var download: Task<Void, Never>?
    @ObservationIgnored private var completion: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var cache: [URL: Data] = [:]
    @ObservationIgnored private var cacheOrder: [URL] = []
    @ObservationIgnored private var notifications = Set<AnyCancellable>()
    @ObservationIgnored private var ownsSession = false

    init() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .merge(with: NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if notification.name == AVAudioSession.routeChangeNotification {
                    guard (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                        == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                } else {
                    guard (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                        == AVAudioSession.InterruptionType.began.rawValue else { return }
                }
                Task { @MainActor in self?.stop() }
            }.store(in: &notifications)
    }

    func toggle(_ voice: CustomGuideVoice) {
        if voiceID == voice.id { stop(); return }
        stop()
        failed = false
        guard CustomGuideVoiceCatalog.isExistingPreviewURL(voice.previewURL) else { failed = true; return }
        voiceID = voice.id
        isLoading = true
        let id = requestID
        download = Task { [weak self] in
            do {
                let data: Data
                if let cached = self?.cache[voice.previewURL] { data = cached }
                else {
                    data = try await Self.downloadPreview(voice.previewURL)
                }
                try Task.checkCancellation()
                guard let self, requestID == id else { return }
                cache[voice.previewURL] = data
                cacheOrder.removeAll { $0 == voice.previewURL }
                cacheOrder.append(voice.previewURL)
                // Browsing a large library must not keep every audition in memory.
                while cache.values.reduce(0, { $0 + $1.count }) > 8_000_000, let oldest = cacheOrder.first {
                    cache.removeValue(forKey: oldest)
                    cacheOrder.removeFirst()
                }
                let audio = try AVAudioPlayer(data: data)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
                try AVAudioSession.sharedInstance().setActive(true)
                ownsSession = true
                audio.volume = 0.85
                guard audio.play() else { throw URLError(.cannotDecodeContentData) }
                player = audio
                isLoading = false
                completion = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(audio.duration + 0.15)) } catch { return }
                    guard let self, requestID == id else { return }
                    stop()
                }
            } catch {
                guard !Task.isCancelled, let self, requestID == id else { return }
                cache.removeValue(forKey: voice.previewURL)
                cacheOrder.removeAll { $0 == voice.previewURL }
                stop()
                failed = true
            }
        }
    }

    nonisolated private static func downloadPreview(_ url: URL) async throws -> Data {
        // Existing files only. No credentials, synthesis endpoint or fallback generation.
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength < 2_000_000 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            if data.count % 8192 == 0 { try Task.checkCancellation() }
            guard data.count < 2_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }
        return data
    }

    func stop() {
        requestID = UUID()
        download?.cancel(); download = nil
        completion?.cancel(); completion = nil
        player?.stop(); player = nil
        voiceID = nil
        isLoading = false
        if ownsSession {
            ownsSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
