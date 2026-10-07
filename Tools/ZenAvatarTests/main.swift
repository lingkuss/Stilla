import Foundation

func near(_ actual: Float, _ expected: Float) { precondition(abs(actual - expected) < 0.001, "\(actual) != \(expected)") }
let box = BreathingTechnique.presets.first { $0.id == "box" }!
precondition(box.phaseDurations == [4, 4, 4, 4], "Box audio must include both holds")
precondition(BreathingTechnique.defaultTechnique.phaseDurations == [4, 0, 4, 0])
for technique in BreathingTechnique.presets {
    precondition(technique.phaseDurations == [technique.inhale, technique.holdIn, technique.exhale, technique.holdOut])
}
var unsafeTiming = box
unsafeTiming.inhale = .infinity; unsafeTiming.holdIn = -1; unsafeTiming.exhale = 100000; unsafeTiming.holdOut = .nan
precondition(unsafeTiming.phaseDurations == [0, 0, 20, 0], "Invalid stored timing must not cause unbounded audio allocation")
near(ZenBreathMotion.sample(at: 0, technique: box).expansion, 0)
near(ZenBreathMotion.sample(at: 2, technique: box).expansion, 0.5)
near(ZenBreathMotion.sample(at: 4, technique: box).expansion, 1)
precondition(ZenBreathMotion.sample(at: 4, technique: box).phase == "Hold")
near(ZenBreathMotion.sample(at: 10, technique: box).expansion, 0.5)
near(ZenBreathMotion.sample(at: 12, technique: box).expansion, 0)
near(ZenBreathMotion.sample(at: 16002, technique: box).expansion, 0.5)
precondition(ZenBreathMotion.sample(at: 4, technique: .defaultTechnique).phase == "Exhale")
for technique in BreathingTechnique.presets {
    let cycle = technique.inhale + technique.holdIn + technique.exhale + technique.holdOut
    for t in stride(from: 0.0, through: cycle * 2, by: 0.05) {
        let sample = ZenBreathMotion.sample(at: t, technique: technique)
        precondition((0...1).contains(sample.expansion) && sample.duration > 0)
    }
}
var invalid = box
invalid.inhale = 0; invalid.holdIn = 0; invalid.exhale = 0; invalid.holdOut = 0
precondition(ZenBreathMotion.sample(at: 10, technique: invalid).index == -1)

