import Foundation
import AVFoundation
import CryptoKit

struct CustomGuideMeditationPack: Codable, Sendable {
    struct Cue: Codable, Sendable { let id: String; let text: String; let pauseWeight: Double }
    struct Practice: Codable, Sendable { let id: String; let minutes: Int; let title: String; let summary: String; let cueIDs: [String] }
    struct Recording: Codable, Sendable { let duration: Double; let sha256: String }
    let version: Int
    let packID: String
    let guideID: String
    let language: String
    let voiceID: String
    let cues: [Cue]
    let sessions: [Practice]
    let speechConcurrency: Int
    var recordings: [String: Recording] = [:]
    private enum CodingKeys: String, CodingKey { case version, packID, guideID, language, voiceID, cues, sessions, speechConcurrency, recordings }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        packID = try c.decode(String.self, forKey: .packID)
        guideID = try c.decode(String.self, forKey: .guideID)
        language = try c.decode(String.self, forKey: .language)
        voiceID = try c.decode(String.self, forKey: .voiceID)
        cues = try c.decode([Cue].self, forKey: .cues)
        sessions = try c.decode([Practice].self, forKey: .sessions)
        speechConcurrency = min(29, max(1, try c.decodeIfPresent(Int.self, forKey: .speechConcurrency) ?? 2))
        recordings = try c.decodeIfPresent([String: Recording].self, forKey: .recordings) ?? [:]
    }
    static let durations = [5,10,15,20,25,30]
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    var isValid: Bool {
        guard version == 1, CustomGuideCatalog.isCustomID(guideID),
              packID.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              CustomGuideLanguage(rawValue: language) != nil, !voiceID.isEmpty,
              cues.count == 29, Set(cues.map(\.id)).count == cues.count,
              cues.contains(where: { $0.id == "introduction" }),
              cues.allSatisfy({ $0.id.range(of: "^[a-z]+[1-4]?$", options: .regularExpression) != nil && !$0.text.isEmpty && $0.text.count <= 320 && $0.pauseWeight.isFinite && $0.pauseWeight > 0 }),
              sessions.count == 6, Set(sessions.map(\.minutes)) == Set(Self.durations),
              Set(sessions.map(\.id)).count == 6 else { return false }
        return sessions.allSatisfy { practice in
            practice.id == "\(packID)-\(practice.minutes)" && !practice.title.isEmpty &&
            practice.cueIDs.count == 8 + (practice.minutes / 5 - 1) * 4 &&
            Set(practice.cueIDs).count == practice.cueIDs.count && !practice.cueIDs.contains("introduction") &&
            Set(practice.cueIDs).isSubset(of: Set(cues.map(\.id)))
        }
    }
    func script(minutes: Int, personality: KaiPersonality) -> MeditationScript? {
        guard isValid, personality.id == guideID,
              let practice = sessions.first(where: { $0.minutes == minutes }) else { return nil }
        let selected = practice.cueIDs.compactMap { id in cues.first { $0.id == id } }
        let clips = practice.cueIDs.compactMap { recordings[$0] }
        guard clips.count == selected.count, clips.allSatisfy({ $0.duration.isFinite && $0.duration > 0 && $0.duration <= 90 }) else { return nil }
        let silence = Double(minutes * 60) - 2 - clips.reduce(0) { $0 + $1.duration }
        guard silence >= Double(selected.count * 2) else { return nil }
        let weight = selected.reduce(0) { $0 + $1.pauseWeight }
        let steps = selected.map { ScriptStep(text: $0.text, pauseDuration: 2 + (silence - Double(selected.count * 2)) * $0.pauseWeight / weight) }
        guard steps.allSatisfy({ $0.pauseDuration <= 180 }) else { return nil }
        return MeditationScript(title: practice.title, durationMinutes: minutes, steps: steps,
            tags: [language, "Custom Guide"], kaiPersonalityID: guideID, kaiPersonalityName: personality.localizedName,
            guidanceHeader: practice.title, guidanceBody: practice.summary,
            narrationLanguage: language, localNarrationID: practice.id)
    }
}

