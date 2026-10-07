import Foundation
import AVFoundation

@main @MainActor struct PausePlaybackChecks {
    static func main() async throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let voice = ZenRecordedVoice()
        var completed = false
        var speakingLevel = false
        let started = ProcessInfo.processInfo.systemUptime
        precondition(voice.play(url: url, endingAfter: 0.25, metersAudio: false, volume: 0,
            onLevel: { if $0 > 0 { speakingLevel = true } }, completion: { completed = $0 }))
        for _ in 0..<60 {
            if completed { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        precondition(completed && !speakingLevel, "Finite silent media must complete without speech animation")
        precondition(ProcessInfo.processInfo.systemUptime - started < 3.1)
        var stoppedCompleted = false
        precondition(voice.play(url: url, endingAfter: 0.5, metersAudio: false, volume: 0,
            onLevel: { _ in }, completion: { _ in stoppedCompleted = true }))
        try await Task.sleep(for: .milliseconds(50))
        voice.stop()
        try await Task.sleep(for: .milliseconds(650))
        precondition(!stoppedCompleted, "Stopping a pause must cancel its continuation")
        var staleCompleted = false
        var replacementCompleted = false
        precondition(voice.play(url: url, endingAfter: 0.5, metersAudio: false, volume: 0,
            onLevel: { _ in }, completion: { _ in staleCompleted = true }))
        precondition(voice.play(url: url, endingAfter: 0.15, metersAudio: false, volume: 0,
            onLevel: { _ in }, completion: { replacementCompleted = $0 }))
        try await Task.sleep(for: .milliseconds(800))
        precondition(!staleCompleted && replacementCompleted, "Only current playback may advance the session")
        for duration in [0.0, -.infinity, .nan, 999] {
            precondition(!voice.play(url: url, endingAfter: duration, metersAudio: false, volume: 0,
                onLevel: { _ in }, completion: { _ in }))
        }
        print("PASS: finite pause completion, no speaking level, cancellation, replacement and invalid-duration rejection (macOS AVAudioPlayer)")
    }
}
