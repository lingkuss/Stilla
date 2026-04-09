import SwiftUI
import Speech
import Foundation
import UIKit

struct KaiExperienceView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    @State private var store = StoreKitManager.shared
    @State private var moodText: String = ""
    @State private var selectedIntention: String? = nil
    @State private var selectedDuration: Int = 10
    @State private var isGenerating: Bool = false
    @State private var kaiPulse: Bool = false
    @State private var showingError: Bool = false
    @State private var showingPaywall: Bool = false
    @State private var showingSettingsPrompt: Bool = false
    @State private var isPersonalityPickerExpanded = false
    @State private var rotationAmount: Double = 0.0
    @State private var pulseAmount: Double = 0.0
    @State private var errorTitle = String(localized: "kai.error.resting.title")
    @State private var errorMessage = String(localized: "kai.error.resting.message")
    @State private var pickedSuggestion: String? = nil
    @State private var suggestionWasPicked = false
    @State private var stillnessRatio: Double = 0.5
    @State private var showingStillnessInfo = false
    
    private let speechManager = SpeechManager.shared
    
    private let intentionKeys = [
        "intention.creative_flow", "intention.deep_stress", "intention.sleep_prep",
        "intention.morning_spark", "intention.anxiety_calm", "intention.grateful_heart",
        "intention.focus_reset", "intention.body_ease", "intention.confidence_boost",
        "intention.gentle_clarity", "intention.evening_unwind", "intention.self_compassion"
    ]

    private var availablePersonalities: [KaiPersonality] {
        KaiPersonality.all
    }

    private var activePersonality: KaiPersonality {
        manager.selectedKaiPersonality
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hue: 0.72, saturation: 0.4, brightness: 0.05)
                    .ignoresSafeArea()
                
                if isGenerating {
                    generatingView
                } else {
                    mainInputView
                }
            }
            .overlay(alignment: .top) {
                kaiTopBar
            }
            .preferredColorScheme(.dark)
            .onChange(of: speechManager.transcription) { _, newValue in
                if !newValue.isEmpty {
                    moodText = newValue
                }
            }
            .onAppear {
                if manager.isSiriTriggeredKai {
                    if let mood = manager.siriPendingMood {
                        moodText = mood
                    }
                    if let duration = manager.siriPendingDuration {
                        selectedDuration = duration
                    }
                    
                    // Reset the flags so we don't re-trigger
                    manager.isSiriTriggeredKai = false
                    manager.siriPendingMood = nil
                    manager.siriPendingDuration = nil
                    
                    // Trigger generation
                    generateMeditation()
                }

                stillnessRatio = manager.preferredStillnessRatio
                isPersonalityPickerExpanded = false
            }
            .sheet(isPresented: $showingPaywall) {
                KAIPaywallView()
            }
        }
    }
    
    private var mainInputView: some View {
        ScrollView {
            VStack(spacing: 24) {
                personalitySection
                
                // Voice / Text Input Box
                VStack(spacing: 24) {
                    ZStack(alignment: .topTrailing) {
                        TextField(String(localized: "kai.mood_input_placeholder"), text: $moodText, axis: .vertical)
                            .lineLimit(4...8)
                            .padding(24)
                            .background {
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 32)
                                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            }

                        if !moodText.isEmpty {
                            Button {
                                moodText = ""
                                pickedSuggestion = nil
                                suggestionWasPicked = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.2))
                                    .padding(16)
                            }
                        }

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    if speechManager.isRecording {
                                        speechManager.stopRecording()
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    } else {
                                        if suggestionWasPicked {
                                            moodText = ""
                                            pickedSuggestion = nil
                                            suggestionWasPicked = false
                                        }
                                        Task {
                                            do {
                                                try await speechManager.requestPermissions()
                                                try speechManager.startRecording()
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                                    kaiPulse = true
                                                }
                                            } catch let speechError as SpeechManager.SpeechError {
                                                errorMessage = speechError.localizedDescription
                                                showingSettingsPrompt = true
                                            } catch {
                                                errorTitle = String(localized: "alerts.voice_input_unavailable")
                                                errorMessage = String(localized: "kai.voice_input_unavailable_type_mood")
                                                showingError = true
                                            }
                                        }
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(speechManager.isRecording ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                                            .frame(width: 44, height: 44)
                                            .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))

                                        Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                            .font(.system(size: 18, weight: .light))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(16)
                            }
                        }
                    }
                    
                    suggestionOptionsView

                    if speechManager.isRecording {
                        Text(String(localized: "kai.listening"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .onChange(of: moodText) { _, newValue in
                    guard suggestionWasPicked else { return }
                    if let currentSuggestion = pickedSuggestion, newValue != currentSuggestion {
                        suggestionWasPicked = false
                        pickedSuggestion = nil
                    }
                }
                
                // Presets
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "kai.intentions"))
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 24)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(intentionKeys, id: \.self) { intentionKey in
                                Button {
                                    if selectedIntention == intentionKey {
                                        selectedIntention = nil
                                    } else {
                                        selectedIntention = intentionKey
                                    }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Text(localizedIntention(intentionKey))
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule()
                                                .fill(selectedIntention == intentionKey ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                                .overlay(Capsule().strokeBorder(Color.white.opacity(selectedIntention == intentionKey ? 0.3 : 0.05), lineWidth: 1))
                                        }
                                        .foregroundStyle(selectedIntention == intentionKey ? .white : .white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "kai.duration"))
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 24)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Filter out 0 (Infinite) as Kai requires a structured script duration
                            ForEach(manager.allDurations.filter { $0 > 0 }, id: \.self) { mins in
                                Button {
                                    selectedDuration = mins
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Text(String(format: String(localized: "kai.duration_minutes_format"), mins))
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(minWidth: 64)
                                        .padding(.vertical, 14)
                                        .background {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(selectedDuration == mins ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(selectedDuration == mins ? 0.2 : 0.05), lineWidth: 1))
                                        }
                                        .foregroundStyle(selectedDuration == mins ? .white : .white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                // Stillness Ratio
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text(String(localized: "kai.stillness_ratio"))
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Button {
                            showingStillnessInfo = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 8) {
                        Slider(value: $stillnessRatio, in: 0.01...0.99, step: 0.01)
                            .tint(.white.opacity(0.3))
                        
                        HStack {
                            Text(String(localized: "kai.continuous_guidance"))
                            Spacer()
                            Text(String(localized: "kai.deep_stillness"))
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .kerning(1)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.04))
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                
                // Generate Button
                Button {
                    generateMeditation()
                } label: {
                    Text(String(localized: "kai.create_meditation"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Capsule().fill(.white))
                        .padding(.horizontal, 24)
                        .shadow(color: .white.opacity(0.1), radius: 20, x: 0, y: 10)
                }
                .disabled(moodText.isEmpty && selectedIntention == nil)
                .opacity((moodText.isEmpty && selectedIntention == nil) ? 0.3 : 1.0)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
            .padding(.top, 68)
        }
        .alert(errorTitle, isPresented: $showingError) {
            Button(String(localized: "kai.i_understand")) { }
        } message: {
            Text(errorMessage)
        }
        .alert(String(localized: "alerts.open_settings"), isPresented: $showingSettingsPrompt) {
            Button(String(localized: "kai.open_settings")) {
                openAppSettings()
            }
            Button(String(localized: "ui.cancel"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert(String(localized: "alerts.about_stillness"), isPresented: $showingStillnessInfo) {
            Button(String(localized: "ui.got_it"), role: .cancel) { }
        } message: {
            Text(String(localized: "kai.stillness_help"))
        }
    }
    
    private var generatingView: some View {
        VStack(spacing: 48) {
            Spacer()

            // Spirit Animation
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .blur(radius: 40)
                        .scaleEffect(0.8 + (pulseAmount * 0.4))
                        .offset(x: CGFloat(sin(Double(i) * 2.0 + rotationAmount * Double.pi / 180.0) * 20.0),
                                y: CGFloat(cos(Double(i) * 2.0 + rotationAmount * Double.pi / 180.0) * 20.0))
                }

                Circle()
                    .stroke(
                        AngularGradient(colors: [.white.opacity(0.0), .white.opacity(0.3), .white.opacity(0.0)], center: .center),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(rotationAmount))

                Image(activePersonality.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 96)
                    .clipped()
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    rotationAmount = 360.0
                }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    pulseAmount = 1.0
                }
            }

            VStack(spacing: 16) {
                Text(loadingHeadline)
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .italic()
                Text(loadingSubheadline)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .multilineTextAlignment(.center)

            Spacer()
            Spacer()
        }
    }
    
    @MainActor
    private func generateMeditation() {
        isGenerating = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        Task {
            // Entitlement Check
            await StoreKitManager.shared.updateCustomerProductStatus()
            
            let isSubscribed = StoreKitManager.shared.isVindlaProSubscribed
            let isFreeAvailable = KaiBrainService.shared.isFreeGenerationAvailable
            
            if !isSubscribed && !isFreeAvailable {
                isGenerating = false
                showingPaywall = true
                return
            }
            
            do {
                var combinedMood = ""
                if let intentionKey = selectedIntention {
                    let intentionText = localizedIntention(intentionKey)
                    combinedMood += "Intention: \(intentionText). "
                }
                if !moodText.isEmpty {
                    combinedMood += "Mood/Details: \(moodText)"
                }

                manager.pendingKaiMoodSummary = moodText.isEmpty ? nil : moodText
                manager.pendingKaiIntention = selectedIntention.map(localizedIntention)

                if let memoryContext = memoryContextString() {
                    if combinedMood.isEmpty {
                        combinedMood = "Memory context: \(memoryContext)"
                    } else {
                        combinedMood += " Recent memory: \(memoryContext)"
                    }
                }
                
                var script = try await KaiBrainService.shared.generateScript(
                    mood: combinedMood.isEmpty ? "Calm" : combinedMood,
                    durationMinutes: selectedDuration,
                    personality: activePersonality,
                    stillnessRatio: stillnessRatio
                )
                
                // Persist choice
                manager.preferredStillnessRatio = stillnessRatio
                script.kaiPersonalityID = activePersonality.id
                script.kaiPersonalityName = activePersonality.localizedName
                
                // If we got here and weren't subscribed, consume the free credit
                if !isSubscribed {
                    KaiBrainService.shared.recordFreeGeneration()
                }
                
                // Set the script in GuruManager and start
                GuruManager.shared.play(script: script)
                
                // Track current script for saving later
                manager.currentScript = script
                
                // Update MeditationManager state
                manager.durationMinutes = selectedDuration
                manager.isGuruEnabled = true
                manager.start(durationMinutes: selectedDuration)
                
                dismiss()
            } catch {
                if case KaiBrainService.BrainError.serviceUnavailable = error {
                    errorTitle = "Mimir Not Configured"
                    errorMessage = "Mimir is not configured for production yet. Add your backend URL before requesting personalized sessions."
                } else if let urlError = error as? URLError {
                    errorTitle = "Connection Problem"
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        errorMessage = "You're offline. Reconnect to the internet and try generating your Mimir session again."
                    case .timedOut:
                        errorMessage = "Mimir took too long to respond. Please try again in a moment."
                    default:
                        errorMessage = "Mimir couldn't be reached right now. Please try again shortly."
                    }
                } else {
                    errorTitle = String(localized: "kai.error.resting.title")
                    errorMessage = "I'm having trouble aligning your path right now. Please check your internet connection or try again in a moment."
                }
                showingError = true
                isGenerating = false
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPersonalityPickerExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    Image(activePersonality.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 58, height: 58)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "kai.choose_your_mimir"))
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.white.opacity(0.4))

                        Text(activePersonality.localizedName)
                            .font(.system(size: 22, weight: .light, design: .serif))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .rotationEffect(.degrees(isPersonalityPickerExpanded ? 180 : 0))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            if isPersonalityPickerExpanded {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(availablePersonalities) { personality in
                                Button {
                                    select(personality)
                                } label: {
                                    KaiPersonalityCard(
                                        personality: personality,
                                        isSelected: activePersonality.id == personality.id,
                                        isLocked: false
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(personality.id)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .onAppear {
                        scrollToActivePersonality(using: proxy, animated: false)
                    }
                    .onChange(of: activePersonality.id) { _, _ in
                        scrollToActivePersonality(using: proxy)
                    }
                }
            }
        }
    }

    private func select(_ personality: KaiPersonality) {
        manager.selectedKaiPersonalityID = personality.id
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func scrollToActivePersonality(using proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            proxy.scrollTo(activePersonality.id, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                action()
            }
        } else {
            action()
        }
    }

    private var suggestionOptionsView: some View {
        let suggestions = manager.latestSessionMemory?.suggestionOptions ?? []
        return Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "kai.mimir_suggestions"))
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(String(localized: "kai.tap_to_autofill_mood"))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 4)

                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            moodText = suggestion
                            pickedSuggestion = suggestion
                            suggestionWasPicked = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(suggestion)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
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

    private func memoryContextString() -> String? {
        let memories = Array(manager.recentSessionMemories.prefix(3))
        guard !memories.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let entries: [String] = memories.map { memory in
            var parts: [String] = []
            parts.append(formatter.string(from: memory.startedAt))
            parts.append("\(max(1, memory.durationMinutesRounded))m")
            if let intention = memory.intention { parts.append("Intention: \(intention)") }
            if let mood = memory.moodSummary { parts.append("Mood: \(mood)") }
            if let reflection = memory.reflection { parts.append("Reflection: \(reflection)") }
            return parts.joined(separator: " | ")
        }
        return entries.joined(separator: " || ")
    }

    private func localizedIntention(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    private var loadingHeadline: String {
        switch activePersonality.id {
        case "zen_minimalist":
            return String(localized: "kai.loading.headline.zen_minimalist")
        case "warm_guardian":
            return String(localized: "kai.loading.headline.warm_guardian")
        case "modern_realist":
            return String(localized: "kai.loading.headline.modern_realist")
        case "cosmic_sage":
            return String(localized: "kai.loading.headline.cosmic_sage")
        case "reflective_analyst":
            return String(localized: "kai.loading.headline.reflective_analyst")
        case "philosopher":
            return String(localized: "kai.loading.headline.philosopher")
        case "ra":
            return String(localized: "kai.loading.headline.ra")
        case "shadow_guide":
            return String(localized: "kai.loading.headline.shadow_guide")
        default:
            return String(localized: "kai.loading.headline.default")
        }
    }

    private var loadingSubheadline: String {
        switch activePersonality.id {
        case "zen_minimalist":
            return String(localized: "kai.loading.subheadline.zen_minimalist")
        case "warm_guardian":
            return String(localized: "kai.loading.subheadline.warm_guardian")
        case "modern_realist":
            return String(localized: "kai.loading.subheadline.modern_realist")
        case "cosmic_sage":
            return String(localized: "kai.loading.subheadline.cosmic_sage")
        case "reflective_analyst":
            return String(localized: "kai.loading.subheadline.reflective_analyst")
        case "philosopher":
            return String(localized: "kai.loading.subheadline.philosopher")
        case "ra":
            return String(localized: "kai.loading.subheadline.ra")
        case "shadow_guide":
            return String(localized: "kai.loading.subheadline.shadow_guide")
        default:
            return String(localized: "kai.loading.subheadline.default")
        }
    }

    private var statusBadge: some View {
        Group {
            if store.isVindlaProSubscribed {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Text(String(localized: "kai.pro_member"))
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.blue.opacity(0.1)))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text({
                        let n = KaiBrainService.shared.freeCreditsRemaining
                        return n > 0
                            ? String(format: String(localized: "kai.free_credits_remaining_format"), n)
                            : String(localized: "kai.zero_credits_remaining")
                    }())
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
            }
        }
    }

    private var kaiTopBar: some View {
        HStack {
            statusBadge

            Spacer()

            Button(String(localized: "ui.close")) { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(hue: 0.72, saturation: 0.4, brightness: 0.05),
                    Color(hue: 0.72, saturation: 0.4, brightness: 0.05).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct KaiPersonalityCard: View {
    let personality: KaiPersonality
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Image(personality.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 250, height: 186)
                    .clipped()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    }

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(.black.opacity(0.28)))
                        .padding(12)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(personality.localizedName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                Text(personality.localizedShortDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.62))

                HStack(spacing: 8) {
                    ForEach(personality.localizedTraits, id: \.self) { trait in
                        Text(trait)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.06)))
                    }
                }

                Text("“\(personality.localizedSampleLine)”")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.74))
                    .lineSpacing(3)

                Text(personality.localizedLongDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineSpacing(3)
            }
        }
        .frame(width: 250, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(isSelected ? Color.white.opacity(0.09) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(isSelected ? .white.opacity(0.22) : .white.opacity(0.06), lineWidth: 1)
                )
        )
    }

}