/// Completed packs are immutable; only a fully validated pack is made available for playback.
final class CustomGuideMeditationLibrary: @unchecked Sendable {
    static let shared = CustomGuideMeditationLibrary()
    private let lock = NSLock()
    private var cached: [String: CustomGuideMeditationPack] = [:]
    static var root: URL { URL.applicationSupportDirectory.appending(path: "GuideCreator/Audio") }
    static func directory(guideID: String, packID: String) -> URL {
        root.appendingPathComponent(guideID).appendingPathComponent(packID)
    }
    static func audioURL(_ pack: CustomGuideMeditationPack, cueID: String) -> URL {
        directory(guideID: pack.guideID, packID: pack.packID).appendingPathComponent(cueID + ".mp3")
    }
    func pack(for guideID: String) -> CustomGuideMeditationPack? {
        guard CustomGuideCatalog.isCustomID(guideID) else { return nil }
        return lock.withLock {
            if let result = cached[guideID] { return result }
            let url = Self.root.appendingPathComponent(guideID).appendingPathComponent("complete.json")
            guard let data = try? Data(contentsOf: url),
                  let pack = try? JSONDecoder().decode(CustomGuideMeditationPack.self, from: data), pack.guideID == guideID,
                  pack.isValid, pack.cues.allSatisfy({ cue in
                      guard let recording = pack.recordings[cue.id], recording.duration.isFinite, recording.duration > 0,
                            let audio = try? Data(contentsOf: Self.audioURL(pack, cueID: cue.id)) else { return false }
                      return CustomGuideMeditationPack.hash(audio) == recording.sha256
                  }) else { return nil }
            cached[guideID] = pack
            return pack
        }
    }
    static func publish(_ pack: CustomGuideMeditationPack, personality: KaiPersonality) throws {
        guard pack.cues.allSatisfy({ pack.recordings[$0.id] != nil }),
              CustomGuideMeditationPack.durations.allSatisfy({ pack.script(minutes: $0, personality: personality) != nil }) else { throw CustomGuideAudioError.invalidAudio }
        let file = root.appendingPathComponent(pack.guideID).appendingPathComponent("complete.json")
        try JSONEncoder().encode(pack).write(to: file, options: .atomic)
    }
    func script(minutes: Int, personality: KaiPersonality) -> MeditationScript? {
        pack(for: personality.id)?.script(minutes: minutes, personality: personality)
    }
    func recording(for script: MeditationScript, step: Int) -> (url: URL, duration: Double)? {
        guard let id = script.kaiPersonalityID, let pack = pack(for: id), pack.language == script.narrationLanguage,
              let practice = pack.sessions.first(where: { $0.id == script.localNarrationID && $0.minutes == script.durationMinutes }),
              practice.cueIDs.indices.contains(step), practice.cueIDs.count == script.steps.count,
              practice.cueIDs.compactMap({ id in pack.cues.first { $0.id == id }?.text }) == script.steps.map(\.text),
              let clip = pack.recordings[practice.cueIDs[step]] else { return nil }
        return (Self.audioURL(pack, cueID: practice.cueIDs[step]), clip.duration)
    }
    func hasCompleteRecording(_ script: MeditationScript) -> Bool {
        !script.isSleepStory && !script.steps.isEmpty && script.steps.indices.allSatisfy { recording(for: script, step: $0) != nil }
    }
}

