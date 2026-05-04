import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(MeditationManager.self) private var manager

    @State private var showSettings = false
    @State private var showSoundLibrary = false
    @State private var showStats = false
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
    @State private var showJourneyOnboarding = false
    @State private var showJourneyOverview = false
    @State private var showJourneyPaywall = false
    @State private var showJourneyError = false
    @State private var journeyErrorTitle = ""
    @State private var journeyErrorMessage = ""
    @State private var quickMoodInput = ""
    @State private var quickMoodErrorTitle = ""
    @State private var quickMoodErrorMessage = ""
    @State private var showQuickMoodError = false
    @State private var showQuickMoodSettingsPrompt = false
    @State private var isTodayStepExpanded = false
    @State private var storeManager = StoreKitManager.shared
    @AppStorage("homeViewMode") private var homeViewMode = HomeViewMode.hero
    private let speechManager = SpeechManager.shared

    private struct ReflectionSheetContext: Identifiable {
        let id = UUID()
        let sessionID: UUID
        let defaultReminderTime: Date
    }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    // Left: Mode Toggle & Stats
                    HStack(spacing: 4) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                homeViewMode = (homeViewMode == .hero) ? .timer : .hero
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: homeViewMode == .hero ? "timer" : "sparkles")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .accessibilityLabel(
                            homeViewMode == .hero
                                ? String(localized: "content.mode.simple_timer")
                                : String(localized: "content.mode.mimir")
                        )
                        
                        Button(action: { showStats = true }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 44, height: 44)
                        }
                    }

                    Spacer()

                    // Right: Technique & Settings
                    HStack(spacing: 8) {
                        Button(action: { showTechniques = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "wind")
                                    .font(.system(size: 12))
                                Text(manager.selectedTechnique.localizedName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                        }

                        Button(action: { showSoundLibrary = true }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 44, height: 44)
                        }

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .layoutPriority(1)

                if manager.state == .idle, homeViewMode == .hero {
                    heroHomeScrollView
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    if manager.state == .idle {
                        timerView
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    } else {
                        // Always show timer view when active
                        timerView
                            .transition(.opacity)
                    }

                    Spacer()

                    // Action button & Siri hint
                    VStack(spacing: 16) {
                        actionButton
                        
                        if manager.state == .idle {
                            Button {
                                showTechniques = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text(techniqueTimings)
                                        .font(.system(size: 11, design: .monospaced))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                    }
                    .padding(.bottom, 16)
                    .layoutPriority(1)
                }
            }

            if manager.isGeneratingGuidedSession {
                guidedSessionLoadingOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }
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
        .fullScreenCover(isPresented: $showStats) {
            StatisticsView()
                .environment(manager)
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
        .sheet(isPresented: $showJourneyOnboarding) {
            PracticeJourneyOnboardingSheet(
                initialGoal: manager.practiceJourneyPrimaryGoal,
                initialObstacle: manager.practiceJourneyMainObstacle,
                initialPreferredStyle: manager.practiceJourneyPreferredStyle,
                initialPreferredDuration: manager.practiceJourneyPreferredOnboardingDuration
            ) { goal, obstacle, preferredStyle, preferredDuration in
                manager.savePracticeJourneyPreferences(
                    goal: goal,
                    obstacle: obstacle,
                    preferredStyle: preferredStyle,
                    preferredDurationMinutes: preferredDuration
                )
                showJourneyOnboarding = false
                startPracticeJourneyLaunchTask()
            }
            .environment(manager)
        }
        .sheet(isPresented: $showJourneyOverview) {
            if let plan = manager.practiceJourneyPlanForOverview {
                PracticeJourneyPlanOverviewSheet(plan: plan)
                    .environment(manager)
            }
        }
        .sheet(isPresented: $showJourneyPaywall) {
            KAIPaywallView()
        }
        .sheet(item: $reflectionSheetContext, onDismiss: { 
            reflectionSheetContext = nil 
            manager.reset()
        }) { context in
            ReflectionPromptView(
                sessionID: context.sessionID,
                defaultReminderTime: context.defaultReminderTime
            )
            .environment(manager)
        }
        .sheet(isPresented: $showSleepStoryCompletion, onDismiss: {
            manager.reset()
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
        .alert(journeyErrorTitle, isPresented: $showJourneyError) {
            Button(String(localized: "kai.i_understand")) { }
        } message: {
            Text(journeyErrorMessage)
        }
        .animation(.easeInOut(duration: 0.6), value: manager.state)
        .onChange(of: manager.state) { _, newValue in
            guard newValue == .complete else { return }
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
                showSoundLibrary = false
                showStats = false
                showTechniques = false
                showKaiExperience = false
                showSleepStories = false
                showSavedMeditations = false
                showJourneyOnboarding = false
                showJourneyOverview = false
                showJourneyPaywall = false
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
        .onChange(of: homeViewMode) { _, newValue in
            if newValue != .hero, speechManager.isRecording {
                speechManager.stopRecording()
            }
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
                dailyPracticeSection
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

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

    private var dailyPracticeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                eyebrow: "DAILY PRACTICE",
                title: "Your weekly path",
                detail: "One clear step each day. Built to feel steady and easy to return to."
            )

            practiceJourneyHomeCard
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
                    Image(imageName)
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

    private var practiceJourneyHomeCard: some View {
        let personality = manager.selectedKaiPersonality

        return VStack(alignment: .leading, spacing: 14) {
            Button {
                startPracticeJourneyFromHome()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(personality.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "content.today_step.guiding_week"))
                                .font(.system(size: 9, weight: .bold))
                                .kerning(1.1)
                                .foregroundStyle(.white.opacity(0.45))
                            Text(personality.localizedName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "content.today_step.eyebrow"))
                                .font(.system(size: 10, weight: .bold))
                                .kerning(1.2)
                                .foregroundStyle(.white.opacity(0.5))

                            switch manager.practiceJourneyHomeCardState {
                            case .start:
                                Text(String(localized: "content.today_step.start_title"))
                                    .font(.system(size: 22, weight: .light, design: .serif))
                                    .foregroundStyle(.white)

                            case .active(let plan, let step):
                                Text(plan.title)
                                    .font(.system(size: 22, weight: .light, design: .serif))
                                    .foregroundStyle(.white)
                                Text(String(format: String(localized: "content.today_step.day_of_week_format"), step.dayNumber))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.82, green: 0.94, blue: 0.86))

                            case .readyForNextCycle(_, let nextCycleNumber):
                                Text(String(localized: "content.today_step.generate_next_title"))
                                    .font(.system(size: 22, weight: .light, design: .serif))
                                    .foregroundStyle(.white)
                                Text(String(format: String(localized: "content.today_step.week_format"), nextCycleNumber))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.82, green: 0.94, blue: 0.86))
                            }
                        }
                    }

                    switch manager.practiceJourneyHomeCardState {
                    case .start:
                        if isTodayStepExpanded {
                            Text(String(localized: "content.today_step.start_detail"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .multilineTextAlignment(.leading)
                        }
                        journeyPrimaryCTAChip(label: String(localized: "content.today_step.start_practice_cta"))

                    case .active(let plan, let step):
                        Text(step.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        if isTodayStepExpanded {
                            Text(step.purpose)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .multilineTextAlignment(.leading)
                        }

                        HStack(spacing: 10) {
                            if isTodayStepExpanded {
                                Text(step.focus)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text("\(plan.completedStepCount)/7")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(red: 0.82, green: 0.94, blue: 0.86))
                        }

                        journeyPrimaryCTAChip(label: String(localized: "content.today_step.start_practice_cta"))

                    case .readyForNextCycle(let goalSummary, let nextCycleNumber):
                        if isTodayStepExpanded {
                            Text(goalSummary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .multilineTextAlignment(.leading)
                            Text(String(format: String(localized: "content.today_step.next_week_detail_format"), nextCycleNumber))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        journeyPrimaryCTAChip(label: String(format: String(localized: "content.today_step.generate_week_cta_format"), nextCycleNumber))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTodayStepExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isTodayStepExpanded ? String(localized: "content.today_step.hide_details") : String(localized: "content.today_step.view_details"))
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: isTodayStepExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)

            if let plan = manager.practiceJourneyPlanForOverview {
                Divider()
                    .overlay(Color.white.opacity(0.08))

                Button {
                    showJourneyOverview = true
                } label: {
                    HStack(spacing: 12) {
                        stepPreviewStrip(for: plan)

                        Spacer()

                        HStack(spacing: 6) {
                            Text(String(localized: "content.today_step.view_all_steps"))
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.24, blue: 0.22),
                            Color(red: 0.12, green: 0.16, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
    }

    private func journeyPrimaryCTAChip(label: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.16))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepPreviewStrip(for plan: PracticeJourneyPlan) -> some View {
        HStack(spacing: 8) {
            ForEach(plan.steps) { step in
                Circle()
                    .fill(stepPreviewColor(step: step, in: plan))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(step.isCompleted ? 0 : 0.25), lineWidth: 1)
                    )
            }
        }
    }

    private func stepPreviewColor(step: PracticeJourneyStep, in plan: PracticeJourneyPlan) -> Color {
        if step.isCompleted {
            return Color(red: 0.82, green: 0.94, blue: 0.86)
        }

        if plan.nextStep?.id == step.id {
            return Color.white.opacity(0.95)
        }

        return Color.clear
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

                Image(manager.selectedKaiPersonality.imageName)
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

    private var timerView: some View {
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
        }
    }

    private func startPracticeJourneyFromHome() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            await StoreKitManager.shared.updateCustomerProductStatus()

            if !StoreKitManager.shared.isVindlaProSubscribed {
                showJourneyPaywall = true
                return
            }

            if manager.practiceJourneyNeedsOnboarding {
                showJourneyOnboarding = true
                return
            }

            startPracticeJourneyLaunchTask()
        }
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
            guard StoreKitManager.shared.isVindlaProSubscribed else {
                showJourneyPaywall = true
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
            guard StoreKitManager.shared.isVindlaProSubscribed else {
                showJourneyPaywall = true
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

    private func startPracticeJourneyLaunchTask() {
        Task {
            do {
                try await manager.startTodayPracticeJourneyStep()
            } catch {
                if case KaiBrainService.BrainError.serviceUnavailable = error {
                    journeyErrorTitle = String(localized: "kai.error.not_configured.title")
                    journeyErrorMessage = String(localized: "kai.error.not_configured.message")
                } else if let urlError = error as? URLError {
                    journeyErrorTitle = String(localized: "kai.error.connection.title")
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        journeyErrorMessage = String(localized: "kai.error.connection.offline")
                    case .timedOut:
                        journeyErrorMessage = String(localized: "kai.error.connection.timeout")
                    default:
                        journeyErrorMessage = String(localized: "kai.error.connection.generic")
                    }
                } else {
                    journeyErrorTitle = "Couldn’t start today’s step"
                    journeyErrorMessage = "Try again in a moment. Your daily path is still saved."
                }
                showJourneyError = true
            }
        }
    }
}

// MARK: - Statistics View

struct PracticeJourneyOnboardingSheet: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    let onContinue: (String, String?, String?, Int) -> Void

    @State private var currentStep = 0
    @State private var primaryGoal: String
    @State private var mainObstacle: String
    @State private var selectedStyleID: String
    @State private var preferredDuration: Int

    private static let styleOptions: [JourneyTechniqueStyle] = [
        JourneyTechniqueStyle(
            id: "breath_anchor",
            titleKey: "journey.onboarding.style.breath_anchor.title",
            summaryKey: "journey.onboarding.style.breath_anchor.summary",
            detailKey: "journey.onboarding.style.breath_anchor.detail",
            keywords: ["calm", "anxiety", "restless", "consistency", "steady", "stress"]
        ),
        JourneyTechniqueStyle(
            id: "body_scan",
            titleKey: "journey.onboarding.style.body_scan.title",
            summaryKey: "journey.onboarding.style.body_scan.summary",
            detailKey: "journey.onboarding.style.body_scan.detail",
            keywords: ["tension", "body", "grounded", "sleep", "tired", "relax"]
        ),
        JourneyTechniqueStyle(
            id: "loving_kindness",
            titleKey: "journey.onboarding.style.self_compassion.title",
            summaryKey: "journey.onboarding.style.self_compassion.summary",
            detailKey: "journey.onboarding.style.self_compassion.detail",
            keywords: ["compassion", "pressure", "hard on myself", "emotional", "kind", "gentle"]
        ),
        JourneyTechniqueStyle(
            id: "visualization",
            titleKey: "journey.onboarding.style.visualization.title",
            summaryKey: "journey.onboarding.style.visualization.summary",
            detailKey: "journey.onboarding.style.visualization.detail",
            keywords: ["focus", "clarity", "motivation", "creative", "imagery", "reset"]
        ),
        JourneyTechniqueStyle(
            id: "open_awareness",
            titleKey: "journey.onboarding.style.open_awareness.title",
            summaryKey: "journey.onboarding.style.open_awareness.summary",
            detailKey: "journey.onboarding.style.open_awareness.detail",
            keywords: ["deep", "stillness", "silence", "advanced", "spacious", "presence"]
        )
    ]

    init(
        initialGoal: String = "",
        initialObstacle: String = "",
        initialPreferredStyle: String = "",
        initialPreferredDuration: Int = 10,
        onContinue: @escaping (String, String?, String?, Int) -> Void
    ) {
        self.onContinue = onContinue
        _primaryGoal = State(initialValue: initialGoal)
        _mainObstacle = State(initialValue: initialObstacle)
        let initialStyleID = Self.styleOptions.first(where: {
            $0.id == initialPreferredStyle || $0.localizedTitle == initialPreferredStyle
        })?.id ?? ""
        _selectedStyleID = State(initialValue: initialStyleID)
        _preferredDuration = State(initialValue: initialPreferredDuration)
    }

    private var totalSteps: Int { 4 }

    private var availableDurations: [Int] {
        manager.allDurations
            .filter { $0 > 0 && $0 <= KaiBrainService.maxAIGenerationDurationMinutes }
            .sorted()
    }

    private var trimmedGoal: String {
        primaryGoal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedStyle: JourneyTechniqueStyle? {
        Self.styleOptions.first(where: { $0.id == selectedStyleID })
    }

    private var recommendedStyleIDs: Set<String> {
        let source = "\(primaryGoal) \(mainObstacle)".lowercased()
        let scored = Self.styleOptions.map { option in
            let score = option.keywords.reduce(0) { partial, keyword in
                partial + (source.contains(keyword) ? 1 : 0)
            }
            return (option.id, score)
        }

        let maxScore = scored.map(\.1).max() ?? 0
        guard maxScore > 0 else {
            return ["breath_anchor", "body_scan"]
        }

        return Set(scored.filter { $0.1 == maxScore }.map(\.0))
    }

    private var canMoveForward: Bool {
        switch currentStep {
        case 0:
            return !trimmedGoal.isEmpty
        case 1:
            return true
        case 2:
            return selectedStyle != nil
        case 3:
            return true
        default:
            return false
        }
    }

    private var primaryButtonTitle: String {
        currentStep == totalSteps - 1 ? String(localized: "journey.onboarding.create_path") : String(localized: "ui.continue")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        pageIntro
                        currentQuestionView
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        Rectangle()
                            .fill(Color.black.opacity(0.12))
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
            .navigationTitle(String(localized: "journey.onboarding.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "ui.cancel")) { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .preferredColorScheme(.dark)
            .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.07).ignoresSafeArea())
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(format: String(localized: "journey.onboarding.step_count_format"), currentStep + 1, totalSteps))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? .white.opacity(0.88) : .white.opacity(0.12))
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var pageIntro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(questionTitle)
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(.white)

            Text(questionSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private var currentQuestionView: some View {
        switch currentStep {
        case 0:
            goalQuestion
        case 1:
            obstacleQuestion
        case 2:
            styleQuestion
        default:
            durationQuestion
        }
    }

    private var goalQuestion: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(
                String(localized: "journey.onboarding.goal_placeholder"),
                text: $primaryGoal,
                axis: .vertical
            )
            .lineLimit(3...5)
            .padding(18)
            .background(cardBackground)

            quickPickRow(
                title: String(localized: "journey.onboarding.try_one"),
                options: [
                    String(localized: "journey.onboarding.goal_option.calm"),
                    String(localized: "journey.onboarding.goal_option.consistency"),
                    String(localized: "journey.onboarding.goal_option.sleep"),
                    String(localized: "journey.onboarding.goal_option.focus")
                ],
                selection: $primaryGoal
            )
        }
    }

    private var obstacleQuestion: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(
                String(localized: "journey.onboarding.obstacle_placeholder"),
                text: $mainObstacle,
                axis: .vertical
            )
            .lineLimit(2...4)
            .padding(18)
            .background(cardBackground)

            quickPickRow(
                title: String(localized: "journey.onboarding.common_blockers"),
                options: [
                    String(localized: "journey.onboarding.obstacle_option.restless"),
                    String(localized: "journey.onboarding.obstacle_option.forget"),
                    String(localized: "journey.onboarding.obstacle_option.tired"),
                    String(localized: "journey.onboarding.obstacle_option.overthink")
                ],
                selection: $mainObstacle
            )

            Text(String(localized: "journey.onboarding.obstacle_skip_help"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var styleQuestion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "journey.onboarding.style_help"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            ForEach(Self.styleOptions) { option in
                styleCard(option)
            }
        }
    }

    private var durationQuestion: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "journey.onboarding.duration_help"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableDurations, id: \.self) { duration in
                        Button {
                            preferredDuration = duration
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text("\(duration)m")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(preferredDuration == duration ? .white : .white.opacity(0.72))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(
                                            preferredDuration == duration
                                                ? Color(hue: 0.55, saturation: 0.6, brightness: 0.7).opacity(0.45)
                                                : Color.white.opacity(0.06)
                                        )
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(preferredDuration == duration ? 0.18 : 0.08), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                settingsHintRow(
                    icon: "person.crop.circle",
                    title: String(localized: "journey.onboarding.guide_label"),
                    value: manager.selectedKaiPersonality.localizedName
                )
                settingsHintRow(
                    icon: "circle.lefthalf.filled",
                    title: String(localized: "journey.onboarding.stillness_label"),
                    value: stillnessDescription
                )
                settingsHintRow(
                    icon: "sparkles",
                    title: String(localized: "journey.onboarding.technique_label"),
                    value: selectedStyle?.localizedTitle ?? String(localized: "journey.onboarding.style.breath_anchor.title")
                )
            }
            .padding(18)
            .background(cardBackground)

            Text(String(localized: "journey.onboarding.settings_help"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        currentStep -= 1
                    }
                } label: {
                    Text(String(localized: "ui.back"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                if currentStep == totalSteps - 1 {
                    onContinue(
                        trimmedGoal,
                        normalizedText(mainObstacle),
                        selectedStyle?.localizedTitle,
                        preferredDuration
                    )
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        currentStep += 1
                    }
                }
            } label: {
                Text(primaryButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canMoveForward ? .white : .white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                canMoveForward
                                    ? Color(hue: 0.55, saturation: 0.6, brightness: 0.7).opacity(0.45)
                                    : Color.white.opacity(0.08)
                            )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(canMoveForward ? 0.18 : 0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canMoveForward)
        }
    }

    private func styleCard(_ option: JourneyTechniqueStyle) -> some View {
        let isSelected = selectedStyleID == option.id
        let isRecommended = recommendedStyleIDs.contains(option.id)

        return Button {
            selectedStyleID = option.id
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(option.localizedTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))

                            if isRecommended {
                                Text(String(localized: "journey.onboarding.suggested"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.75))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color(red: 0.82, green: 0.94, blue: 0.86)))
                            }
                        }

                        Text(option.localizedSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.3))
                }

                Text(option.localizedDetail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineSpacing(2)
            }
            .padding(18)
            .background(styleCardBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private var questionTitle: String {
        switch currentStep {
        case 0:
            return String(localized: "journey.onboarding.question.goal.title")
        case 1:
            return String(localized: "journey.onboarding.question.obstacle.title")
        case 2:
            return String(localized: "journey.onboarding.question.style.title")
        default:
            return String(localized: "journey.onboarding.question.duration.title")
        }
    }

    private var questionSubtitle: String {
        switch currentStep {
        case 0:
            return String(localized: "journey.onboarding.question.goal.subtitle")
        case 1:
            return String(localized: "journey.onboarding.question.obstacle.subtitle")
        case 2:
            return String(localized: "journey.onboarding.question.style.subtitle")
        default:
            return String(localized: "journey.onboarding.question.duration.subtitle")
        }
    }

    private func quickPickRow(
        title: String,
        options: [String],
        selection: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection.wrappedValue = option
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text(option)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.84))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func settingsHintRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.06)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }

            Spacer()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func styleCardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
            )
    }

    private var stillnessDescription: String {
        let percentage = Int((manager.preferredStillnessRatio * 100).rounded())
        switch percentage {
        case ..<35:
            return String(localized: "journey.onboarding.stillness.more_guided")
        case 35...65:
            return String(localized: "journey.onboarding.stillness.balanced")
        default:
            return String(localized: "journey.onboarding.stillness.more_spacious")
        }
    }

    private func normalizedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct JourneyTechniqueStyle: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let summaryKey: String
    let detailKey: String
    let keywords: [String]

    var localizedTitle: String {
        Bundle.main.localizedString(forKey: titleKey, value: titleKey, table: nil)
    }

    var localizedSummary: String {
        Bundle.main.localizedString(forKey: summaryKey, value: summaryKey, table: nil)
    }

    var localizedDetail: String {
        Bundle.main.localizedString(forKey: detailKey, value: detailKey, table: nil)
    }
}

