import SwiftUI
import UIKit
import StoreKit

struct ContentView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.requestReview) private var requestReview

    @State private var showSettings = false
    @State private var showZenSession = false
    // Navigation is intentionally ephemeral: a fresh launch always opens the world.
    @State private var showSimpleTimer = false
    @State private var showSoundLibrary = false
    @State private var showGarden = false
    @State private var showTechniques = false
    @State private var showKaiExperience = false
    @State private var showSleepStories = false
    @State private var showAddDuration = false
    @State private var customDurationText = ""
    @State private var kaiPulse = false
    @State private var currentPhase = ""
    @State private var showSavedMeditations = false
    @State private var reflectionSheetContext: ReflectionSheetContext?
    @State private var showSleepStoryCompletion = false
    @State private var showMeditationPaywall = false
    @State private var quickMoodInput = ""
    @State private var quickMoodErrorTitle = ""
    @State private var quickMoodErrorMessage = ""
    @State private var showQuickMoodError = false
    @State private var showQuickMoodSettingsPrompt = false
    @State private var storeManager = StoreKitManager.shared
    @AppStorage("zenAvatarEnabled") private var zenAvatarEnabled = true
    private let speechManager = SpeechManager.shared

    private struct ReflectionSheetContext: Identifiable {
        let id = UUID()
        let sessionID: UUID
        let defaultReminderTime: Date
    }

    private var showsMountainWorld: Bool {
        manager.activeMountainSession != nil || (manager.state == .idle && !showSimpleTimer)
    }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            if manager.hasSeenOnboarding {
                if showsMountainWorld {
                    MountainJourneyView {
                        showSimpleTimer = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } else {
                    simpleTimerContent
                }
            }
            if manager.isGeneratingGuidedSession {
                guidedSessionLoadingOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showGarden) { StillnessGardenView { showGarden = false } }
        .sheet(isPresented: $showZenSession) {
            ZenSessionView().environment(manager)
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
                .environment(manager)
        }
        .fullScreenCover(isPresented: $showSoundLibrary) {
            NavigationStack {
                SoundSelectionView(mode: .ambience)
                    .environment(manager)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "ui.done")) { showSoundLibrary = false }
                                .fontWeight(.medium)
                        }
                    }
                    .preferredColorScheme(.dark)
                    .scrollContentBackground(.hidden)
                    .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.10).ignoresSafeArea())
            }
        }
        .fullScreenCover(isPresented: $showTechniques) {
            TechniqueLibraryView()
                .environment(manager)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !manager.hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
                .environment(manager)
        }
        .sheet(isPresented: $showKaiExperience) {
            KaiExperienceView()
                .environment(manager)
        }
        .sheet(isPresented: $showSleepStories) {
            SleepStoriesExperienceView()
                .environment(manager)
        }
        .sheet(isPresented: $showSavedMeditations) {
            SavedMeditationsLibraryView()
                .environment(manager)
        }
        .sheet(isPresented: $showMeditationPaywall) {
            KAIPaywallView()
        }
        .sheet(item: $reflectionSheetContext, onDismiss: { 
            reflectionSheetContext = nil 
            manager.reset()
            requestReviewIfAppropriate()
        }) { context in
            ReflectionPromptView(
                sessionID: context.sessionID,
                defaultReminderTime: context.defaultReminderTime
            )
            .environment(manager)
        }
        .sheet(isPresented: $showSleepStoryCompletion, onDismiss: {
            manager.reset()
            requestReviewIfAppropriate()
        }) {
            SleepStoryCompletionView()
                .environment(manager)
        }
        .alert(String(localized: "alerts.custom_duration"), isPresented: $showAddDuration) {
            TextField(String(localized: "content.custom_duration_minutes_placeholder"), text: $customDurationText)
                .keyboardType(.numberPad)
            Button(String(localized: "ui.add")) {
                if let mins = Int(customDurationText), mins >= 1, mins <= 180 {
                    manager.addCustomDuration(mins)
                    manager.durationMinutes = mins
                }
                customDurationText = ""
            }
            Button(String(localized: "ui.cancel"), role: .cancel) {
                customDurationText = ""
            }
        } message: {
            Text(String(localized: "content.custom_duration_help"))
        }
        .animation(.easeInOut(duration: 0.6), value: manager.state)
        .onChange(of: manager.state) { _, newValue in
            guard newValue == .complete, manager.activeMountainSession == nil else { return }
            if manager.currentScript?.isSleepStory == true {
                showSleepStoryCompletion = true
                return
            }
            guard let sessionID = manager.lastCompletedSessionID else { return }
            reflectionSheetContext = ReflectionSheetContext(
                sessionID: sessionID,
                defaultReminderTime: manager.defaultNextSessionReminderTime()
            )
        }
        .onChange(of: manager.shouldDismissSheets) { _, newValue in
            if newValue {
                showSettings = false
                showZenSession = false
                showSoundLibrary = false
                showTechniques = false
                showKaiExperience = false
                showSleepStories = false
                showSavedMeditations = false
                showMeditationPaywall = false
                reflectionSheetContext = nil
                showSleepStoryCompletion = false
                manager.shouldDismissSheets = false
            }
        }
        .onChange(of: manager.isSiriTriggeredKai) { _, newValue in
            if newValue {
                showKaiExperience = true
            }
        }
        .onChange(of: speechManager.transcription) { _, newValue in
            guard speechManager.isRecording else { return }
            quickMoodInput = newValue
        }
        .alert(quickMoodErrorTitle, isPresented: $showQuickMoodError) {
            Button(String(localized: "kai.i_understand")) { }
        } message: {
            Text(quickMoodErrorMessage)
        }
        .alert(String(localized: "alerts.open_settings"), isPresented: $showQuickMoodSettingsPrompt) {
            Button(String(localized: "kai.open_settings")) {
                openAppSettings()
            }
            Button(String(localized: "ui.cancel"), role: .cancel) { }
        } message: {
            Text(quickMoodErrorMessage)
        }
    }

    private var simpleTimerContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if manager.state == .idle {
                    Button {
                        showSimpleTimer = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "mountain.2")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text("content.mode.world"))
                    .accessibilityIdentifier("content.openWorld")
                }
                Spacer(minLength: 0)
                Button { showGarden = true } label: {
                    Image(systemName: "camera.macro").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("garden.eyebrow"))
                .accessibilityIdentifier("garden.open")
                Button { showTechniques = true } label: {
                    Image(systemName: "wind").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("nav.techniques"))
                .accessibilityValue(manager.selectedTechnique.localizedName)
                Button { showSoundLibrary = true } label: {
                    Image(systemName: "speaker.wave.2").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("settings.ambience"))
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("nav.settings"))
            }
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .layoutPriority(1)

            timerView
            Spacer()
            VStack(spacing: 16) {
                actionButton
                if manager.state == .idle {
                    Button { showTechniques = true } label: {
                        HStack(spacing: 6) {
                            Text(techniqueTimings).font(.system(size: 11, design: .monospaced))
                            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .padding(.bottom, 16)
            .layoutPriority(1)
        }
        .preferredColorScheme(.dark)
    }

    private var latestKaiHeader: String {
        let fallback = String(localized: "reflection.fallback_title")
        let header = manager.latestSessionMemory?.proactiveHeader?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        return header.isEmpty ? fallback : header
    }

    private var latestKaiBody: String {
        let fallback = String(localized: "content.home_proactive_fallback_body")
        let body = manager.latestSessionMemory?.proactiveBody?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        return body.isEmpty ? fallback : body
    }

    private var latestSavedSessions: [MeditationScript] {
        Array(manager.savedMeditations.suffix(4).reversed())
    }

    private var homeSectionTopSpacing: CGFloat { 20 }

    private var savedLibraryGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private static let savedSessionCreatedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var guidedSessionLoadingOverlay: some View {
        ZStack {
            Color(hue: 0.72, saturation: 0.4, brightness: 0.05)
                .ignoresSafeArea()

            KaiGeneratingLoadingView(personality: manager.selectedKaiPersonality)
        }
        .allowsHitTesting(true)
    }

    private var heroHomeScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Button { showZenSession = true } label: {
                    HStack(spacing: 12) {
                        Image(KaiPersonality.zenMinimalist.imageName)
                            .resizable().scaledToFill().frame(width: 42, height: 42)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("zen.avatar.meet").font(.subheadline.weight(.medium))
                            Text("zen.session.entry").font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.9)).padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("zenSession.open")
                .padding(.horizontal, 20).padding(.top, 12)

                personalizedSessionSection
                    .padding(.horizontal, 20)
                    .padding(.top, homeSectionTopSpacing)

                sleepStoriesSection
                    .padding(.horizontal, 20)
                    .padding(.top, homeSectionTopSpacing)

                heroView
                    .padding(.top, homeSectionTopSpacing)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var personalizedSessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                eyebrow: String(localized: "content.personalized.eyebrow"),
                title: String(localized: "content.personalized.title"),
                detail: String(localized: "content.personalized.detail")
            )

            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    TextField(String(localized: "content.personalized.mood_placeholder"), text: $quickMoodInput, axis: .vertical)
                        .lineLimit(2...5)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.top, 14)
                        .padding(.bottom, 56)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )

                    if !quickMoodInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            quickMoodInput = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.35))
                                .padding(12)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer()
                            Button {
                                toggleQuickMoodRecording()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(speechManager.isRecording ? String(localized: "content.personalized.stop") : String(localized: "content.personalized.speak"))
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(speechManager.isRecording ? Color.red.opacity(0.24) : Color.white.opacity(0.12))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        startQuickMoodMeditationFromHome()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(String(localized: "content.personalized.start_now"))
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(quickMoodInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(quickMoodInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    Button {
                        showKaiExperience = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Text(String(localized: "content.personalized.more_options"))
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.indigo.opacity(0.34),
                                Color.blue.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                    )
            )
        }
    }

    private var sleepStoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                eyebrow: String(localized: "content.sleep.eyebrow"),
                title: String(localized: "content.sleep.title"),
                detail: String(localized: "content.sleep.detail")
            )

            Button {
                showSleepStories = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "content.sleep.card_title"))
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.97))

                    Text(String(localized: "content.sleep.card_detail"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(String(localized: "content.sleep.open_cta"))
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, minHeight: 182, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.black.opacity(0.16))
                        .overlay(
                            Image("sleep_story_moon")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .overlay(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.02, green: 0.05, blue: 0.13).opacity(0.82),
                                            Color(red: 0.03, green: 0.07, blue: 0.16).opacity(0.58),
                                            Color.black.opacity(0.42)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.white.opacity(0.42))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(2)
        }
    }

    private func exploreCard(
        eyebrow: String,
        title: String,
        detail: String,
        systemImage: String,
        imageName: String? = nil,
        accent: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        let minHeight: CGFloat = imageName == nil ? 188 : 232

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                if let imageName {
                    GuideArtwork.image(named: imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.02),
                                    Color.black.opacity(0.18),
                                    Color.black.opacity(0.44)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(eyebrow)
                            .font(.system(size: 9, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.white.opacity(0.45))

                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if imageName == nil {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                }

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text(String(localized: "ui.open"))
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.78))
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(accent.opacity(0.95))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Redesign Home Views

    private var heroView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    eyebrow: String(localized: "content.saved_library.eyebrow"),
                    title: String(localized: "content.saved_library.title"),
                    detail: String(localized: "content.saved_library.detail")
                )

                VStack(spacing: 8) {
                    if latestSavedSessions.isEmpty {
                        Text(String(localized: "content.saved_library.empty"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        LazyVGrid(columns: savedLibraryGridColumns, spacing: 12) {
                            ForEach(latestSavedSessions) { script in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(script.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.92))
                                            .lineLimit(2)

                                        Spacer(minLength: 4)

                                        Button {
                                            startSavedScriptFromHome(script)
                                        } label: {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(String(localized: "content.saved_library.play"))
                                    }

                                    Text(String(format: String(localized: "content.saved_library.duration_format"), script.durationMinutes))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.78))

                                    Text(
                                        String(
                                            format: String(localized: "content.saved_library.created_prefix"),
                                            Self.savedSessionCreatedDateFormatter.string(from: script.createdAt)
                                        )
                                    )
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.56))
                                    .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                    }
                }

                Button {
                    showSavedMeditations = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Text(String(localized: "content.saved_library.see_more"))
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 188, height: 188)
                    .overlay(
                        Circle()
                            .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )

                GuideArtwork.image(named: manager.selectedKaiPersonality.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 164, height: 164)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .scaleEffect(kaiPulse ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: kaiPulse)

            VStack(spacing: 8) {
                Text(latestKaiHeader)
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 32)

                Text("“\(latestKaiBody)”")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .italic()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .lineSpacing(4)

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 20, height: 1)
                    Text(String(localized: "content.mimir_label"))
                        .font(.system(size: 10, weight: .bold))
                        .kerning(3)
                        .foregroundStyle(.white.opacity(0.5))
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 20, height: 1)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .onAppear {
            kaiPulse = true
        }
    }

    private var showsActiveZenAvatar: Bool {
        zenAvatarEnabled && manager.state != .idle && manager.isGuruEnabled
            && manager.currentScript != nil
            && (manager.currentScript?.generatedPersonality ?? manager.selectedKaiPersonality).id == KaiPersonality.zenMinimalist.id
    }

    @ViewBuilder
    private var timerView: some View {
        if showsActiveZenAvatar {
            VStack(spacing: 8) {
                Spacer(minLength: 12)
                ZenAvatarView(
                    speech: GuruManager.shared.avatarSpeech,
                    technique: manager.state == .meditating && manager.currentScript?.isSleepStory != true ? manager.selectedTechnique : nil,
                    onPhaseChange: { phase, duration in
                        currentPhase = phase
                        manager.playBreathingCue(phase: phase, duration: duration)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("zenSession.activeAvatar")
                Text(timerText)
                    .font(.system(.title3, design: .rounded).weight(.light))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.65))
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("zenSession.timer")
                    .padding(.bottom, 28)
            }
        } else {
            classicTimerView
        }
    }

    private var classicTimerView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Status label
            statusLabel
                .padding(.top, 30)
                .padding(.bottom, 12)

            // Breathing circle
            BreathingCircleView(
                isActive: manager.state == .meditating,
                progress: manager.progress,
                technique: manager.selectedTechnique,
                imageName: manager.activeKaiPersonaImageName,
                showsZenAvatar: manager.state != .idle
                    && manager.isGuruEnabled
                    && manager.currentScript != nil
                    && manager.currentScript?.isSleepStory != true
                    && (manager.currentScript?.generatedPersonality ?? manager.selectedKaiPersonality).id == KaiPersonality.zenMinimalist.id,
                onPhaseChange: { phase, duration in
                    currentPhase = phase
                    manager.playBreathingCue(phase: phase, duration: duration)
                }
            )

            // Timer display
            VStack(spacing: 4) {
                Text(timerText)
                    .font(.system(size: 64, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                
                if manager.state == .meditating, manager.isGuruEnabled, manager.currentScript != nil {
                    KaiScriptView()
                        .frame(height: 200)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.top, 12)
            .animation(.easeInOut, value: manager.currentKaiPhrase)

            if manager.state == .idle {
                libraryButton
                    .padding(.top, 6)
                
                durationPicker
                    .padding(.top, 10)
            }

            Spacer()
        }
    }

    // MARK: - Subviews

    private var backgroundGradient: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundColors: [Color] {
        switch manager.state {
        case .idle:
            return [
                Color(hue: 0.70, saturation: 0.5, brightness: 0.12),
                Color(hue: 0.75, saturation: 0.6, brightness: 0.08),
                Color(hue: 0.80, saturation: 0.4, brightness: 0.06),
            ]
        case .meditating:
            return [
                Color(hue: 0.68, saturation: 0.5, brightness: 0.15),
                Color(hue: 0.72, saturation: 0.55, brightness: 0.10),
                Color(hue: 0.78, saturation: 0.4, brightness: 0.07),
            ]
        case .complete:
            return [
                Color(hue: 0.55, saturation: 0.4, brightness: 0.15),
                Color(hue: 0.60, saturation: 0.5, brightness: 0.10),
                Color(hue: 0.65, saturation: 0.35, brightness: 0.07),
            ]
        }
    }

    private var statusLabel: some View {
        Text(statusText)
            .font(.title3.weight(.light))
            .foregroundStyle(.white.opacity(0.6))
            .tracking(2)
    }

    private var statusText: String {
        switch manager.state {
        case .idle:
            return String(localized: "content.status.ready")
        case .meditating:
            return localizedPhaseStatus(currentPhase)
        case .complete:
            return String(localized: "content.status.complete")
        }
    }

    private func localizedPhaseStatus(_ phase: String) -> String {
        guard !phase.isEmpty else { return String(localized: "content.status.breathe") }

        switch phase.lowercased() {
        case "inhale":
            return String(localized: "content.phase.inhale")
        case "exhale":
            return String(localized: "content.phase.exhale")
        case "hold":
            return String(localized: "content.phase.hold")
        default:
            return phase.uppercased()
        }
    }

    private var timerText: String {
        switch manager.state {
        case .idle:
            let mins = manager.durationMinutes
            if mins == 0 {
                return "00:00"
            }
            return String(format: "%02d:00", mins)
        case .meditating, .complete:
            return manager.formattedTime
        }
    }

    private var techniqueTimings: String {
        let t = manager.selectedTechnique
        var parts: [String] = []
        parts.append(String(format: String(localized: "content.timing.in_format"), Int(t.inhale)))
        if t.holdIn > 0 {
            parts.append(String(format: String(localized: "content.timing.hold_format"), Int(t.holdIn)))
        }
        parts.append(String(format: String(localized: "content.timing.out_format"), Int(t.exhale)))
        if t.holdOut > 0 {
            parts.append(String(format: String(localized: "content.timing.hold_format"), Int(t.holdOut)))
        }
        return parts.joined(separator: " · ")
    }

    private var actionButton: some View {
        Button {
            handleAction()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: actionIcon)
                    .font(.body.weight(.semibold))
                Text(actionText)
                    .font(.body.weight(.medium))
                    .tracking(1)
            }
            .foregroundStyle(actionForeground)
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .background(actionBackground)
            .clipShape(Capsule())
        }
    }

    private var durationPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Infinite (always first)
                durationPill(mins: 0, label: "∞")

                // All durations (built-in + custom)
                ForEach(manager.allDurations, id: \.self) { mins in
                    durationPill(mins: mins, label: "\(mins)m")
                        .contextMenu {
                            if manager.isCustomDuration(mins) {
                                Button(role: .destructive) {
                                    manager.removeCustomDuration(mins)
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Label(String(localized: "ui.remove"), systemImage: "trash")
                                }
                            }
                        }
                }

                // Add Button
                Button {
                    showAddDuration = true
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private var libraryButton: some View {
        // Library Button
        Button {
            showSavedMeditations = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.05)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(height: 44)
    }

    private func durationPill(mins: Int, label: String) -> some View {
        let isSelected = manager.durationMinutes == mins
        let isCustom = manager.isCustomDuration(mins)

        return Button {
            withAnimation {
                manager.durationMinutes = mins
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(isSelected 
                            ? Color(hue: 0.55, saturation: 0.6, brightness: 0.7).opacity(0.4)
                            : Color.white.opacity(0.05))
                )
                .overlay(
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        if isCustom {
                            Circle()
                                .fill(Color(hue: 0.45, saturation: 0.5, brightness: 0.8))
                                .frame(width: 6, height: 6)
                                .offset(x: 16, y: -16)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var actionIcon: String {
        switch manager.state {
        case .idle: return "play.fill"
        case .meditating: return "stop.fill"
        case .complete: return "arrow.counterclockwise"
        }
    }

    private var actionText: String {
        switch manager.state {
        case .idle: return String(localized: "content.action.begin")
        case .meditating: return String(localized: "content.action.stop")
        case .complete: return String(localized: "content.action.done")
        }
    }

    private var actionForeground: Color {
        switch manager.state {
        case .idle:
            return .white
        case .meditating:
            return .white.opacity(0.9)
        case .complete:
            return .white
        }
    }

    @ViewBuilder
    private var actionBackground: some View {
        switch manager.state {
        case .idle:
            Capsule()
                .fill(Color(hue: 0.55, saturation: 0.6, brightness: 0.7).opacity(0.4))
                .overlay(
                    Capsule()
                        .stroke(Color(hue: 0.55, saturation: 0.5, brightness: 0.9).opacity(0.3), lineWidth: 1)
                )
        case .meditating:
            Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        case .complete:
            Capsule()
                .fill(Color(hue: 0.45, saturation: 0.5, brightness: 0.6).opacity(0.4))
                .overlay(
                    Capsule()
                        .stroke(Color(hue: 0.45, saturation: 0.4, brightness: 0.8).opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func handleAction() {
        switch manager.state {
        case .idle:
            manager.start()
        case .meditating:
            manager.stop()
        case .complete:
            manager.reset()
            requestReviewIfAppropriate()
        }
    }

    private func requestReviewIfAppropriate() {
        guard ReviewPromptPolicy.shouldRequestReview else { return }
        ReviewPromptPolicy.recordReviewRequest()
        requestReview()
    }

    private func toggleQuickMoodRecording() {
        if speechManager.isRecording {
            speechManager.stopRecording()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        Task {
            do {
                try await speechManager.requestPermissions()
                try speechManager.startRecording()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } catch let speechError as SpeechManager.SpeechError {
                quickMoodErrorMessage = speechError.localizedDescription
                showQuickMoodSettingsPrompt = true
            } catch {
                quickMoodErrorTitle = String(localized: "alerts.voice_input_unavailable")
                quickMoodErrorMessage = String(localized: "kai.voice_input_unavailable_type_mood")
                showQuickMoodError = true
            }
        }
    }

    private func startQuickMoodMeditationFromHome() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            await StoreKitManager.shared.updateCustomerProductStatus()
            guard KaiBrainService.usesLocalScripts || StoreKitManager.shared.isVindlaProSubscribed else {
                showMeditationPaywall = true
                return
            }

            do {
                try await manager.startQuickMoodSessionFromHome(moodText: quickMoodInput)
                quickMoodInput = ""
                if speechManager.isRecording {
                    speechManager.stopRecording()
                }
            } catch {
                if case KaiBrainService.BrainError.serviceUnavailable = error {
                    quickMoodErrorTitle = String(localized: "kai.error.not_configured.title")
                    quickMoodErrorMessage = String(localized: "kai.error.not_configured.message")
                } else if let urlError = error as? URLError {
                    quickMoodErrorTitle = String(localized: "kai.error.connection.title")
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        quickMoodErrorMessage = String(localized: "kai.error.connection.offline")
                    case .timedOut:
                        quickMoodErrorMessage = String(localized: "kai.error.connection.timeout")
                    default:
                        quickMoodErrorMessage = String(localized: "kai.error.connection.generic")
                    }
                } else {
                    quickMoodErrorTitle = String(localized: "kai.error.resting.title")
                    quickMoodErrorMessage = String(localized: "kai.error.resting.message")
                }
                showQuickMoodError = true
            }
        }
    }

    private func startSavedScriptFromHome(_ script: MeditationScript) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            await StoreKitManager.shared.updateCustomerProductStatus()
            guard KaiBrainService.usesLocalScripts || StoreKitManager.shared.isVindlaProSubscribed else {
                showMeditationPaywall = true
                return
            }

            manager.durationMinutes = script.durationMinutes
            manager.isGuruEnabled = true
            manager.currentScript = script
            GuruManager.shared.play(script: script)
            manager.start(durationMinutes: script.durationMinutes)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }


}

// MARK: - Technique Library View

struct TechniqueLibraryView: View {
    var allowsPreviewSelection = false
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @State private var storeManager = StoreKitManager.shared
    @State private var showingCustomEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.72, saturation: 0.4, brightness: 0.10)
                    .ignoresSafeArea()

                List {
                    Section {
                        techniqueRow(BreathingTechnique.defaultTechnique)
                    } header: {
                        Text(String(localized: "content.standard"))
                    }

                    Section {
                        ForEach(BreathingTechnique.presets) { technique in
                            techniqueRow(technique)
                        }
                    } header: {
                        HStack {
                            Text(String(localized: "content.library"))
                            Spacer()
                            if !allowsPreviewSelection && !storeManager.isPurchased(StoreKitManager.techniqueLibraryID) {
                                Button(String(format: String(localized: "content.unlock_all_format"), storeManager.displayPrice(for: StoreKitManager.techniqueLibraryID, fallback: "$1.99"))) {
                                    Task {
                                        await storeManager.purchase(StoreKitManager.techniqueLibraryID)
                                    }
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                            }
                        }
                    }

                    Section {
                        ForEach(manager.userCustomTechniques) { technique in
                            techniqueRow(technique)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        manager.removeCustomTechnique(technique.id)
                                    } label: {
                                        Label(String(localized: "ui.delete"), systemImage: "trash")
                                    }
                                }
                        }

                        if storeManager.isPurchased(StoreKitManager.customTechniqueEditorID) {
                            Button {
                                showingCustomEditor = true
                            } label: {
                                Label(String(localized: "content.create_custom_technique"), systemImage: "plus")
                            }
                        } else {
                            Button {
                                Task {
                                    await storeManager.purchase(StoreKitManager.customTechniqueEditorID)
                                }
                            } label: {
                                HStack {
                                    Label(String(localized: "content.create_custom_technique"), systemImage: "lock.fill")
                                    Spacer()
                                    Text(String(format: String(localized: "content.unlock_custom_format"), storeManager.displayPrice(for: StoreKitManager.customTechniqueEditorID, fallback: "$0.99")))
                                        .font(.caption.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "content.custom"))
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle(String(localized: "nav.techniques"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingCustomEditor) {
                CustomTechniqueEditor()
                    .environment(manager)
            }
        }
    }

    private func techniqueRow(_ technique: BreathingTechnique) -> some View {
        let isLocked = technique.isPurchasable && !allowsPreviewSelection && !storeManager.isPurchased(StoreKitManager.techniqueLibraryID)
        let isSelected = manager.selectedTechnique.id == technique.id

        return Button {
            if !isLocked {
                manager.selectedTechnique = technique
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(technique.localizedName)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .blue : .white)
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
                
                Text(technique.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                
                Text(String(format: String(localized: "content.technique_timing_full_format"),
                           technique.inhale, technique.holdIn, technique.exhale, technique.holdOut))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 4)
        }
        .disabled(isLocked)
        .listRowBackground(Color.white.opacity(0.04))
    }
}

// MARK: - Custom Technique Editor

struct CustomTechniqueEditor: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var inhale: Double = 4
    @State private var holdIn: Double = 0
    @State private var exhale: Double = 4
    @State private var holdOut: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "content.custom_section_name")) {
                    TextField(String(localized: "content.custom_name_placeholder"), text: $name)
                }

                Section(String(localized: "content.custom_section_timings")) {
                    timingRow(title: String(localized: "content.inhale"), value: $inhale)
                    timingRow(title: String(localized: "content.hold_in"), value: $holdIn)
                    timingRow(title: String(localized: "content.exhale"), value: $exhale)
                    timingRow(title: String(localized: "content.hold_out"), value: $holdOut)
                }

                Section {
                    Button(String(localized: "content.add_technique")) {
                        let new = BreathingTechnique(
                            id: UUID().uuidString,
                            name: name.isEmpty ? String(localized: "content.custom_technique_default_name") : name,
                            description: String(localized: "content.custom_technique_default_description"),
                            inhale: inhale,
                            holdIn: holdIn,
                            exhale: exhale,
                            holdOut: holdOut
                        )
                        manager.addCustomTechnique(new)
                        manager.selectedTechnique = new
                        dismiss()
                    }
                    .disabled(inhale == 0 || exhale == 0)
                }
            }
            .navigationTitle(String(localized: "nav.new_technique"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "ui.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func timingRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: String(localized: "content.seconds_format"), Int(value.wrappedValue)))
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            }
            Slider(value: value, in: 0...20, step: 1)
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Environment(MeditationManager.self) private var manager
    @State private var currentPage = 0
    @State private var selectedOnboardingPersonalityID: String? = KaiPersonality.default.id
    
    let pages = [
        OnboardingPage(
            titleKey: "onboarding.page3.title",
            descriptionKey: "onboarding.page3.description",
            systemImage: "sparkles"
        ),
        OnboardingPage(
            titleKey: "onboarding.page4.title",
            descriptionKey: "onboarding.page4.description",
            systemImage: "person.crop.rectangle.stack.fill",
            style: .personalitySelection
        ),
        OnboardingPage(
            titleKey: "onboarding.page1.title",
            descriptionKey: "onboarding.page1.description",
            systemImage: "circle.dotted"
        )
    ]
    
    var body: some View {
        ZStack {
            Color(hue: 0.72, saturation: 0.4, brightness: 0.10)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(for: pages[index])
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 640)

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? .white : .white.opacity(0.22))
                            .frame(width: index == currentPage ? 20 : 8, height: 8)
                    }
                }
                
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        withAnimation {
                            manager.hasSeenOnboarding = true
                        }
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? String(localized: "onboarding.get_started") : String(localized: "onboarding.next"))
                        .font(.headline)
                        .foregroundStyle(isNextEnabled ? .white : .white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    isNextEnabled
                                        ? Color(hue: 0.55, saturation: 0.6, brightness: 0.7)
                                        : Color.white.opacity(0.10)
                                )
                        )
                        .padding(.horizontal, 40)
                }
                .disabled(!isNextEnabled)
            }
            .padding(.vertical, 60)
        }
        .preferredColorScheme(.dark)
    }

    private var isNextEnabled: Bool {
        pages[currentPage].style != .personalitySelection || selectedOnboardingPersonalityID != nil
    }

    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        switch page.style {
        case .standard:
            VStack(spacing: 24) {
                Image(systemName: page.systemImage)
                    .font(.system(size: 80, weight: .thin))
                    .foregroundStyle(Color(hue: 0.55, saturation: 0.6, brightness: 0.8))
                    .padding(.bottom, 20)
                
                Text(page.localizedTitle)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(page.localizedDescription)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }

        case .personalitySelection:
            VStack(spacing: 24) {
                Image(systemName: page.systemImage)
                    .font(.system(size: 70, weight: .thin))
                    .foregroundStyle(Color(hue: 0.55, saturation: 0.6, brightness: 0.8))
                
                Text(page.localizedTitle)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(page.localizedDescription)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(KaiPersonality.all) { personality in
                            Button {
                                manager.selectedKaiPersonalityID = personality.id
                                selectedOnboardingPersonalityID = personality.id
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    GuideArtwork.image(named: personality.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 210, height: 150)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 24)
                                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                                        }

                                    HStack(spacing: 8) {
                                        Text(personality.localizedName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white)

                                        if selectedOnboardingPersonalityID == personality.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                    }

                                    Text(personality.localizedShortDescription)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.65))
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(width: 210, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(selectedOnboardingPersonalityID == personality.id ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 28)
                                                .strokeBorder(selectedOnboardingPersonalityID == personality.id ? .white.opacity(0.22) : .white.opacity(0.06), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

enum ReviewPromptPolicy {
    private static let completedSessionCountKey = "review.completed_session_count"
    private static let lastRequestedVersionKey = "review.last_requested_version"
    private static let lastRequestedDateKey = "review.last_requested_date"
    private static let minimumSessionSeconds = 60
    private static let minimumCompletedSessions = 3
    private static let minimumDaysBetweenRequests = 180.0

    static func recordCompletedSession(durationSeconds: Int) {
        guard durationSeconds >= minimumSessionSeconds else { return }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: completedSessionCountKey) + 1, forKey: completedSessionCountKey)
    }

    static var shouldRequestReview: Bool {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: completedSessionCountKey) >= minimumCompletedSessions else {
            return false
        }

        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let lastVersion = defaults.string(forKey: lastRequestedVersionKey)
        guard lastVersion != currentVersion else { return false }

        let lastRequestedAt = defaults.object(forKey: lastRequestedDateKey) as? Date
        if let lastRequestedAt,
           Date().timeIntervalSince(lastRequestedAt) < minimumDaysBetweenRequests * 24 * 60 * 60 {
            return false
        }

        return true
    }

    static func recordReviewRequest() {
        let defaults = UserDefaults.standard
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        defaults.set(currentVersion, forKey: lastRequestedVersionKey)
        defaults.set(Date(), forKey: lastRequestedDateKey)
    }
}

struct OnboardingPage {
    let titleKey: String
    let descriptionKey: String
    let systemImage: String
    let style: Style

    var localizedTitle: String {
        Bundle.main.localizedString(forKey: titleKey, value: titleKey, table: nil)
    }

    var localizedDescription: String {
        Bundle.main.localizedString(forKey: descriptionKey, value: descriptionKey, table: nil)
    }

    init(titleKey: String, descriptionKey: String, systemImage: String, style: Style = .standard) {
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.systemImage = systemImage
        self.style = style
    }

    enum Style {
        case standard
        case personalitySelection
    }
}