enum CustomGuideAudioError: Error {
    case unavailable, permissions, credits, paidVoice, voice, expired, invalidAudio, rateLimited, authentication
    var message: String {
        switch self {
        case .unavailable: return GuideCreatorCopy.text("Voice creation isn't connected yet. Your choices are saved.", "Röstskapandet är inte anslutet ännu. Dina val är sparade.")
        case .permissions: return GuideCreatorCopy.text("The voice connection needs permission to create speech. Your choices are saved.", "Röstanslutningen behöver behörighet att skapa tal. Dina val är sparade.")
        case .credits: return GuideCreatorCopy.text("ElevenLabs needs available credits or a plan that supports this voice. Completed work is saved.", "ElevenLabs behöver tillgängliga krediter eller en plan som stöder rösten. Det som är klart är sparat.")
        case .paidVoice: return GuideCreatorCopy.text("This library voice requires a paid ElevenLabs plan. Choose a standard voice to test with free credits.", "Den här biblioteksrösten kräver en betald ElevenLabs-plan. Välj en standardröst för att testa med gratiskrediter.")
        case .voice: return GuideCreatorCopy.text("This voice isn't available for generation. Please choose another voice.", "Den här rösten är inte tillgänglig för generering. Välj en annan röst.")
        case .expired: return GuideCreatorCopy.text("This unfinished generation has expired. Change the guide's name to begin a new version.", "Det här påbörjade skapandet har löpt ut. Ändra guidens namn för att börja en ny version.")
        case .invalidAudio: return GuideCreatorCopy.text("A recording couldn't be verified. Completed parts are saved; try again.", "En inspelning kunde inte verifieras. Färdiga delar är sparade. Försök igen.")
        case .rateLimited: return GuideCreatorCopy.text("Voice creation is busy or has reached its limit. Please try again later.", "Röstskapandet är upptaget eller har nått sin gräns. Försök igen senare.")
        case .authentication: return GuideCreatorCopy.text("This device couldn't be verified. Please try again.", "Enheten kunde inte verifieras. Försök igen.")
        }
    }
}