struct PracticeJourneyPlanOverviewSheet: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    let plan: PracticeJourneyPlan
    @State private var showStartError = false
    @State private var startErrorTitle = ""
    @State private var startErrorMessage = ""

    private var currentStepID: UUID? {
        plan.nextStep?.id
    }

    private var progressFraction: Double {
        guard !plan.steps.isEmpty else { return 0 }
        return Double(plan.completedStepCount) / Double(plan.steps.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    progressSection
                    stepsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle(String(localized: "journey.overview.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .preferredColorScheme(.dark)
            .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.07).ignoresSafeArea())
            .alert(startErrorTitle, isPresented: $showStartError) {
                Button(String(localized: "kai.i_understand")) { }
            } message: {
                Text(startErrorMessage)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.title)
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .foregroundStyle(.white)

                    Text(String(format: String(localized: "journey.overview.week_format"), plan.cycleNumber))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.82, green: 0.94, blue: 0.86))
                }

                Spacer()

                Image(systemName: plan.isCompleted ? "checkmark.circle.fill" : "figure.mind.and.body")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(plan.isCompleted ? Color(red: 0.82, green: 0.94, blue: 0.86) : .white.opacity(0.85))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }

            Text(plan.summary)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineSpacing(3)

            Text(plan.goalSummary)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(3)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plan.isCompleted ? String(localized: "journey.overview.progress_complete") : String(localized: "journey.overview.progress"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Text("\(plan.completedStepCount)/\(plan.steps.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.82, green: 0.94, blue: 0.86),
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(proxy.size.width * progressFraction, progressFraction == 0 ? 0 : 24))
                }
            }
            .frame(height: 10)

            if let nextStep = plan.nextStep {
                Text(String(format: String(localized: "journey.overview.next_step_format"), nextStep.dayNumber, nextStep.title))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text(String(localized: "journey.overview.week_complete_detail"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(18)
        .background(sheetCardBackground)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "journey.overview.all_steps"))
                .font(.system(size: 12, weight: .bold))
                .kerning(1.1)
                .foregroundStyle(.white.opacity(0.45))

            ForEach(plan.steps) { step in
                stepCard(for: step)
            }
        }
    }

    private func stepCard(for step: PracticeJourneyStep) -> some View {
        let isCurrent = currentStepID == step.id
        let isCompleted = step.isCompleted
        let reflection = step.completion?.reflection?.trimmingCharacters(in: .whitespacesAndNewlines)
        let checkInSummary = localizedCheckInSummary(for: step.completion?.checkInTags)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(stepBadgeBackground(isCurrent: isCurrent, isCompleted: isCompleted))
                        .frame(width: 38, height: 38)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.75))
                    } else {
                        Text("\(step.dayNumber)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text(step.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.96))

                        Spacer()

                        if isCurrent {
                            statusPill(String(localized: "journey.overview.status_today"), color: .white.opacity(0.18))
                        } else if isCompleted {
                            statusPill(String(localized: "journey.overview.status_done"), color: Color(red: 0.82, green: 0.94, blue: 0.86).opacity(0.22))
                        } else {
                            statusPill(String(localized: "journey.overview.status_ahead"), color: Color.white.opacity(0.08))
                        }
                    }

                    Text(step.focus)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))

                    if isCurrent {
                        Text(step.purpose)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineSpacing(2)
                        infoLine(icon: "sparkles", text: step.adaptationTip)
                        infoLine(icon: "timer", text: String(format: String(localized: "journey.overview.duration_recommended_format"), step.suggestedDurationMinutes))

                        if manager.activePracticeJourneyPlan?.nextStep?.id == step.id {
                            Button {
                                startTodayFromOverview()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(String(localized: "content.today_step.start_practice_cta"))
                                        .font(.system(size: 12, weight: .bold))
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.16))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(manager.isGeneratingGuidedSession)
                            .opacity(manager.isGeneratingGuidedSession ? 0.6 : 1.0)
                        }
                    } else if !checkInSummary.isEmpty {
                        infoLine(icon: "heart.text.square", text: checkInSummary)
                        if let reflection, !reflection.isEmpty {
                            infoLine(icon: "quote.bubble", text: reflection)
                        }
                    } else if let reflection, !reflection.isEmpty {
                        infoLine(icon: "quote.bubble", text: reflection)
                    }
                }
            }
        }
        .padding(18)
        .background(stepCardBackground(isCurrent: isCurrent, isCompleted: isCompleted))
    }

    private func statusPill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func infoLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 14, height: 14)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(2)
        }
    }

    private func localizedCheckInSummary(for tags: [String]?) -> String {
        guard let tags, !tags.isEmpty else { return "" }
        let labels = tags.map { tag in
            Bundle.main.localizedString(forKey: "reflection.check_in.\(tag)", value: tag, table: nil)
        }
        return String(format: String(localized: "journey.overview.check_in_format"), labels.joined(separator: ", "))
    }

    private func stepBadgeBackground(isCurrent: Bool, isCompleted: Bool) -> Color {
        if isCompleted {
            return Color(red: 0.82, green: 0.94, blue: 0.86)
        }

        if isCurrent {
            return Color.white.opacity(0.18)
        }

        return Color.white.opacity(0.08)
    }

    private func stepCardBackground(isCurrent: Bool, isCompleted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                isCurrent
                    ? Color.white.opacity(0.10)
                    : isCompleted
                        ? Color(red: 0.82, green: 0.94, blue: 0.86).opacity(0.08)
                        : Color.white.opacity(0.05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        isCurrent
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }

    private var sheetCardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func startTodayFromOverview() {
        Task {
            do {
                try await manager.startTodayPracticeJourneyStep()
                dismiss()
            } catch {
                if case KaiBrainService.BrainError.serviceUnavailable = error {
                    startErrorTitle = String(localized: "kai.error.not_configured.title")
                    startErrorMessage = String(localized: "kai.error.not_configured.message")
                } else if let urlError = error as? URLError {
                    startErrorTitle = String(localized: "kai.error.connection.title")
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        startErrorMessage = String(localized: "kai.error.connection.offline")
                    case .timedOut:
                        startErrorMessage = String(localized: "kai.error.connection.timeout")
                    default:
                        startErrorMessage = String(localized: "kai.error.connection.generic")
                    }
                } else {
                    startErrorTitle = String(localized: "journey.overview.start_error_title")
                    startErrorMessage = String(localized: "journey.overview.start_error_message")
                }
                showStartError = true
            }
        }
    }
}

