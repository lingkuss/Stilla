import SwiftUI

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
    @State private var kaiShimmer = false
    @State private var kaiPulse = false
    @State private var currentPhase = ""
    @State private var showSavedMeditations = false
    @State private var reflectionSheetContext: ReflectionSheetContext?
    @State private var showSleepStoryCompletion = false
    @State private var storeManager = StoreKitManager.shared
    @AppStorage("homeViewMode") private var homeViewMode = HomeViewMode.hero

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

                if manager.state == .idle {
                    if homeViewMode == .hero {
                        heroView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    } else {
                        timerView
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                } else {
                    // Always show timer view when active
                    timerView
                        .transition(.opacity)
                }

                Spacer()

                // Action button & Siri hint
                VStack(spacing: 16) {
                    if homeViewMode == .timer || manager.state != .idle {
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
                }
                .padding(.bottom, 16)
                .layoutPriority(1)
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

    private var guidedSessionLoadingOverlay: some View {
        ZStack {
            Color(hue: 0.72, saturation: 0.4, brightness: 0.05)
                .ignoresSafeArea()

            KaiGeneratingLoadingView(personality: manager.selectedKaiPersonality)
        }
        .allowsHitTesting(true)
    }

    // MARK: - Redesign Home Views

    private var heroView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 1. Large Persona Portrait (Middle)
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 240, height: 240)
                    .overlay(
                        Circle()
                            .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                
                Image(manager.selectedKaiPersonality.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 220, height: 220)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .scaleEffect(kaiPulse ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: kaiPulse)
            
            // 3. Message Citation (Under the image)
            VStack(spacing: 16) {
                Text("“\(latestKaiBody)”")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 60)
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
            }
            
            Spacer()
            
            // 4. Primary Action Button
            Button(action: { 
                showKaiExperience = true 
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text(String(localized: "content.start_mimir_journey"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .background {
                    Capsule()
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .indigo.opacity(0.3), radius: 15, x: 0, y: 8)
                }
            }
            .buttonStyle(.plain)

            Button(action: {
                showSleepStories = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(localized: "content.start_sleep_stories"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .onAppear {
            kaiPulse = true
        }
    }

    private var timerView: some View {
        VStack(spacing: 0) {
            // Kai Experience Promo Card (RESTORED FULL PREMIUM VERSION)
            if manager.state == .idle {
                Button(action: { 
                    showKaiExperience = true 
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    VStack(alignment: .leading, spacing: 6) { 
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                Text(String(localized: "content.personalized_hint"))
                                    .font(.system(size: 9, weight: .bold))
                                    .kerning(1)
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(latestKaiHeader)
                                .font(.system(size: 16, weight: .light, design: .serif))
                                .italic()
                                .foregroundStyle(.white)
                            
                            Text(latestKaiBody)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                            
                            LinearGradient(
                                colors: [.indigo.opacity(0.2), .purple.opacity(0.05), .clear],
                                startPoint: kaiShimmer ? .topLeading : .bottomTrailing,
                                endPoint: kaiShimmer ? .bottomTrailing : .topLeading
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: kaiShimmer)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .scaleEffect(kaiPulse ? 1.01 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: kaiPulse)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .onAppear {
                    kaiShimmer = true
                    kaiPulse = true
                }

                Button(action: {
                    showSleepStories = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(String(localized: "content.sleep_stories_hint"))
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            
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
}

// MARK: - Statistics View

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
                Section("Name") {
                    TextField(String(localized: "content.custom_name_placeholder"), text: $name)
                }

                Section("Timings") {
                    timingRow(title: "Inhale", value: $inhale)
                    timingRow(title: "Hold (In)", value: $holdIn)
                    timingRow(title: "Exhale", value: $exhale)
                    timingRow(title: "Hold (Out)", value: $holdOut)
                }

                Section {
                    Button(String(localized: "content.add_technique")) {
                        let new = BreathingTechnique(
                            id: UUID().uuidString,
                            name: name.isEmpty ? "Custom" : name,
                            description: "Custom user technique.",
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
