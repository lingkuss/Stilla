import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language.override") private var appLanguageOverride = AppLocalization.LanguageOption.system.rawValue
    @State private var showLanguageRestartAlert = false

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
                            Text(String(localized: "settings.start_sound"))
                            Spacer()
                            Text(manager.startSound.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        SoundSelectionView(mode: .end)
                    } label: {
                        HStack {
                            Text(String(localized: "settings.end_sound"))
                            Spacer()
                            Text(manager.endSound.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label(String(localized: "settings.chimes"), systemImage: "bell.fill")
                }

                // Ambient
                Section {
                    NavigationLink {
                        SoundSelectionView(mode: .ambience)
                    } label: {
                        HStack {
                            Text(String(localized: "settings.ambience"))
                            Spacer()
                            Text(manager.ambientSound.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label(String(localized: "settings.during_meditation"), systemImage: "waveform")
                } footer: {
                    Text(String(localized: "settings.ambience_help"))
                }

                // Volume Mix
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.chimes_and_cues"))
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
                        Text(String(localized: "settings.ambience"))
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
                    Label(String(localized: "settings.volume_mix"), systemImage: "slider.horizontal.3")
                } footer: {
                    Text(String(localized: "settings.volume_mix_help"))
                }

                // Haptics
                Section {
                    Toggle(isOn: $manager.hapticEnabled) {
                        Label(String(localized: "settings.haptic_feedback"), systemImage: "iphone.radiowaves.left.and.right")
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
                        Label(String(localized: "settings.breathing_cues"), systemImage: "metronome.fill")
                    }
                } header: {
                    Label(String(localized: "settings.feedback"), systemImage: "hand.tap.fill")
                } footer: {
                    if !StoreKitManager.shared.isPurchased(StoreKitManager.techniqueLibraryID) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "settings.sound_cues_unlock_required"))
                            
                            Button {
                                Task {
                                    await StoreKitManager.shared.purchase(StoreKitManager.techniqueLibraryID)
                                }
                            } label: {
                                Text(String(format: String(localized: "settings.unlock_for_format"), StoreKitManager.shared.displayPrice(for: StoreKitManager.techniqueLibraryID, fallback: "$1.99")))
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
                        Text(String(localized: "settings.breathing_cues_help"))
                    }
                }

                // Daily Reminder
                Section {
                    Toggle(isOn: $manager.dailyReminderEnabled) {
                        Label(String(localized: "settings.daily_reminder"), systemImage: "clock.badge.checkmark.fill")
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
                } footer: {
                    Text(String(localized: "settings.daily_reminder_help"))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Kai's Voice
                Section {
                    NavigationLink {
                        VoiceSelectionView()
                    } label: {
                        HStack {
                            Label(String(localized: "settings.mimir_voice"), systemImage: "quote.bubble.fill")
                            Spacer()
                            if let voice = AVSpeechSynthesisVoice(identifier: manager.kaiVoiceIdentifier) {
                                Text(voice.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text(String(localized: "settings.voice_help"))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Section {
                    Picker(String(localized: "settings.app_language"), selection: $appLanguageOverride) {
                        Text(String(localized: "settings.language.system")).tag(AppLocalization.LanguageOption.system.rawValue)
                        Text(String(localized: "settings.language.english")).tag(AppLocalization.LanguageOption.english.rawValue)
                        Text(String(localized: "settings.language.swedish")).tag(AppLocalization.LanguageOption.swedish.rawValue)
                        Text(String(localized: "settings.language.spanish")).tag(AppLocalization.LanguageOption.spanish.rawValue)
                        Text(String(localized: "settings.language.french")).tag(AppLocalization.LanguageOption.french.rawValue)
                        Text(String(localized: "settings.language.norwegian")).tag(AppLocalization.LanguageOption.norwegian.rawValue)
                        Text(String(localized: "settings.language.danish")).tag(AppLocalization.LanguageOption.danish.rawValue)
                    }
                    .onChange(of: appLanguageOverride) { _, newValue in
                        AppLocalization.applyLanguageOverride(rawValue: newValue)
                        showLanguageRestartAlert = true
                    }
                } footer: {
                    Text(String(localized: "settings.app_language_footer"))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Siri Tips
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        voiceCommandRow(
                            String(localized: "settings.voice_command.ask_mimir.command"),
                            desc: String(localized: "settings.voice_command.ask_mimir.description")
                        )
                        voiceCommandRow(
                            String(localized: "settings.voice_command.begin.command"),
                            desc: String(localized: "settings.voice_command.begin.description")
                        )
                        voiceCommandRow(
                            String(localized: "settings.voice_command.begin_custom.command"),
                            desc: String(localized: "settings.voice_command.begin_custom.description")
                        )
                        voiceCommandRow(
                            String(localized: "settings.voice_command.begin_limitless.command"),
                            desc: String(localized: "settings.voice_command.begin_limitless.description")
                        )
                        voiceCommandRow(
                            String(localized: "settings.voice_command.end.command"),
                            desc: String(localized: "settings.voice_command.end.description")
                        )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label(String(localized: "settings.voice_commands"), systemImage: "mic.fill")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(String(localized: "settings.mimir_cloud_processing"), systemImage: "lock.shield.fill")
                            .foregroundStyle(.white.opacity(0.85))

                        Text(String(localized: "settings.privacy_cloud_processing"))
                            .foregroundStyle(.white.opacity(0.7))

                        Text(String(localized: "settings.privacy_sensitive_info"))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label(String(localized: "settings.privacy_data"), systemImage: "hand.raised.fill")
                }

                // Support / Information
                Section {
                    Button {
                        manager.hasSeenOnboarding = false
                        dismiss()
                    } label: {
                        Label(String(localized: "settings.show_intro_guide"), systemImage: "sparkles")
                    }
                }

                Section {
                    Link("Privacy Policy", destination: URL(string: "https://vindla-three.vercel.app/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://vindla-three.vercel.app/terms")!)
                }
            }
            .navigationTitle(String(localized: "nav.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) {
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
            .alert(String(localized: "settings.language.restart_required"), isPresented: $showLanguageRestartAlert) {
                Button(String(localized: "ui.ok"), role: .cancel) { }
            } message: {
                Text(String(localized: "settings.language.restart_message"))
            }
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
    @State private var selectedLockedSoundName: String = ""
    @State private var purchaseStatusMessage = ""
    @State private var showingPurchaseStatus = false

    private let premiumTones: Set<SoundEngine.Sound> = [
        .zenWoodblock, .bambooChime, .templeBell
    ]

    private let premiumAmbiences: Set<SoundEngine.AmbientSound> = [
        .delta, .alpha, .beta, .whiteNoise, .pinkNoise, .brownNoise, .solfeggioLove, .solfeggioNature
    ]
    
    private let ambientDescriptions: [SoundEngine.AmbientSound: String] = [
        .delta: String(localized: "sound.delta.description"),
        .alpha: String(localized: "sound.alpha.description"),
        .beta: String(localized: "sound.beta.description"),
        .rain: String(localized: "sound.rain.description"),
        .whiteNoise: String(localized: "sound.white_noise.description"),
        .pinkNoise: String(localized: "sound.pink_noise.description"),
        .brownNoise: String(localized: "sound.brown_noise.description"),
        .solfeggioLove: String(localized: "sound.solfeggio_love.description"),
        .solfeggioNature: String(localized: "sound.solfeggio_nature.description")
    ]
    
    var body: some View {
        List {
            if mode == .start || mode == .end {
                Section {
                    ForEach(SoundEngine.Sound.allCases, id: \.self) { sound in
                        toneRow(sound)
                    }
                } footer: {
                    Text(String(localized: "settings.chimes_help"))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                Section(String(localized: "settings.nature_and_noise")) {
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
                    Text(String(localized: "settings.binaural_beats"))
                } footer: {
                    Text(String(localized: "settings.binaural_beats_help"))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Section(String(localized: "settings.solfeggio_frequencies")) {
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
        .alert(String(localized: "alerts.purchase_status"), isPresented: $showingPurchaseStatus) {
            Button(String(localized: "ui.ok"), role: .cancel) { }
        } message: {
            Text(purchaseStatusMessage)
        }
    }
    
    private func titleForMode() -> String {
        switch mode {
        case .start: return String(localized: "settings.start_sound")
        case .end: return String(localized: "settings.end_sound")
        case .ambience: return String(localized: "settings.ambience")
        }
    }
    
    // MARK: - Row Views
    
    private func toneRow(_ sound: SoundEngine.Sound) -> some View {
        let isSelected = (mode == .start && manager.startSound == sound) || (mode == .end && manager.endSound == sound)
        let isPremium = premiumTones.contains(sound)
        let isLocked = isPremium && !storeManager.isPurchased(StoreKitManager.soundBundleID)
        
        return Button {
            handleToneTap(sound, isLocked: isLocked)
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
        let isPremium = premiumAmbiences.contains(ambient)
        let isLocked = isPremium && !storeManager.isPurchased(StoreKitManager.soundBundleID)
        
        return Button {
            handleAmbientTap(ambient, isLocked: isLocked)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ambient.rawValue)
                        .foregroundStyle(isSelected ? .blue : .primary)
                    if let desc = ambientDescriptions[ambient], ambient != .none {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
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
    
    private func handleToneTap(_ sound: SoundEngine.Sound, isLocked: Bool) {
        // Always preview
        startPreviewTimer(isLocked: isLocked)
        manager.soundEngine.playSound(sound)
        
        if isLocked {
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
    
    private func handleAmbientTap(_ ambient: SoundEngine.AmbientSound, isLocked: Bool) {
        // Always preview
        startPreviewTimer(isLocked: isLocked)
        manager.soundEngine.startAmbientSound(ambient)
        
        if isLocked {
            selectedLockedSoundName = ambient.rawValue
            showingPurchaseSheet = true
        } else {
            manager.ambientSound = ambient
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    // MARK: - Playback
    
    private func startPreviewTimer(isLocked: Bool) {
        previewTimer?.invalidate()
        
        // Always stop locked sounds after 5 seconds.
        // For unlocked sounds, only auto-stop if NOT in an active session.
        if isLocked || manager.state != .meditating {
            let currentAmbient = manager.ambientSound
            let soundEngine = manager.soundEngine
            let isMeditating = manager.state == .meditating
            
            previewTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                if isLocked {
                    if isMeditating {
                        // Revert back to the valid session sound
                        soundEngine.startAmbientSound(currentAmbient)
                    } else {
                        soundEngine.stopAll()
                    }
                } else if !isMeditating {
                    // Stop unlocked preview only if we aren't meditating
                    soundEngine.stopAll()
                }
            }
        }
    }
    
    private func stopPreview() {
        previewTimer?.invalidate()
        // Recovery logic: if we are mid-session, ensure the valid ambient is playing
        if manager.state == .meditating {
            manager.soundEngine.startAmbientSound(manager.ambientSound)
        } else {
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
                    Text(String(localized: "settings.unlock_premium_sound_library"))
                        .font(.title2.bold())
                    
                    Text(String(format: String(localized: "settings.locked_sound_message_format"), selectedLockedSoundName))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    Button {
                        Task {
                            let outcome = await storeManager.purchase(StoreKitManager.soundBundleID)
                            if case .success = outcome {
                                showingPurchaseSheet = false
                            } else {
                                presentPurchaseStatus(outcome)
                            }
                        }
                    } label: {
                        Text(String(localized: "settings.unlock_premium_library"))
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
            .navigationTitle(String(localized: "nav.premium_audio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.close")) {
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

    private func presentPurchaseStatus(_ outcome: StoreKitManager.PurchaseOutcome) {
        switch outcome {
        case .success:
            return
        case .cancelled:
            purchaseStatusMessage = "Purchase cancelled."
        case .pending:
            purchaseStatusMessage = "Your premium library purchase is pending approval."
        case .unavailable:
            purchaseStatusMessage = "The premium library isn't available right now. Check your App Store product configuration."
        case .failed(let message):
            purchaseStatusMessage = message
        }
        showingPurchaseStatus = true
    }
}
