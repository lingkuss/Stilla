import Foundation
import AVFoundation
import CryptoKit

@main @MainActor struct LipSyncChecks {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var checked = 0
        for (folder, manifest) in [("GuideIntroductions", "manifest.json"), ("GuideMeditations", "audio.json")] {
            let pack = root.appendingPathComponent("Stilla/Resources/\(folder)")
            let data = try Data(contentsOf: pack.appendingPathComponent(manifest))
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let clips = json["clips"] as! [[String: Any]]
            for clip in clips where ["serene_guide", "shadow_guide"].contains(clip["guideID"] as! String) {
                let url = pack.appendingPathComponent(clip["file"] as! String)
                let sidecar = url.deletingPathExtension().appendingPathExtension("lipsync.json")
                let track = try JSONDecoder().decode(GuideLipSyncTrack.self, from: Data(contentsOf: sidecar))
                let audio = try AVAudioPlayer(contentsOf: url)
                precondition(track.isValid && abs(track.duration-audio.duration) < 0.05, url.lastPathComponent)
                let hash = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
                precondition(hash == track.audioSHA256, "Stale visemes for \(url.lastPathComponent)")
                for t in stride(from: 0.0, through: track.duration + 0.1, by: 1.0/60) {
                    let pose = track.pose(at: t)
                    precondition((0...1).contains(pose.opening) && (0...1).contains(pose.rounding) && (-1...1).contains(pose.lipShape))
                }
                checked += 1
            }
        }
        precondition(checked == 66)

        // Real audio clock, including a seek near the end, then stop and a stale
        // sidecar. This exercises the production player, not a duplicate timer.
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let source = root.appendingPathComponent("Stilla/Resources/GuideIntroductions/serene_guide-en.m4a")
        let url = temporary.appendingPathComponent("voice.m4a")
        try FileManager.default.copyItem(at: source, to: url)
        let audio = try AVAudioPlayer(contentsOf: url), voice = ZenRecordedVoice()
        let hash = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        let sidecar = url.deletingPathExtension().appendingPathExtension("lipsync.json")
        func writeTrack(hash: String) throws {
            let json: [String: Any] = ["version": 1, "audioSHA256": hash, "duration": audio.duration,
                "mouthCues": [["start": 0, "end": audio.duration-1, "value": "X"],
                              ["start": audio.duration-1, "end": audio.duration, "value": "D"]]]
            try JSONSerialization.data(withJSONObject: json).write(to: sidecar)
        }
        try writeTrack(hash: hash)
        var poses = [ZenMouthPose](), completed = false, cleared = false
        precondition(voice.play(url: url, endingAfter: 0.4, volume: 0, onLevel: { _ in },
            onPose: { if let pose = $0 { poses.append(pose) } else { cleared = true } }, completion: { completed = $0 }))
        for _ in 0..<40 { if completed { break }; try await Task.sleep(for: .milliseconds(50)) }
        guard completed && cleared && poses.count > 2 && poses.contains(where: { $0.opening > 0.8 }) else {
            throw NSError(domain: "LipSync", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Seek check: completed=\(completed), cleared=\(cleared), openings=\(poses.map(\.opening))"])
        }
        poses = []; cleared = false; completed = false
        precondition(voice.play(url: url, endingAfter: 0.8, volume: 0, onLevel: { _ in },
            onPose: { if let pose = $0 { poses.append(pose) } else { cleared = true } }, completion: { completed = $0 }))
        try await Task.sleep(for: .milliseconds(150)); voice.stop()
        let count = poses.count
        try await Task.sleep(for: .milliseconds(300))
        precondition(cleared && poses.count == count && !completed, "Cancelled callbacks must not animate or complete")
        try writeTrack(hash: "outdated-audio")
        poses = []; cleared = false
        precondition(voice.play(url: url, endingAfter: 0.3, volume: 0, onLevel: { _ in },
            onPose: { if let pose = $0 { poses.append(pose) } else { cleared = true } }, completion: { _ in }))
        try await Task.sleep(for: .milliseconds(600))
        precondition(poses.isEmpty && cleared, "Changed recordings must fall back, never use stale mouth shapes")
        print("PASS: \(checked) audio-bound tracks, 60 Hz pose bounds; AVAudioPlayer seek, completion, stop and stale-hash fallback")
    }
}
