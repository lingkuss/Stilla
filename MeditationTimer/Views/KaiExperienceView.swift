import SwiftUI
import Speech

struct KaiExperienceView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    @State private var moodText: String = ""
    @State private var selectedDuration: Int = 10
    @State private var isGenerating: Bool = false
    @State private var kaiPulse: Bool = false
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
            .onAppear {
                // Initial pulse state
            }
        }
    }
    
    private var mainInputView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Intro
                VStack(spacing: 12) {
                    Text("How are you feeling?")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .italic()
                    Text("Speak or type your mood. Kai will curate your path.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                
                // Voice / Text Input Box
                VStack(spacing: 24) {
                    ZStack(alignment: .topTrailing) {
                        TextField("e.g. Anxious about tomorrow's presentation...", text: $moodText, axis: .vertical)
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
                            Button { moodText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.2))
                                    .padding(16)
                            }
                        }
                    }
                    
                    // Voice Button & Aura
                    ZStack {
                        // Breathing Aura (Visible when recording)
                        if speechManager.isRecording {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 120, height: 120)
                                .scaleEffect(kaiPulse ? 1.4 : 0.8)
                                .opacity(kaiPulse ? 0.0 : 0.4)
                            
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .scaleEffect(kaiPulse ? 1.2 : 0.9)
                        }
                        
                        Button {
                            if speechManager.isRecording {
                                speechManager.stopRecording()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } else {
                                do {
                                    speechManager.requestPermissions()
                                    try speechManager.startRecording()
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                        kaiPulse = true
                                    }
                                } catch {
                                    showingError = true
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(speechManager.isRecording ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                                    .frame(width: 72, height: 72)
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                                
                                Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)
                    
                    Text(speechManager.isRecording ? "Listening to your heart..." : "Tap to Speak")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                
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
                                    moodText = preset
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    Text(preset)
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule()
                                                .fill(moodText == preset ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                                .overlay(Capsule().strokeBorder(Color.white.opacity(moodText == preset ? 0.3 : 0.05), lineWidth: 1))
                                        }
                                        .foregroundStyle(moodText == preset ? .white : .white.opacity(0.6))
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
                    
                    HStack(spacing: 12) {
                        ForEach([5, 10, 30], id: \.self) { mins in
                            Button {
                                selectedDuration = mins
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text("\(mins)m")
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
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
                .disabled(moodText.isEmpty)
                .opacity(moodText.isEmpty ? 0.3 : 1.0)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
        }
        .alert("Kai is resting", isPresented: $showingError) {
            Button("I understand") { }
        } message: {
            Text("I'm having trouble aligning your path right now. Please check your internet connection or try again in a moment.")
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
                        .offset(x: isGenerating ? CGFloat.random(in: -30...30) : 0, y: isGenerating ? CGFloat.random(in: -30...30) : 0)
                        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(Double(i) * 0.5), value: isGenerating)
                }
                
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 140, height: 140)
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
            do {
                let script = try await KaiBrainService.shared.generateScript(
                    mood: moodText.isEmpty ? "Calm" : moodText,
                    durationMinutes: selectedDuration
                )
                
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
                showingError = true
                isGenerating = false
            }
        }
    }
}
