import SwiftUI
import LinkPresentation

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
    @State private var isSavingShare = false
    @State private var shareUploadError = false
    @State private var cachedShareImage: UIImage?
    @State private var cachedShareURL: URL?
    @State private var isGeneratingShareContent = false

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
            .navigationTitle(showingShareCard ? String(localized: "reflection.share_nav_title") : String(localized: "reflection.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .preferredColorScheme(.dark)
            .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.07).ignoresSafeArea())
            .alert(String(localized: "alerts.voice_input_unavailable"), isPresented: $showingError) {
                Button(String(localized: "reflection.i_understand")) { }
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
            .alert(String(localized: "alerts.could_not_share_session"), isPresented: $shareUploadError) {
                Button(String(localized: "ui.ok")) { }
            } message: {
                Text(String(localized: "reflection.share_upload_error"))
            }
            .onAppear {
                prefetchShareContent()
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
                    Text(String(localized: "reflection.how_are_you_now"))
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .italic()
                }
            }

            Text(String(localized: "reflection.short_reflection_hint"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var reflectionInputSection: some View {
        ZStack(alignment: .bottomTrailing) {
            TextField(String(localized: "reflection.placeholder"), text: $reflectionText, axis: .vertical)
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
                            errorMessage = String(localized: "reflection.voice_input_fallback_error")
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
                        Text(String(localized: "reflection.reminder_prompt"))
                            .font(.system(size: 14, weight: .medium))
                        Text(reminderSuggestionText)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(hue: 0.55, saturation: 0.6, brightness: 0.7)))

                if wantsReminder {
                    HStack(spacing: 8) {
                        Text(String(localized: "reflection.time_label"))
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
            if manager.currentScript != nil, !manager.isCurrentScriptSaved {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.saveCurrentScript()
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "books.vertical.fill")
                        Text(saveScriptButtonTitle)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                }
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                handleSave()
                transitionToShare()
            } label: {
                Text(String(localized: "reflection.save"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }

            Button(String(localized: "ui.skip")) {
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
                Text(String(localized: "reflection.share_title"))
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .italic()
                Text(String(localized: "reflection.share_subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    shareSession()
                } label: {
                    HStack(spacing: 8) {
                        if isGeneratingShareContent || isSavingShare {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isGeneratingShareContent || isSavingShare ? String(localized: "reflection.preparing") : String(localized: "reflection.share_action"))
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
                }
                .disabled(isGeneratingShareContent || isSavingShare)

                Button(String(localized: "reflection.not_now")) {
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
        return suggestion.isEmpty ? String(localized: "reflection.reminder_default_suggestion") : suggestion
    }

    private var activePersonaName: String {
        manager.currentScript?.resolvedKaiPersonalityName ?? manager.selectedKaiPersonality.name
    }

    private var activePersonaImageName: String? {
        manager.currentScript?.generatedPersonality?.imageName ?? manager.selectedKaiPersonality.imageName
    }

    private var fallbackScript: MeditationScript {
        MeditationScript(title: String(localized: "reflection.fallback_title"), durationMinutes: 10, steps: [])
    }

    private var saveScriptButtonTitle: String {
        if manager.currentScript?.isSleepStory == true {
            return String(localized: "reflection.save_sleep_story")
        }
        return String(localized: "reflection.save_exercise")
    }

    private var lastSessionScript: MeditationScript? {
        manager.currentScript
    }

    private func transitionToShare() {
        guard manager.currentScript != nil else {
            dismiss()
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            showingShareCard = true
        }
        
        prefetchShareContent()
    }

    private func prefetchShareContent() {
        guard let script = manager.currentScript, 
              !isGeneratingShareContent,
              cachedShareImage == nil else { return }

        isGeneratingShareContent = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)

            let personaImg = loadPersonaUIImage()
            let cardView = ShareSessionCardView(script: script, personaUIImage: personaImg)
            let renderer = ImageRenderer(content: cardView)
            renderer.scale = UIScreen.main.scale
            renderer.proposedSize = ProposedViewSize(width: 420, height: 560)
            
            if let image = renderer.uiImage {
                cachedShareImage = image
            }
            
            isGeneratingShareContent = false
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

    private func loadPersonaUIImage() -> UIImage? {
        guard let imageName = activePersonaImageName else { return nil }
        return UIImage(named: imageName)
    }

    private func shareSession() {
        if let url = cachedShareURL {
            presentShareSheet(url: url)
            return
        }
        
        guard let script = lastSessionScript else { return }
        let payload = ShareSessionPayload(script: script)
        
        isSavingShare = true
        shareUploadError = false
        
        print("MIMIR: Starting session upload...")
        
        Task {
            do {
                let id = try await uploadSessionForSharing(payload)
                print("MIMIR: Upload successful, ID: \(id)")
                await MainActor.run {
                    guard let shortURL = makeShareURL(id: id) else {
                        self.isSavingShare = false
                        self.shareUploadError = true
                        return
                    }

                    self.cachedShareURL = shortURL
                    self.isSavingShare = false
                    presentShareSheet(url: shortURL)
                }
            } catch {
                print("MIMIR: Upload failed: \(error)")
                await MainActor.run {
                    self.isSavingShare = false
                    self.shareUploadError = true
                }
            }
        }
    }

    private func uploadSessionForSharing(_ payload: ShareSessionPayload) async throws -> String {
        guard let url = Secrets.kaiShareBackendURL else {
            throw NSError(domain: "ShareError", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "reflection.missing_backend_error")])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = Secrets.kaiBackendToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "ShareError", code: 1, userInfo: nil)
        }

        struct ShareResponse: Codable { let id: String }
        let shareRes = try JSONDecoder().decode(ShareResponse.self, from: data)
        return shareRes.id
    }

    private func makeShareURL(id: String) -> URL? {
        guard let baseURL = Secrets.kaiShareWebBaseURL else { return nil }
        return baseURL
            .appendingPathComponent("share")
            .appending(queryItems: [URLQueryItem(name: "id", value: id)])
    }

    private func presentShareSheet(url: URL) {
        let provider = ShareActivityProvider(url: url, image: cachedShareImage)
        
        var items: [Any] = [provider]
        if let image = cachedShareImage {
            items.append(image)
        }
        
        shareItems = items
        showingShareSheet = true
    }
}

class ShareActivityProvider: NSObject, UIActivityItemSource {
    let url: URL
    let image: UIImage?
    let title: String

    init(url: URL, image: UIImage?, title: String = String(localized: "reflection.share_default_title")) {
        self.url = url
        self.image = image
        self.title = title
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = url
        metadata.url = url
        
        if let image = image {
            metadata.iconProvider = NSItemProvider(object: image)
            metadata.imageProvider = NSItemProvider(object: image)
        }
        
        return metadata
    }
}