var speech = ZenSpeechMotion()
precondition(!speech.isVoicing(at: 100))
speech.speak(word: "andas", at: 100)
precondition(speech.isVoicing(at: 100.1))
precondition(speech.mouthOpening(at: 100.04) > 0.5)
// An utterance can still be running during a punctuation pause: stop moving.
near(speech.mouthOpening(at: 101), 0)
precondition(!speech.isVoicing(at: 101))
speech.speak(word: "mmm", at: 102)
precondition(speech.mouthOpening(at: 102.04) < 0.04)
// Native phoneme markers override the word estimate, including lip closure.
speech.speak(phoneme: "ɑ", at: 102.05)
near(speech.mouthOpening(at: 102.06), 0.95)
speech.speak(phoneme: "p", at: 102.07)
near(speech.mouthOpening(at: 102.08), 0.03)
speech.stop()
precondition(!speech.isSpeaking && !speech.isVoicing(at: 102.09))
near(speech.mouthOpening(at: 102.09), 0)
speech.speak(word: "hej", at: 105)
precondition(speech.isSpeaking && speech.isVoicing(at: 105.1))
near(speech.mouthOpening(at: 110), 0)
// Rounded vowels change lip shape, not just the vertical opening.
speech.speak(phoneme: "u", at: 111)
precondition(speech.mouthPose(at: 111.05).rounding > 0.7)
speech.speak(phoneme: "p", at: 111.1)
near(speech.mouthPose(at: 111.11).rounding, 0)
speech.stop()
precondition(speech.mouthPose(at: 111.12) == ZenMouthPose())
// The word estimate must not snap on letter boundaries or flutter during a
// sustained vowel. Check continuity independently of the render-frame filter.
speech.speak(word: "aoem", at: 120)
for boundary in [0.065, 0.13, 0.195, 0.26] {
    let before = speech.mouthPose(at: 120 + boundary - 0.00001)
    let after = speech.mouthPose(at: 120 + boundary + 0.00001)
    precondition(abs(before.opening - after.opening) < 0.002)
    precondition(abs(before.rounding - after.rounding) < 0.002)
}
speech.speak(word: "aaaa", at: 130)
near(speech.mouthOpening(at: 130.08), speech.mouthOpening(at: 130.12))
near(speech.mouthOpening(at: 130), 0)
near(speech.mouthOpening(at: 130.27), 0)
// Recorded speech follows measured audio, gates silence, expires stale readings
// and returns to native word animation cleanly after stop.
speech.stop()
speech.speak(level: 0.75, at: 140)
near(speech.mouthOpening(at: 140.02), 0.6)
precondition(speech.isVoicing(at: 140.02))
precondition(!speech.isVoicing(at: 140.2))
speech.speak(level: 0, at: 141)
near(speech.mouthOpening(at: 141.02), 0)
precondition(!speech.isVoicing(at: 141.02))
speech.speak(level: .nan, at: 142)
near(speech.mouthOpening(at: 142.02), 0)
speech.stop()
speech.speak(word: "andas", at: 143)
precondition(speech.mouthOpening(at: 143.04) > 0.5)
print("PASS: breathing phases, speech gaps/stop/restart, phoneme priority, lip closure/rounding, continuous coarticulation and sustained vowels")

let track = GuideLipSyncTrack(version: 1, audioSHA256: "test", duration: 1.5, mouthCues: [
    .init(start: 0, end: 0.3, value: "D"), .init(start: 0.3, end: 0.42, value: "A"),
    .init(start: 0.42, end: 0.9, value: "F"), .init(start: 0.9, end: 1.1, value: "G"),
    .init(start: 1.1, end: 1.5, value: "X")])
precondition(track.isValid)
precondition(track.pose(at: 0.1).opening > 0.7)
precondition(track.pose(at: 0.34).opening < 0.001, "Bilabial consonants must seal even when audio is loud")
precondition(track.pose(at: 0.6).rounding > 0.9)
precondition(track.pose(at: 0.97).lipShape < -0.9)
precondition(track.pose(at: 1.3) == .init() && track.pose(at: .nan) == .init())
for boundary in [0.28, 0.40, 0.88, 1.08] {
    let a = track.pose(at: boundary - 0.00001), b = track.pose(at: boundary + 0.00001)
    precondition(abs(a.opening-b.opening) < 0.002 && abs(a.rounding-b.rounding) < 0.002 && abs(a.lipShape-b.lipShape) < 0.002)
}
speech.stop(); speech.speak(level: 1, at: 150); speech.speak(pose: track.pose(at: 0.34), at: 150)
near(speech.mouthOpening(at: 150.01), 0)
speech.speak(pose: track.pose(at: 0.6), at: 150.03)
precondition(speech.mouthPose(at: 150.04).rounding > 0.9)
precondition(speech.mouthPose(at: 150.3) == .init(), "Expired playback may not leave a talking face")
speech.stop(); precondition(speech.mouthPose(at: 150.04) == .init())
precondition(GuideEyeMotion.blinkClosure(age: 0) == 0)
precondition(GuideEyeMotion.blinkClosure(age: 0.08) == 1)
precondition(GuideEyeMotion.blinkClosure(age: 0.16) > 0 && GuideEyeMotion.blinkClosure(age: 0.25) == 0)
print("PASS: audio-clock visemes, consonant closure, rounding, F/V, continuous unequal cue boundaries, stale/reset poses and asymmetric blinks")
