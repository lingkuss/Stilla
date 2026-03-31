import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var manager = manager

        NavigationStack {
            List {
                // Sounds
                Section {
                    NavigationLink {
                        SoundSelectionView(mode: .start)
                    } label: {
                        HStack {
                            Text("Start Sound")
                            Spacer()
                            Text(manager.startSound.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        SoundSelectionView(mode: .end)
                    } label: {
                        HStack {
                            Text("End Sound")
                            Spacer()
                            Text(manager.endSound.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Chimes", systemImage: "bell.fill")
                }

                // Ambient
                Section {
                    NavigationLink {
                        SoundSelectionView(mode: .ambience)
                    } label: {
                        HStack {
                            Text("Ambience")
                            Spacer()
                            Text(manager.ambientSound.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("During Meditation", systemImage: "waveform")
                } footer: {
                    Text("Plays gentle rain or binaural beats during your session")
                }

                // Volume Mix
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chimes & Cues")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.1")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                            
                            Slider(value: Bindable(manager).toneVolume, in: 0...1) { editing in
                                if !editing { manager.soundEngine.playSound(manager.startSound) }
                            }
                            
                            Image(systemName: "speaker.wave.3")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ambience")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.1")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                            
                            Slider(value: Bindable(manager).ambientVolume, in: 0...1) { editing in
                                if !editing { manager.soundEngine.startAmbientSound(manager.ambientSound) }
                            }
                            
                            Image(systemName: "speaker.wave.3")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Volume Mix", systemImage: "slider.horizontal.3")
                } footer: {
                    Text("Balance the levels of your meditation tones against your continuous ambient sounds.")
                }

                // Haptics
                Section {
                    Toggle(isOn: $manager.hapticEnabled) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }

                    Picker(selection: $manager.breathingCueMode) {
                        ForEach(MeditationManager.BreathingCueMode.allCases, id: \.self) { mode in
                            let needsIAP = (mode == .sound || mode == .both)
                            let locked = needsIAP && !StoreKitManager.shared.isPurchased(StoreKitManager.techniqueLibraryID)
                            if locked {
                                Label(mode.rawValue, systemImage: "lock.fill").tag(mode)
                            } else {
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Label("Breathing Cues", systemImage: "metronome.fill")
                    }
                } header: {
                    Label("Feedback", systemImage: "hand.tap.fill")
                } footer: {
                    if !StoreKitManager.shared.isPurchased(StoreKitManager.techniqueLibraryID) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sound cues require the Technique Library unlock")
                            
                            Button {
                                Task {
                                    await StoreKitManager.shared.purchase(StoreKitManager.techniqueLibraryID)
                                }
                            } label: {
                                Text("Unlock for $1.99")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color(hue: 0.55, saturation: 0.6, brightness: 0.7))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Subtle breath sounds at each inhale and exhale transition")
                    }
                }

                // Daily Reminder
                Section {
                    Toggle(isOn: $manager.dailyReminderEnabled) {
                        Label("Daily Reminder", systemImage: "clock.badge.checkmark.fill")
                    }
                    .onChange(of: manager.dailyReminderEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationManager.shared.requestAuthorization()
                                if !granted {
                                    manager.dailyReminderEnabled = false
                                } else {
                                    manager.updateDailyReminder()
                                }
                            }
                        } else {
                            manager.updateDailyReminder()
                        }
                    }

                    if manager.dailyReminderEnabled {
                        DatePicker("Reminder Time", selection: $manager.dailyReminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: manager.dailyReminderTime) { _, _ in
                                manager.updateDailyReminder()
                            }
                    }
                } header: {
                    Label("Mindfulness", systemImage: "sparkles")
                } footer: {
                    Text("Receive a gentle notification to help you stay consistent.")
                }

                // Kai's Voice
                Section {
                    NavigationLink {
                        VoiceSelectionView()
                    } label: {
                        HStack {
                            Label("Kai's Voice", systemImage: "quote.bubble.fill")
                            Spacer()
                            if let voice = AVSpeechSynthesisVoice(identifier: manager.kaiVoiceIdentifier) {
                                Text(voice.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Voice Guide", systemImage: "person.wave.2.fill")
                } footer: {
                    Text("Choose a high-quality natural voice for Kai.")
                }

                // Siri Tips
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        voiceCommandRow("\"Hey Siri, begin MeditationTimer\"", desc: "Begin with saved duration")
                        voiceCommandRow("\"Hey Siri, meditate for X minutes\"", desc: "Begin with custom duration")
                        voiceCommandRow("\"Hey Siri, begin limitless meditation with MeditationTimer\"", desc: "Begin a limitless stopwatch")
                        voiceCommandRow("\"Hey Siri, end MeditationTimer\"", desc: "End session early")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Voice Commands", systemImage: "mic.fill")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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

    // MARK: - Legacy Sound Picker Removed

    // MARK: - Voice Command Row

    private func voiceCommandRow(_ command: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(command)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hue: 0.55, saturation: 0.5, brightness: 0.9))
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
import SwiftUI
import StoreKit

enum SoundSelectionMode {
    case start
    case end
    case ambience
}

struct SoundSelectionView: View {
    let mode: SoundSelectionMode
    
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    @State private var storeManager = StoreKitManager.shared
    @State private var previewTimer: Timer?
    @State private var showingPurchaseSheet = false
    @State private var selectedLockedSoundID: String? = nil
    @State private var selectedLockedSoundName: String = ""
    
    private let premiumTones: [SoundEngine.Sound: String] = [
        .zenWoodblock: StoreKitManager.soundZenWoodblockID,
        .bambooChime: StoreKitManager.soundBambooChimeID,
        .templeBell: StoreKitManager.soundTempleBellID
    ]
    
    private let premiumAmbiences: [SoundEngine.AmbientSound: String] = [
        .delta: StoreKitManager.ambientBinauralDeltaID,
        .alpha: StoreKitManager.ambientBinauralAlphaID,
        .beta: StoreKitManager.ambientBinauralBetaID,
        .whiteNoise: StoreKitManager.ambientNoiseWhiteID,
        .pinkNoise: StoreKitManager.ambientNoisePinkID,
        .brownNoise: StoreKitManager.ambientNoiseBrownID,
        .solfeggioLove: StoreKitManager.ambientSolfeggioLoveID,
        .solfeggioNature: StoreKitManager.ambientSolfeggioNatureID
    ]
    
    private let ambientDescriptions: [SoundEngine.AmbientSound: String] = [
        .delta: "Promotes deep sleep and physical healing.",
        .alpha: "Encourages relaxed focus and creative problem-solving.",
        .beta: "Enhances concentration and active thinking.",
        .rain: "Plays gentle rain sounds during your session.",
        .whiteNoise: "Bright static that masks distracting background sounds.",
        .pinkNoise: "Balanced static, like a soothing distant waterfall.",
        .brownNoise: "Deep, warm static, like a distant rolling ocean.",
        .solfeggioLove: "528 Hz - The 'Miracle' tone, promotes repair and harmony.",
        .solfeggioNature: "432 Hz - Mathematical tuning aligned with nature."
    ]
    
    var body: some View {
        List {
            if mode == .start || mode == .end {
                Section {
                    ForEach(SoundEngine.Sound.allCases, id: \.self) { sound in
                        toneRow(sound)
                    }
                } footer: {
                    Text("These gentle tones mark the beginning and end of your meditation.")
                }
            } else {
                Section("Nature & Noise") {
                    ambientRow(.none)
                    ambientRow(.rain)
                    ambientRow(.brownNoise)
                    ambientRow(.pinkNoise)
                    ambientRow(.whiteNoise)
                }

                Section {
                    ambientRow(.delta)
                    ambientRow(.alpha)
                    ambientRow(.beta)
                } header: {
                    Text("Binaural Beats")
                } footer: {
                    Text("Binaural beats use two slightly different frequencies to guide your brainwaves into specific mental states.")
                }

                Section("Solfeggio Frequencies") {
                    ambientRow(.solfeggioNature)
                    ambientRow(.solfeggioLove)
                }
            }
        }
        .navigationTitle(titleForMode())
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopPreview()
        }
        .sheet(isPresented: $showingPurchaseSheet) {
            premiumPurchaseModal
        }
    }
    
    private func titleForMode() -> String {
        switch mode {
        case .start: return "Start Sound"
        case .end: return "End Sound"
        case .ambience: return "Ambience"
        }
    }
    
    // MARK: - Row Views
    
    private func toneRow(_ sound: SoundEngine.Sound) -> some View {
        let isSelected = (mode == .start && manager.startSound == sound) || (mode == .end && manager.endSound == sound)
        let productID = premiumTones[sound]
        let isPremium = productID != nil
        let isLocked = isPremium && !storeManager.isPurchased(productID!)
        
        return Button {
            handleToneTap(sound, isLocked: isLocked, productID: productID)
        } label: {
            HStack {
                Text(sound.rawValue)
                    .foregroundStyle(isSelected ? .blue : .primary)
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    private func ambientRow(_ ambient: SoundEngine.AmbientSound) -> some View {
        let isSelected = manager.ambientSound == ambient
        let productID = premiumAmbiences[ambient]
        let isPremium = productID != nil
        let isLocked = isPremium && !storeManager.isPurchased(productID!)
        
        return Button {
            handleAmbientTap(ambient, isLocked: isLocked, productID: productID)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ambient.rawValue)
                        .foregroundStyle(isSelected ? .blue : .primary)
                    if let desc = ambientDescriptions[ambient], ambient != .none {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleToneTap(_ sound: SoundEngine.Sound, isLocked: Bool, productID: String?) {
        // Always preview
        startPreviewTimer()
        manager.soundEngine.playSound(sound)
        
        if isLocked {
            selectedLockedSoundID = productID
            selectedLockedSoundName = sound.rawValue
            showingPurchaseSheet = true
        } else {
            if mode == .start {
                manager.startSound = sound
            } else {
                manager.endSound = sound
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    private func handleAmbientTap(_ ambient: SoundEngine.AmbientSound, isLocked: Bool, productID: String?) {
        // Always preview
        startPreviewTimer()
        manager.soundEngine.startAmbientSound(ambient)
        
        if isLocked {
            selectedLockedSoundID = productID
            selectedLockedSoundName = ambient.rawValue
            showingPurchaseSheet = true
        } else {
            manager.ambientSound = ambient
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    // MARK: - Playback
    
    private func startPreviewTimer() {
        previewTimer?.invalidate()
        // Only auto-stop if we are NOT in an active meditation session.
        // If meditating, let the sound continue as part of the session.
        if manager.state != .meditating {
            previewTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                manager.soundEngine.stopAll()
            }
        }
    }
    
    private func stopPreview() {
        previewTimer?.invalidate()
        // Only stop everything if we aren't in a real meditation session.
        if manager.state != .meditating {
            manager.soundEngine.stopAll()
        }
    }
    
    // MARK: - Purchase Modal
    
    private var premiumPurchaseModal: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                VStack(spacing: 8) {
                    Text("Unlock ")
                        .font(.title2) +
                    Text(selectedLockedSoundName)
                        .font(.title2.bold())
                    
                    Text("Premium procedural audio. Pure, rich, and generated instantly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    if let id = selectedLockedSoundID {
                        Button {
                            Task {
                                await storeManager.purchase(id)
                                if storeManager.isPurchased(id) {
                                    showingPurchaseSheet = false
                                }
                            }
                        } label: {
                            Text("Unlock Single Sound - $0.99")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .foregroundStyle(.white)
                    }
                    
                    Button {
                        Task {
                            await storeManager.purchase(StoreKitManager.soundBundleID)
                            if storeManager.isPurchased(StoreKitManager.soundBundleID) {
                                showingPurchaseSheet = false
                            }
                        }
                    } label: {
                        Text("Unlock Premium Library - $4.99")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(radius: 10)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("Premium Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showingPurchaseSheet = false
                        stopPreview()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.10).ignoresSafeArea())
        }
        .presentationDetents([.fraction(0.6)])
    }
}
