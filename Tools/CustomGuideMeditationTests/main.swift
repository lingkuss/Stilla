import Foundation
import AVFoundation

enum GuideCreatorCopy { static func text(_ en: String, _ sv: String) -> String { en } }
enum Secrets { static var kaiGuideImageBackendURL: URL? { nil } }
actor AppAttestAuthManager {
    static let shared = AppAttestAuthManager()
    func authorize(_ request: inout URLRequest) async throws {}
    func invalidateCachedToken() {}
}
@main struct Checks {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        var pack = try JSONDecoder().decode(CustomGuideMeditationPack.self, from: data)
        precondition(pack.isValid)
        let guide = KaiPersonality(id: pack.guideID, name: "Moss", shortDescription: "Calm", longDescription: "Calm", traits: [], sampleLine: "Hello", promptInjection: "Calm", symbolName: "sparkles", imageName: pack.guideID, isFreeTier: true)
        precondition(pack.script(minutes: 5, personality: guide) == nil)
        for (i,cue) in pack.cues.enumerated() { pack.recordings[cue.id] = .init(duration: Double(6 + i % 5), sha256: "test") }
        for minutes in CustomGuideMeditationPack.durations {
            let script = pack.script(minutes: minutes, personality: guide)!
            let practice = pack.sessions.first { $0.minutes == minutes }!
            let total = 2 + practice.cueIDs.reduce(0.0) { $0 + pack.recordings[$1]!.duration } + script.steps.reduce(0) { $0 + $1.pauseDuration }
            precondition(abs(total - Double(minutes * 60)) < 0.000001)
            precondition(script.narrationLanguage == "sv" && script.kaiPersonalityID == guide.id)
            precondition(script.steps.allSatisfy { $0.pauseDuration >= 2 && $0.pauseDuration <= 180 })
        }
        precondition(pack.script(minutes: 5, personality: .zenMinimalist) == nil)
        precondition(pack.script(minutes: 7, personality: guide) == nil)
        pack.recordings["breath1"] = nil
        precondition(pack.script(minutes: 30, personality: guide) == nil)
        var bad = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        bad["packID"] = "../../escape"
        let badPack = try JSONDecoder().decode(CustomGuideMeditationPack.self, from: JSONSerialization.data(withJSONObject: bad))
        precondition(!badPack.isValid)
        print("PASS: six exact durations, language and guide isolation, complete recordings required, bounded pauses, path validation")
    }
}