@MainActor enum CustomGuideMeditationGenerator {
    private struct Brief: Codable {
        let guideID: String; let name: String; let language: String; let voiceID: String; let personality: String; let appearance: String
    }
    private struct Pending: Codable { let fingerprint: String; var pack: CustomGuideMeditationPack }
    private struct SpeechRequest: Encodable { let packID: String; let cueID: String }
    private struct Failure: Decodable { let code: String? }
    private struct CompletedRecording: Sendable {
        let cueID: String
        let recording: CustomGuideMeditationPack.Recording
    }
    static func generate(draft: CustomGuideDraft, progress: @escaping (String) -> Void) async throws -> CustomGuideMeditationPack {
        guard let voiceID = draft.voiceID else { throw CustomGuideAudioError.voice }
        let brief = Brief(guideID: draft.guideID, name: draft.name, language: draft.language.rawValue, voiceID: voiceID, personality: draft.personality, appearance: draft.imageDescription)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let body = try encoder.encode(brief), fingerprint = CustomGuideMeditationPack.hash(body)
        let root = CustomGuideMeditationLibrary.root.appendingPathComponent(draft.guideID)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let pendingURL = root.appendingPathComponent("pending.json")
        var pack: CustomGuideMeditationPack
        if let data = try? Data(contentsOf: pendingURL), let saved = try? JSONDecoder().decode(Pending.self, from: data),
           saved.fingerprint == fingerprint, saved.pack.isValid { pack = saved.pack }
        else {
            progress(GuideCreatorCopy.text("Writing six meditations…", "Skriver sex meditationer…"))
            pack = try JSONDecoder().decode(CustomGuideMeditationPack.self, from: await request(path: "meditations", body: body))
            guard pack.isValid, pack.guideID == draft.guideID, pack.voiceID == voiceID, pack.language == draft.language.rawValue else { throw CustomGuideAudioError.invalidAudio }
            try encoder.encode(Pending(fingerprint: fingerprint, pack: pack)).write(to: pendingURL, options: .atomic)
        }
        let directory = CustomGuideMeditationLibrary.directory(guideID: pack.guideID, packID: pack.packID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var remaining: [CustomGuideMeditationPack.Cue] = []
        for cue in pack.cues {
            let url = CustomGuideMeditationLibrary.audioURL(pack, cueID: cue.id)
            if let recording = pack.recordings[cue.id], let data = try? Data(contentsOf: url), CustomGuideMeditationPack.hash(data) == recording.sha256 { continue }
            pack.recordings[cue.id] = nil
            remaining.append(cue)
        }
        let packID = pack.packID, total = pack.cues.count
        var completed = total - remaining.count
        func reportProgress() {
            progress(GuideCreatorCopy.text("Recording your voice: \(completed) of \(total) complete", "Spelar in din röst: \(completed) av \(total) klara"))
        }
        reportProgress()
        let recordCue: @Sendable (CustomGuideMeditationPack.Cue) async -> Result<CompletedRecording, Error> = { cue in
            do {
                return .success(try await record(cueID: cue.id, packID: packID, directory: directory))
            } catch { return .failure(error) }
        }
        try await withThrowingTaskGroup(of: Result<CompletedRecording, Error>.self) { group in
            var next = remaining.makeIterator()
            // Fill every available provider slot, then immediately replace each finished job.
            for _ in 0..<min(pack.speechConcurrency, remaining.count) {
                if let cue = next.next() { group.addTask { await recordCue(cue) } }
            }
            var firstError: Error?
            for try await result in group {
                switch result {
                case .success(let clip):
                    pack.recordings[clip.cueID] = clip.recording
                    completed += 1
                    do {
                        // Only this parent task writes the shared checkpoint.
                        try encoder.encode(Pending(fingerprint: fingerprint, pack: pack)).write(to: pendingURL, options: .atomic)
                    } catch { if firstError == nil { firstError = error } }
                    reportProgress()
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
                if Task.isCancelled { group.cancelAll() }
                // Keep completed in-flight work on failure, but stop starting new paid requests.
                if firstError == nil, !Task.isCancelled, let cue = next.next() {
                    group.addTask { await recordCue(cue) }
                }
            }
            try Task.checkCancellation()
            if let firstError { throw firstError }
        }
        return pack
    }
    private static func record(cueID: String, packID: String, directory: URL) async throws -> CompletedRecording {
        try Task.checkCancellation()
        let body = try JSONEncoder().encode(SpeechRequest(packID: packID, cueID: cueID))
        let data = try await request(path: "speech", body: body)
        let duration = try await Task.detached(priority: .userInitiated) {
            guard data.count <= 2_000_000, let player = try? AVAudioPlayer(data: data), player.duration.isFinite,
                  player.duration > 0.2, player.duration <= 90 else { throw CustomGuideAudioError.invalidAudio }
            return player.duration
        }.value
        try data.write(to: directory.appendingPathComponent(cueID + ".mp3"), options: .atomic)
        return CompletedRecording(cueID: cueID, recording: .init(duration: duration, sha256: CustomGuideMeditationPack.hash(data)))
    }
    private static func request(path: String, body: Data) async throws -> Data {
        guard let base = Secrets.kaiGuideImageBackendURL, base.scheme == "https" else { throw CustomGuideAudioError.unavailable }
        let url = base.deletingLastPathComponent().appendingPathComponent(path)
        var request = URLRequest(url: url, timeoutInterval: 180)
        request.httpMethod = "POST"; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for attempt in 0...1 {
            do { try await AppAttestAuthManager.shared.authorize(&request) }
            catch { throw CustomGuideAudioError.authentication }
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw CustomGuideAudioError.unavailable }
            if http.statusCode == 401, attempt == 0 { await AppAttestAuthManager.shared.invalidateCachedToken(); continue }
            guard http.statusCode == 200 else {
                let code = (try? JSONDecoder().decode(Failure.self, from: data))?.code
                switch code {
                case "voice_permissions": throw CustomGuideAudioError.permissions
                case "voice_plan_required": throw CustomGuideAudioError.paidVoice
                case "voice_credits": throw CustomGuideAudioError.credits
                case "voice_unavailable": throw CustomGuideAudioError.voice
                case "plan_expired": throw CustomGuideAudioError.expired
                case "invalid_audio", "invalid_plan": throw CustomGuideAudioError.invalidAudio
                case "rate_limited", "generation_in_progress": throw CustomGuideAudioError.rateLimited
                default: throw CustomGuideAudioError.unavailable
                }
            }
            guard data.count <= 2_000_000, http.mimeType == (path == "speech" ? "audio/mpeg" : "application/json") else { throw CustomGuideAudioError.invalidAudio }
            return data
        }
        throw CustomGuideAudioError.authentication
    }
}
