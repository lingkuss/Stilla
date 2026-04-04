import SwiftUI

struct ReflectionPromptView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    let sessionID: UUID

    @State private var reflectionText: String = ""
    @State private var wantsReminder: Bool = true
    @State private var reminderTime: Date
    @State private var isListeningPulse = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingShareCard = false
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var cachedShareImage: UIImage?
    @State private var cachedShareURL: URL?

    private let speechManager = SpeechManager.shared

    init(sessionID: UUID, defaultReminderTime: Date) {
        self.sessionID = sessionID
        _reminderTime = State(initialValue: defaultReminderTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if showingShareCard {
                    shareCardPhase
                } else {
                    reflectionPhase
                }
            }
            .padding(.top, 24)
            .navigationTitle(showingShareCard ? "Share" : "Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .preferredColorScheme(.dark)
            .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.07).ignoresSafeArea())
            .alert("Voice Input Unavailable", isPresented: $showingError) {
                Button("I understand") { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: speechManager.transcription) { _, newValue in
                if !newValue.isEmpty {
                    reflectionText = newValue
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
        }
    }

    // MARK: - Reflection Phase

    private var reflectionPhase: some View {
        Group {
            headerSection
            reflectionInputSection
            reminderSection
            Spacer()
            reflectionActionSection
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                personaImage

                VStack(alignment: .leading, spacing: 6) {
                    Text(activePersonaName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("How are you now?")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .italic()
                }
            }

            Text("A short reflection helps Kai remember what matters to you.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var reflectionInputSection: some View {
        ZStack(alignment: .bottomTrailing) {
            TextField("One line is enough...", text: $reflectionText, axis: .vertical)
                .lineLimit(3...6)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            Button {
                if speechManager.isRecording {
                    speechManager.stopRecording()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    Task {
                        do {
                            try await speechManager.requestPermissions()
                            try speechManager.startRecording()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                isListeningPulse = true
                            }
                        } catch let speechError as SpeechManager.SpeechError {
                            errorMessage = speechError.localizedDescription
                            showingError = true
                        } catch {
                            errorMessage = "Voice input isn't available right now. Please type instead."
                            showingError = true
                        }
                    }
                }
            } label: {
                ZStack {
                    if speechManager.isRecording {
                        Circle()
                            .fill(Color.blue.opacity(0.18))
                            .frame(width: 48, height: 48)
                            .scaleEffect(isListeningPulse ? 1.15 : 0.9)
                            .opacity(isListeningPulse ? 0.4 : 0.7)
                    }

                    Circle()
                        .fill(speechManager.isRecording ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

                    Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .padding(.horizontal, 24)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $wantsReminder) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Should I remind you tomorrow to")
                            .font(.system(size: 14, weight: .medium))
                        Text(reminderSuggestionText)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(hue: 0.55, saturation: 0.6, brightness: 0.7)))

                if wantsReminder {
                    HStack(spacing: 8) {
                        Text("Time")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var reflectionActionSection: some View {
        VStack(spacing: 12) {
            Button {
                handleSave()
                transitionToShare()
            } label: {
                Text("Save Reflection")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }

            Button("Skip") {
                transitionToShare()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Share Phase

    private var shareCardPhase: some View {
        VStack(spacing: 24) {
            Spacer()

            // Preview of the share card
            let personaImg = loadPersonaUIImage()
            ShareSessionCardView(
                script: manager.currentScript ?? fallbackScript,
                personaUIImage: personaImg
            )
            .scaleEffect(0.75)
            .frame(height: 420)

            VStack(spacing: 16) {
                Text("Share your journey")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .italic()
                Text("Let others discover their own path with Kai.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    shareSession()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
                }

                Button("Not now") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var personaImage: some View {
        if let imageName = activePersonaImageName {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 54, height: 54)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                )
        }
    }

    private var reminderSuggestionText: String {
        let memory = manager.recentSessionMemories.first(where: { $0.id == sessionID })
        let suggestion = memory?.suggestionOptions.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return suggestion.isEmpty ? "return for a Kai session" : suggestion
    }

    private var activePersonaName: String {
        manager.currentScript?.resolvedKaiPersonalityName ?? manager.selectedKaiPersonality.name
    }

    private var activePersonaImageName: String? {
        manager.currentScript?.generatedPersonality?.imageName ?? manager.selectedKaiPersonality.imageName
    }

    private var fallbackScript: MeditationScript {
        MeditationScript(title: "Kai Journey", durationMinutes: 10, steps: [])
    }

    private func transitionToShare() {
        guard let script = manager.currentScript else {
            dismiss()
            return
        }

        // Pre-render the share image so it's ready when the user taps Share
        let personaImg = loadPersonaUIImage()
        let cardView = ShareSessionCardView(script: script, personaUIImage: personaImg)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        cachedShareImage = renderer.uiImage

        // Pre-compute the share URL
        let payload = ShareSessionPayload(script: script)
        if let encoded = ShareSessionCodec.encode(payload) {
            cachedShareURL = URL(string: "https://stilla-three.vercel.app/share?data=\(encoded)")
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            showingShareCard = true
        }
    }

    private func handleSave() {
        if !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            manager.attachReflection(reflectionText, to: sessionID)
        }

        if wantsReminder {
            Task {
                let granted = await NotificationManager.shared.requestAuthorization()
                if granted {
                    NotificationManager.shared.scheduleNextSessionReminder(
                        at: reminderDate(),
                        suggestionText: reminderSuggestionText,
                        personaName: activePersonaName
                    )
                }
            }
        }
    }

    private func reminderDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components) ?? tomorrow
    }

    /// Load the persona image as a UIImage so ImageRenderer can use it
    private func loadPersonaUIImage() -> UIImage? {
        guard let imageName = activePersonaImageName else { return nil }
        return UIImage(named: imageName)
    }

    private func shareSession() {
        var items: [Any] = []
        if let image = cachedShareImage {
            items.append(image)
        }
        if let url = cachedShareURL {
            items.append(url)
        }

        shareItems = items
        showingShareSheet = true
    }
}
