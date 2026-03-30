import SwiftUI
import Speech

struct KaiExperienceView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    @State private var moodText: String = ""
    @State private var selectedDuration: Int = 10
    @State private var isGenerating: Bool = false
    @State private var showingError: Bool = false
    
    private let speechManager = SpeechManager.shared
    
    private let presets = [
        "Deep Stress", "Sleep Prep", "Creative Flow", 
        "Morning Spark", "Anxiety Calm", "Grateful Heart"
    ]
    
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
            .navigationTitle("Kai Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
            .onChange(of: speechManager.transcription) { _, newValue in
                if !newValue.isEmpty {
                    moodText = newValue
                }
            }
        }
    }
    
    private var mainInputView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Intro
                VStack(spacing: 8) {
                    Text("How are you feeling, truly?")
                        .font(.title2.weight(.medium))
                    Text("Speak or type your mood. Kai will create your session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                
                // Voice / Text Input Box
                VStack(spacing: 16) {
                    ZStack(alignment: .topTrailing) {
                        TextField("e.g. Anxious about tomorrow's presentation...", text: $moodText, axis: .vertical)
                            .lineLimit(4...8)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        
                        if !moodText.isEmpty {
                            Button { moodText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                            }
                        }
                    }
                    
                    // Voice Button
                    Button {
                        if speechManager.isRecording {
                            speechManager.stopRecording()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } else {
                            do {
                                speechManager.requestPermissions()
                                try speechManager.startRecording()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } catch {
                                showingError = true
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text(speechManager.isRecording ? "Listening..." : "Speak Mood")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(speechManager.isRecording ? Color.red.opacity(0.3) : Color.blue.opacity(0.3))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(speechManager.isRecording ? Color.red.opacity(0.5) : Color.blue.opacity(0.5), lineWidth: 1)
                        )
                        .scaleEffect(speechManager.isRecording ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speechManager.isRecording)
                    }
                }
                .padding(.horizontal, 24)
                
                // Presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Or choose a preset")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    moodText = preset
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Text(preset)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Capsule().strokeBorder(Color.white.opacity(moodText == preset ? 0.4 : 0.1), lineWidth: 1))
                                        .background(Capsule().fill(Color.white.opacity(moodText == preset ? 0.1 : 0.05)))
                                        .foregroundStyle(moodText == preset ? .white : .white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                    
                    HStack(spacing: 12) {
                        ForEach([5, 10, 30], id: \.self) { mins in
                            Button {
                                selectedDuration = mins
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text("\(mins)m")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(selectedDuration == mins ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(Color.white.opacity(selectedDuration == mins ? 0.3 : 0.1), lineWidth: 1)
                                    )
                                    .foregroundStyle(selectedDuration == mins ? .white : .white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // Generate Button
                Button {
                    generateMeditation()
                } label: {
                    Text("Create Meditation")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(.white))
                        .padding(.horizontal, 24)
                }
                .disabled(moodText.isEmpty)
                .opacity(moodText.isEmpty ? 0.5 : 1.0)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var generatingView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Breathing Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isGenerating ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isGenerating)
            }
            
            VStack(spacing: 12) {
                Text("Kai is crafting your path...")
                    .font(.title3.weight(.medium))
                Text("Aligning your mood with your breath.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            
            Spacer()
            Spacer()
        }
    }
    
    private func generateMeditation() {
        isGenerating = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        Task {
            do {
                let script = try await KaiBrainService.shared.generateScript(
                    mood: moodText.isEmpty ? "Calm" : moodText,
                    durationMinutes: selectedDuration
                )
                
                // Set the script in GuruManager and start
                GuruManager.shared.play(script: script)
                
                // Update MeditationManager state
                manager.durationMinutes = selectedDuration
                manager.isGuruEnabled = true
                manager.start()
                
                dismiss()
            } catch {
                showingError = true
                isGenerating = false
            }
        }
    }
}
