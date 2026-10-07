import SwiftUI

/// A quiet, separate entry point for choosing a session with the Zen guide.
struct ZenSessionView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var voice = ZenAvatarVoice()
    @State private var speech = SpeechManager()
    @State private var input = ""
    @State private var request = ZenSessionRequest.parse("")
    @State private var preparedScript: MeditationScript?
    @State private var isPreparing = false
    @State private var isRequestingMicrophone = false
    @State private var isVisible = false
    @State private var generation: Task<Void, Never>?
    @State private var recording: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var showsPaywall = false
    @FocusState private var inputFocused: Bool

    private let ink = Color(red: 0.16, green: 0.20, blue: 0.19)
    private let paper = Color(red: 0.94, green: 0.935, blue: 0.90)
    private var typeTitle: String {
        String(localized: request.kind == .sleepStory ? "zen.session.story" : "zen.session.meditation")
    }
    private var suggestion: String {
        if preparedScript != nil {
            return String(localized: "zen.session.ready")
        }
        return String(localized: "zen.session.suggestion")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 4) {
                        Text(KaiPersonality.zenMinimalist.localizedName)
                            .font(.system(.title3, design: .serif))
                        Text("zen.session.subtitle")
                            .font(.caption).foregroundStyle(ink.opacity(0.60))
                    }

                    ZenAvatarView(speech: voice.avatarSpeech)
                        .frame(height: 290)
                        .background {
                            Ellipse().fill(.white.opacity(0.7)).blur(radius: 35)
                                .padding(.horizontal, 35).padding(.vertical, 20)
                        }

                    VStack(spacing: 12) {
                        if ZenVoiceLibrary.clip(for: suggestion) != nil {
                            Label("zen.voice.local", systemImage: "waveform")
                                .font(.caption).foregroundStyle(ink.opacity(0.6))
                        }
                        HStack(alignment: .top, spacing: 10) {
                            Text(suggestion)
                                .font(.system(.title3, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                if voice.isPlaying { voice.stop() }
                                else { speech.stopRecording(); voice.play(suggestion) }
                            } label: {
                                Image(systemName: voice.isPlaying ? "stop.circle" : "speaker.wave.2")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(String(localized: voice.isPlaying ? "zen.avatar.stop" : "zen.avatar.listen"))
                            .accessibilityIdentifier("zenSession.listen")
                        }
                        HStack {
                            Label(typeTitle, systemImage: request.kind == .sleepStory ? "moon" : "wind")
                            Spacer()
                            Text("\(request.minutes) min").monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.70))
                        if request.durationWasClamped {
                            Text("zen.session.duration_limit").font(.caption)
                                .foregroundStyle(ink.opacity(0.65))
                        }
                        if !request.input.isEmpty {
                            Text(request.input).font(.footnote).italic()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(ink.opacity(0.65)).lineLimit(3)
                        }
                        Button { prepare(startImmediately: true) } label: {
                            HStack(spacing: 8) {
                                if isPreparing { ProgressView().tint(paper) }
                                else { Image(systemName: "play.fill").font(.caption) }
                                Text(isPreparing ? "zen.session.preparing" : "zen.session.start")
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .foregroundStyle(paper).background(ink, in: Capsule())
                        }
                        .disabled(isPreparing || speech.isRecording || manager.state != .idle)
                        .accessibilityIdentifier("zenSession.start")
                    }
                    .padding(20)
                    .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 26))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("zen.session.input_title").font(.subheadline.weight(.medium))
                        HStack(alignment: .bottom, spacing: 4) {
                            TextField(String(localized: "zen.session.placeholder"), text: $input, axis: .vertical)
                                .lineLimit(2...5).font(.body)
                                .focused($inputFocused)
                                .accessibilityIdentifier("zenSession.input")
                                .padding(.vertical, 12).padding(.leading, 15)
                                .disabled(isPreparing || speech.isRecording)
                            Button { toggleMicrophone() } label: {
                                Image(systemName: speech.isRecording ? "stop.fill" : "mic")
                                    .frame(width: 44, height: 48)
                            }
                            .accessibilityLabel(String(localized: speech.isRecording ? "zen.session.stop_recording" : "zen.session.record"))
                            .accessibilityIdentifier("zenSession.microphone")
                            .disabled(isPreparing || isRequestingMicrophone)
                            Button { submit() } label: {
                                Image(systemName: "arrow.up")
                                    .font(.body.weight(.semibold))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(paper).background(ink, in: Circle())
                            }
                            .padding(5)
                            .accessibilityLabel(String(localized: "zen.session.create"))
                            .accessibilityIdentifier("zenSession.submit")
                            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPreparing || speech.isRecording)
                        }
                        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                        if speech.isRecording {
                            Label("zen.session.listening", systemImage: "waveform")
                                .font(.caption).accessibilityAddTraits(.updatesFrequently)
                        } else {
                            Text("zen.session.examples").font(.caption)
                                .foregroundStyle(ink.opacity(0.6))
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if KaiBrainService.usesLocalScripts {
                        Label("zen.session.local", systemImage: "iphone")
                            .font(.caption2).foregroundStyle(ink.opacity(0.55))
                            .accessibilityIdentifier("zenSession.localMode")
                    }
                    if manager.state != .idle {
                        Text("zen.avatar.session_active").font(.footnote)
                    }
                }
                .disabled(manager.state != .idle)
                .padding(.horizontal, 24).padding(.bottom, 28)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(paper.ignoresSafeArea())
            .foregroundStyle(ink).tint(ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .sheet(isPresented: $showsPaywall) { KAIPaywallView() }
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                generation?.cancel()
                recording?.cancel()
                voice.stop()
                speech.stopRecording()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    voice.stop()
                    speech.stopRecording()
                }
                // System permission dialogs temporarily make the scene inactive.
                // Let that request finish; cancel it only when actually backgrounded.
                if phase == .background { recording?.cancel() }
            }
            .onChange(of: speech.transcription) { _, value in input = value }
            .onChange(of: inputFocused) { _, focused in if focused { voice.stop() } }
            .onChange(of: manager.state) { _, state in
                if state != .idle { voice.stop(); speech.stopRecording() }
            }
        }
    }

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isPreparing else { return }
        request = ZenSessionRequest.parse(trimmed)
        preparedScript = nil
        prepare(startImmediately: false)
    }

    private func prepare(startImmediately: Bool) {
        guard !isPreparing, manager.state == .idle else { return }
        voice.stop()
        speech.stopRecording()
        inputFocused = false
        errorMessage = nil
        isPreparing = true
        generation = Task { @MainActor in
            defer { isPreparing = false }
            if !KaiBrainService.usesLocalScripts {
                await StoreKitManager.shared.updateCustomerProductStatus()
                guard !Task.isCancelled, isVisible else { return }
                guard StoreKitManager.shared.isVindlaProSubscribed else {
                    showsPaywall = true
                    return
                }
            }
            do {
                var script: MeditationScript
                if let preparedScript { script = preparedScript }
                else if request.kind == .sleepStory {
                    script = try await KaiBrainService.shared.generateSleepStory(
                        themeTitle: request.input.isEmpty ? typeTitle : request.input,
                        themeSubtitle: nil, durationMinutes: request.minutes, excluding: []).script
                } else {
                    script = try await KaiBrainService.shared.generateScript(
                        mood: request.input.isEmpty ? String(localized: "zen.session.suggestion") : request.input,
                        durationMinutes: request.minutes, personality: .zenMinimalist,
                        stillnessRatio: manager.preferredStillnessRatio)
                }
                try Task.checkCancellation()
                guard isVisible, manager.state == .idle else { return }
                script.kaiPersonalityID = KaiPersonality.zenMinimalist.id
                script.kaiPersonalityName = KaiPersonality.zenMinimalist.localizedName
                preparedScript = script
                if startImmediately {
                    manager.selectedKaiPersonalityID = KaiPersonality.zenMinimalist.id
                    manager.pendingKaiMoodSummary = request.input.isEmpty ? nil : request.input
                    manager.pendingKaiIntention = typeTitle
                    manager.currentScript = script
                    manager.isGuruEnabled = true
                    manager.start(durationMinutes: script.durationMinutes)
                    manager.shouldDismissSheets = true
                    dismiss()
                } else {
                    voice.play(String(localized: "zen.session.ready"))
                }
            } catch is CancellationError {
                // Closing the sheet must never start a late session.
            } catch {
                errorMessage = String(localized: "zen.session.error")
            }
        }
    }

    private func toggleMicrophone() {
        if speech.isRecording { speech.stopRecording(); return }
        voice.stop()
        inputFocused = false
        errorMessage = nil
        isRequestingMicrophone = true
        recording = Task { @MainActor in
            defer { isRequestingMicrophone = false }
            do {
                try await speech.requestPermissions()
                try Task.checkCancellation()
                guard isVisible, scenePhase != .background else { return }
                try speech.startRecording()
            } catch is CancellationError {
            } catch {
                errorMessage = String(localized: "zen.session.microphone_error")
            }
        }
    }
}