struct StatisticsView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    private let milestones: [(icon: String, title: String, desc: String, check: (MeditationManager) -> Bool)] = [
        ("sparkles", "First Light", "First session", { $0.totalSecondsMeditated > 0 }),
        ("sunrise.fill", "Early Riser", "Meditate 5 days", { $0.meditationHistory.values.filter { $0 > 0 }.count >= 5 }),
        ("flame.fill", "Week Warrior", "7-day streak", { $0.bestStreakDays >= 7 }),
        ("hourglass", "One Hour", "1 hour total", { $0.totalSecondsMeditated >= 3600 }),
        ("leaf.fill", "Deep Roots", "20 min session", { $0.bestSessionSeconds >= 1200 }),
        ("flame.circle.fill", "Fortnight", "14-day streak", { $0.bestStreakDays >= 14 }),
        ("drop.fill", "Still Water", "10 hours total", { $0.totalSecondsMeditated >= 36000 }),
        ("moon.stars.fill", "Lunar Cycle", "30-day streak", { $0.bestStreakDays >= 30 }),
        ("bolt.fill", "Marathon", "45 min session", { $0.bestSessionSeconds >= 2700 }),
        ("wind", "Breath Master", "50 hours total", { $0.totalSecondsMeditated >= 180000 }),
        ("sun.max.fill", "Enlightened", "90-day streak", { $0.bestStreakDays >= 90 }),
        ("mountain.2.fill", "Zen Master", "100 hours total", { $0.totalSecondsMeditated >= 360000 }),
    ]

    @State private var selectedMilestone: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // MARK: Milestone Badges (FREE)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(String(localized: "content.milestones"))
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(Array(milestones.enumerated()), id: \.offset) { idx, m in
                                let earned = m.check(manager)
                                Button {
                                    selectedMilestone = idx
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: m.icon)
                                            .font(.title2)
                                            .foregroundStyle(earned
                                                ? Color(hue: 0.13, saturation: 0.8, brightness: 0.95)
                                                : .white.opacity(0.15))
                                        Text(m.title)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(earned ? .white : .white.opacity(0.3))
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(earned
                                                ? Color(hue: 0.13, saturation: 0.6, brightness: 0.3).opacity(0.4)
                                                : Color.white.opacity(0.03))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .alert(
                        selectedMilestone != nil ? milestones[selectedMilestone!].title : "",
                        isPresented: Binding(
                            get: { selectedMilestone != nil },
                            set: { if !$0 { selectedMilestone = nil } }
                        )
                    ) {
                        Button(String(localized: "ui.ok"), role: .cancel) { }
                    } message: {
                        if let idx = selectedMilestone {
                            let m = milestones[idx]
                            let earned = m.check(manager)
                            Text("\(m.desc)\n\(earned ? String(localized: "content.milestone_earned") : String(localized: "content.milestone_keep_going"))")
                        }
                    }

                    VStack(spacing: 8) {
                        Text(String(localized: "content.total_journey"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(2)

                        Text(formatStatTime(manager.totalSecondsMeditated))
                            .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 0) {
                        statCard(
                            icon: "flame.fill",
                            label: String(localized: "stats.streak"),
                            value: String(format: String(localized: "stats.days_format"), manager.currentStreak),
                            color: Color(hue: 0.08, saturation: 0.8, brightness: 0.95)
                        )
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1, height: 40)
                        statCard(
                            icon: "clock.fill",
                            label: String(localized: "stats.daily_avg"),
                            value: formatStatTime(manager.averageSessionSeconds),
                            color: Color(hue: 0.55, saturation: 0.6, brightness: 0.9)
                        )
                    }
                    .padding(.horizontal, 24)

                    weeklyChartSection
                        .padding(.horizontal, 24)

                    recordsSection
                        .padding(.horizontal, 24)

                    heatmapSection
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(String(localized: "nav.journey"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                Color(hue: 0.72, saturation: 0.4, brightness: 0.10)
                    .ignoresSafeArea()
            )
            .preferredColorScheme(.dark)
        }
    }

    // MARK: – Weekly Chart

    private var weeklyChartSection: some View {
        let data = manager.weeklyData
        let maxVal = max(data.map(\.seconds).max() ?? 1, 1)
        let midVal = maxVal / 2

        return VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "content.this_week"))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .bottom, spacing: 0) {
                // Y-axis labels
                VStack(alignment: .trailing) {
                    Text(formatChartTime(maxVal))
                    Spacer()
                    Text(formatChartTime(midVal))
                    Spacer()
                    Text(String(localized: "content.zero_minutes"))
                    // Spacer for day labels below bars
                    Text("")
                        .padding(.top, 6)
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 32)

                // Bars
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(day.seconds > 0
                                    ? Color(hue: 0.55, saturation: 0.6, brightness: 0.8)
                                    : Color.white.opacity(0.06))
                                .frame(height: max(6, CGFloat(day.seconds) / CGFloat(maxVal) * 100))

                            Text(day.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 130)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private func formatChartTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h\(m)" : "\(h)h"
        }
        return "\(mins)m"
    }

    // MARK: – Records

    private var recordsSection: some View {
        HStack(spacing: 0) {
            statCard(
                icon: "trophy.fill",
                label: String(localized: "stats.best_session"),
                value: formatStatTime(manager.bestSessionSeconds),
                color: Color(hue: 0.13, saturation: 0.8, brightness: 0.95)
            )
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 40)
            statCard(
                icon: "crown.fill",
                label: String(localized: "stats.best_streak"),
                value: String(format: String(localized: "stats.days_format"), manager.bestStreakDays),
                color: Color(hue: 0.13, saturation: 0.7, brightness: 0.9)
            )
        }
    }

    // MARK: – Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "content.consistency_map"))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7), spacing: 4) {
                    ForEach(heatmapDates, id: \.self) { date in
                        heatmapSquare(for: date)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }

    // MARK: - Subviews

    private func heatmapSquare(for date: Date) -> some View {
        let seconds = manager.secondsMeditated(on: date)
        let isToday = Calendar.current.isDateInToday(date)

        let color: Color
        if seconds == 0 {
            color = Color.white.opacity(0.04)
        } else if seconds < 300 {
            color = Color(hue: 0.55, saturation: 0.6, brightness: 0.4)
        } else if seconds < 900 {
            color = Color(hue: 0.55, saturation: 0.7, brightness: 0.6)
        } else if seconds < 1800 {
            color = Color(hue: 0.55, saturation: 0.8, brightness: 0.8)
        } else {
            color = Color(hue: 0.55, saturation: 0.9, brightness: 1.0)
        }

        return RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(isToday ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1)
            )
    }

    // MARK: - Helpers

    private var heatmapDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = manager.meditationHistory.keys.compactMap { formatter.date(from: $0) }

        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: today)!
        let earliest = dates.min() ?? ninetyDaysAgo
        let baseStart = min(earliest, ninetyDaysAgo)

        let weekday = calendar.component(.weekday, from: baseStart)
        let paddedStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: baseStart)!

        let components = calendar.dateComponents([.day], from: paddedStart, to: today)
        let dayCount = components.day ?? 0

        return (0...dayCount).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: paddedStart)
        }
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatStatTime(_ seconds: Int) -> String {
        if seconds == 0 { return "0m" }
        if seconds < 60 { return "< 1m" }

        let mins = seconds / 60
        let hours = mins / 60
        let remainingMins = mins % 60

        if hours > 0 {
            if remainingMins > 0 {
                return "\(hours)h \(remainingMins)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Technique Library View

struct TechniqueLibraryView: View {
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
                            if !storeManager.isPurchased(StoreKitManager.techniqueLibraryID) {
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
        let isLocked = technique.isPurchasable && !storeManager.isPurchased(StoreKitManager.techniqueLibraryID)
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
    @State private var selectedOnboardingPersonalityID: String? = nil
    
    let pages = [
        OnboardingPage(
            titleKey: "onboarding.page1.title",
            descriptionKey: "onboarding.page1.description",
            systemImage: "circle.dotted"
        ),
        OnboardingPage(
            titleKey: "onboarding.page2.title",
            descriptionKey: "onboarding.page2.description",
            systemImage: "wind"
        ),
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
            titleKey: "onboarding.page5.title",
            descriptionKey: "onboarding.page5.description",
            systemImage: "speaker.wave.3.fill"
        ),
        OnboardingPage(
            titleKey: "onboarding.page6.title",
            descriptionKey: "onboarding.page6.description",
            systemImage: "mic.fill"
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
                                    Image(personality.imageName)
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
