import Foundation

struct ShareSessionPayload: Codable {
    let version: Int
    let script: SharedMeditationScript

    init(version: Int = 1, script: MeditationScript) {
        self.version = version
        self.script = SharedMeditationScript(from: script)
    }
    
    enum CodingKeys: String, CodingKey {
        case version = "v"
        case script = "s"
    }
}

// Aggressively shortened models for sharing only
struct SharedScriptStep: Codable {
    let t: String // text
    let p: Double // pauseDuration
    
    init(from step: ScriptStep) {
        self.t = step.text
        self.p = step.pauseDuration
    }
}

struct SharedMeditationScript: Codable {
    let t: String // title
    let d: Int    // duration
    let s: [SharedScriptStep] // steps
    let kid: String? // kaiPersonalityID
    let kn: String?  // kaiPersonalityName
    
    init(from script: MeditationScript) {
        self.t = script.title
        self.d = script.durationMinutes
        self.s = script.steps.map { SharedScriptStep(from: $0) }
        self.kid = script.kaiPersonalityID
        self.kn = script.kaiPersonalityName
    }
    
    func toFullScript() -> MeditationScript {
        return MeditationScript(
            title: t,
            durationMinutes: d,
            steps: s.map { ScriptStep(text: $0.t, pauseDuration: $0.p) },
            kaiPersonalityID: kid,
            kaiPersonalityName: kn
        )
    }
}
