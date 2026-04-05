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
    @State private var errorTitle = "Kai is resting"
    @State private var errorMessage = "I'm having trouble aligning your path right now. Please check your internet connection or try again in a moment."
    @State private var pickedSuggestion: String? = nil
    @State private var suggestionWasPicked = false
    @State private var stillnessRatio: Double = 0.5
    @State private var showingStillnessInfo = false
    
    private let speechManager = SpeechManager.shared
    
    private let presets = [
        "Creative Flow", "Deep Stress", "Sleep Prep",
        "Morning Spark", "Anxiety Calm", "Grateful Heart",
        "Focus Reset", "Body Ease", "Confidence Boost",
        "Gentle Clarity", "Evening Unwind", "Self-Compassion"
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
                        TextField("Speak or type your mood. Kai will curate your path.", text: $moodText, axis: .vertical)
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
                                                errorTitle = "Voice Input Unavailable"
                                                errorMessage = "Voice input isn't available right now. Please type your mood instead."
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
                        Text("Listening to your heart...")
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
                    Text("INTENTIONS")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 24)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    if selectedIntention == preset {
                                        selectedIntention = nil
                                    } else {
                                        selectedIntention = preset
                                    }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Text(preset)
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule()
                                                .fill(selectedIntention == preset ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                                .overlay(Capsule().strokeBorder(Color.white.opacity(selectedIntention == preset ? 0.3 : 0.05), lineWidth: 1))
                                        }
                                        .foregroundStyle(selectedIntention == preset ? .white : .white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 16) {
                    Text("DURATION")
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
                                    Text("\(mins)m")
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
                    }
                }
                
                // Stillness Ratio
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text("STILLNESS RATIO")
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
                            Text("Continuous Guidance")
                            Spacer()
                            Text("Deep Stillness")
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
                    Text("Create Meditation")
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
            Button("I understand") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Open Settings?", isPresented: $showingSettingsPrompt) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("About Stillness", isPresented: $showingStillnessInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("This slider controls how much silence Kai provides. At lower levels, Kai gives constant guidance. At higher levels, Kai steps back to give you long, quiet stretches of stillness.")
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
                Text("Kai is crafting your path")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .italic()
                Text("Aligning your heart with your breath.")
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
            
            let isSubscribed = StoreKitManager.shared.isKAISubscribed
            let isFreeAvailable = KaiBrainService.shared.isFreeGenerationAvailable
            
            if !isSubscribed && !isFreeAvailable {
                isGenerating = false
                showingPaywall = true
                return
            }
            
            do {
                var combinedMood = ""
                if let intention = selectedIntention {
                    combinedMood += "Intention: \(intention). "
                }
                if !moodText.isEmpty {
                    combinedMood += "Mood/Details: \(moodText)"
                }

                manager.pendingKaiMoodSummary = moodText.isEmpty ? nil : moodText
                manager.pendingKaiIntention = selectedIntention

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
                script.kaiPersonalityName = activePersonality.name
                
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
                    errorTitle = "Kai Not Configured"
                    errorMessage = "Kai is not configured for production yet. Add your backend URL before requesting personalized sessions."
                } else if let urlError = error as? URLError {
                    errorTitle = "Connection Problem"
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        errorMessage = "You're offline. Reconnect to the internet and try generating your Kai session again."
                    case .timedOut:
                        errorMessage = "Kai took too long to respond. Please try again in a moment."
                    default:
                        errorMessage = "Kai couldn't be reached right now. Please try again shortly."
                    }
                } else {
                    errorTitle = "Kai is resting"
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
                        Text("CHOOSE YOUR KAI")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.white.opacity(0.4))

                        Text(activePersonality.name)
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
                        Text("KAI SUGGESTIONS")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Tap one to auto-fill your mood")
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

    private var statusBadge: some View {
        Group {
            if store.isKAISubscribed {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Text("KAI PRO MEMBER")
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
                        return n > 0 ? "\(n) FREE CREDIT\(n == 1 ? "" : "S")" : "0 CREDITS REMAINING"
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

            Button("Close") { dismiss() }
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
                    Text(personality.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                Text(personality.shortDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.62))

                HStack(spacing: 8) {
                    ForEach(personality.traits, id: \.self) { trait in
                        Text(trait)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.06)))
                    }
                }

                Text("“\(personality.sampleLine)”")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.74))
                    .lineSpacing(3)

                Text(personality.longDescription)
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
