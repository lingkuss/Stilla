import SwiftUI
import AVFoundation
import UIKit

struct SettingsView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language.override") private var appLanguageOverride = AppLocalization.LanguageOption.system.rawValue
    @State private var showLanguageRestartAlert = false
    @State private var routineManager = RoutineManager.shared

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.mimir_voice"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.1")
                                .foregroundStyle(.secondary)
                                .font(.footnote)

                            Slider(value: Bindable(manager).mimirVoiceVolume, in: 0...1)

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
                        DatePicker(String(localized: "settings.reminder_time"), selection: $manager.dailyReminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: manager.dailyReminderTime) { _, _ in
                                manager.updateDailyReminder()
                            }
                    }
                } footer: {
                    Text(String(localized: "settings.daily_reminder_help"))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Section {
                    NavigationLink {
                        RoutineListView()
                            .environment(manager)
                    } label: {
                        HStack {
                            Label(String(localized: "settings.routines"), systemImage: "calendar.badge.clock")
                            Spacer()
                            Text("\(routineManager.routines.filter(\.isEnabled).count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(String(localized: "settings.routines_help"))
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

struct RoutineListView: View {
    @Environment(MeditationManager.self) private var manager
    @State private var routineManager = RoutineManager.shared
    @State private var editingRoutine: MeditationRoutine?
    @State private var creatingRoutine = false

    var body: some View {
        NavigationStack {
            Group {
                if routineManager.routines.isEmpty {
                    ContentUnavailableView(
                        String(localized: "routines.empty_title"),
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text(String(localized: "routines.empty_message"))
                    )
                    .padding(.horizontal, 24)
                } else {
                    List {
                        ForEach(routineManager.routines) { routine in
                            routineRow(routine)
                                .listRowBackground(Color.white.opacity(0.04))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRoutine = routine
                                }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                let id = routineManager.routines[idx].id
                                routineManager.delete(id)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(String(localized: "settings.routines"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        creatingRoutine = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.10).ignoresSafeArea())
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine) { updated in
                    routineManager.update(updated)
                }
                .environment(manager)
            }
            .sheet(isPresented: $creatingRoutine) {
                RoutineEditorView(routine: nil) { created in
                    routineManager.add(created)
                }
                .environment(manager)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func routineRow(_ routine: MeditationRoutine) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(formattedTime(hour: routine.hour, minute: routine.minute)) • \(weekdaySummary(routine.weekdays))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                Text("\(sessionLabel(for: routine)) • \(minutesLabel(for: routine.durationMinutes)) • \(techniqueName(for: routine.techniqueID))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(String(localized: "routines.ambience")): \(ambientName(for: routine.ambientSound))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { routine.isEnabled },
                set: { routineManager.toggle(routine.id, enabled: $0) }
            ))
            .labelsHidden()
            .tint(Color(hue: 0.55, saturation: 0.6, brightness: 0.7))
        }
        .padding(.vertical, 6)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func weekdaySummary(_ weekdays: [Int]) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let mapped = weekdays.compactMap { weekday -> String? in
            let idx = weekday - 1
            guard symbols.indices.contains(idx) else { return nil }
            return symbols[idx]
        }
        return mapped.joined(separator: " ")
    }

    private func techniqueName(for id: String) -> String {
        let all = [BreathingTechnique.defaultTechnique] + BreathingTechnique.presets + manager.userCustomTechniques
        return all.first(where: { $0.id == id })?.localizedName ?? BreathingTechnique.defaultTechnique.localizedName
    }

    private func minutesLabel(for minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }

    private func ambientName(for sound: SoundEngine.AmbientSound) -> String {
        let key = sound.rawValue
        let value = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        return value == key ? sound.rawValue : value
    }

    private func sessionLabel(for routine: MeditationRoutine) -> String {
        switch routine.sessionType {
        case .simpleTimer:
            return String(localized: "routines.session.simple_timer")
        case .guidedByMood:
            return String(localized: "routines.session.guided_mood")
        case .guidedByIntention:
            return String(localized: "routines.session.guided_intention")
        case .savedScript:
            return String(localized: "routines.session.saved_script")
        }
    }
}

private struct RoutineEditorView: View {
    let routine: MeditationRoutine?
    let onSave: (MeditationRoutine) -> Void

    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var selectedTime = Date()
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedDuration = 10
    @State private var selectedTechniqueID = BreathingTechnique.defaultTechnique.id
    @State private var selectedAmbientSoundRaw = SoundEngine.AmbientSound.none.rawValue
    @State private var selectedSessionType: RoutineSessionType = .simpleTimer
    @State private var moodPrompt = ""
    @State private var selectedIntentionKey: String?
    @State private var selectedPersonaID = KaiPersonality.default.id
    @State private var selectedSavedScriptID: UUID?
    @State private var isEnabled = true
    @State private var showingNotificationDeniedAlert = false
    @State private var storeManager = StoreKitManager.shared
    @State private var gateToUnlock: RoutineAccessGate?
    @State private var pendingAccessGates: [RoutineAccessGate] = []
    @State private var pendingRoutineForSave: MeditationRoutine?
    @State private var purchaseStatusMessage = ""
    @State private var showingPurchaseStatus = false

    private let intentionKeys = [
        "intention.creative_flow", "intention.deep_stress", "intention.sleep_prep",
        "intention.morning_spark", "intention.anxiety_calm", "intention.grateful_heart",
        "intention.focus_reset", "intention.body_ease", "intention.confidence_boost",
        "intention.gentle_clarity", "intention.evening_unwind", "intention.self_compassion"
    ]

    private var availableRoutineDurations: [Int] {
        let allDurations = manager.allDurations.filter { $0 > 0 }
        if selectedSessionType == .guidedByMood || selectedSessionType == .guidedByIntention {
            return allDurations.filter { $0 <= KaiBrainService.maxAIGenerationDurationMinutes }
        }
        return allDurations
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "routines.section.schedule")) {
                    TextField(String(localized: "routines.title_placeholder"), text: $title)
                    DatePicker(String(localized: "routines.time"), selection: $selectedTime, displayedComponents: .hourAndMinute)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        ForEach(orderedWeekdays, id: \.weekday) { item in
                            let selected = selectedWeekdays.contains(item.weekday)
                            Button {
                                if selected {
                                    selectedWeekdays.remove(item.weekday)
                                } else {
                                    selectedWeekdays.insert(item.weekday)
                                }
                            } label: {
                                Text(item.symbol)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selected ? Color(hue: 0.55, saturation: 0.6, brightness: 0.7) : Color.white.opacity(0.08))
                                    .foregroundStyle(selected ? .black : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(String(localized: "routines.section.session")) {
                    Picker(String(localized: "routines.session_type"), selection: $selectedSessionType) {
                        Text(String(localized: "routines.session.simple_timer")).tag(RoutineSessionType.simpleTimer)
                        Text(String(localized: "routines.session.guided_mood")).tag(RoutineSessionType.guidedByMood)
                        Text(String(localized: "routines.session.guided_intention")).tag(RoutineSessionType.guidedByIntention)
                        Text(String(localized: "routines.session.saved_script")).tag(RoutineSessionType.savedScript)
                    }

                    if selectedSessionType == .guidedByMood {
                        TextField(String(localized: "routines.mood_placeholder"), text: $moodPrompt, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if selectedSessionType == .guidedByIntention {
                        Picker(String(localized: "routines.intention"), selection: Binding(
                            get: { selectedIntentionKey ?? intentionKeys.first ?? "" },
                            set: { selectedIntentionKey = $0 }
                        )) {
                            ForEach(intentionKeys, id: \.self) { key in
                                Text(localizedText(for: key)).tag(key)
                            }
                        }
                    }

                    if selectedSessionType == .guidedByMood || selectedSessionType == .guidedByIntention {
                        Picker(String(localized: "routines.persona"), selection: $selectedPersonaID) {
                            ForEach(KaiPersonality.all) { persona in
                                Text(persona.localizedName).tag(persona.id)
                            }
                        }
                    }

                    if selectedSessionType == .savedScript {
                        if manager.savedMeditations.isEmpty {
                            Text(String(localized: "routines.saved_script_none"))
                                .foregroundStyle(.secondary)
                        } else {
                            Picker(String(localized: "routines.saved_script"), selection: Binding(
                                get: { selectedSavedScriptID ?? manager.savedMeditations.first!.id },
                                set: { selectedSavedScriptID = $0 }
                            )) {
                                ForEach(manager.savedMeditations, id: \.id) { script in
                                    Text(script.title).tag(script.id)
                                }
                            }
                        }
                    }
                }

                Section(String(localized: "routines.section.meditation")) {
                    if selectedSessionType == .savedScript, let script = selectedSavedScript {
                        HStack {
                            Text(String(localized: "routines.duration"))
                            Spacer()
                            Text(minutesLabel(for: script.durationMinutes))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker(String(localized: "routines.duration"), selection: $selectedDuration) {
                            ForEach(availableRoutineDurations, id: \.self) { duration in
                                Text(minutesLabel(for: duration)).tag(duration)
                            }
                        }
                    }

                    Picker(String(localized: "routines.technique"), selection: $selectedTechniqueID) {
                        ForEach(availableTechniques, id: \.id) { technique in
                            Text(technique.localizedName).tag(technique.id)
                        }
                    }

                    Picker(String(localized: "routines.ambience"), selection: $selectedAmbientSoundRaw) {
                        ForEach(SoundEngine.AmbientSound.allCases, id: \.rawValue) { sound in
                            Text(localizedText(for: sound.rawValue)).tag(sound.rawValue)
                        }
                    }

                    Toggle(String(localized: "routines.enabled"), isOn: $isEnabled)
                }
            }
            .navigationTitle(routine == nil ? String(localized: "routines.new") : String(localized: "routines.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "ui.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.save")) {
                        Task {
                            await saveRoutine()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExisting)
            .onChange(of: selectedSessionType) { _, newValue in
                if newValue == .guidedByIntention && selectedIntentionKey == nil {
                    selectedIntentionKey = intentionKeys.first
                }
                if newValue == .savedScript && selectedSavedScriptID == nil {
                    selectedSavedScriptID = manager.savedMeditations.first?.id
                }
                if newValue == .savedScript, let script = selectedSavedScript {
                    selectedDuration = script.durationMinutes
                } else if (newValue == .guidedByMood || newValue == .guidedByIntention),
                          selectedDuration > KaiBrainService.maxAIGenerationDurationMinutes {
                    selectedDuration = KaiBrainService.maxAIGenerationDurationMinutes
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(String(localized: "routines.notifications_required.title"), isPresented: $showingNotificationDeniedAlert) {
            Button(String(localized: "ui.cancel"), role: .cancel) { }
            Button(String(localized: "routines.notifications_required.open_settings")) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text(String(localized: "routines.notifications_required.message"))
        }
        .alert(item: $gateToUnlock) { gate in
            Alert(
                title: Text(routineAccessTitle(for: gate)),
                message: Text(routineAccessMessage(for: gate)),
                primaryButton: .default(Text(routineAccessUnlockLabel(for: gate))) {
                    Task {
                        await unlockGateAndContinue(gate)
                    }
                },
                secondaryButton: .cancel(Text(String(localized: "routines.gate.not_now"))) {
                    gateToUnlock = nil
                    pendingAccessGates = []
                    pendingRoutineForSave = nil
                }
            )
        }
        .alert(String(localized: "paywall.alert.title"), isPresented: $showingPurchaseStatus) {
            Button(String(localized: "common.ok"), role: .cancel) { }
        } message: {
            Text(purchaseStatusMessage)
        }
    }

    private var availableTechniques: [BreathingTechnique] {
        let merged = [BreathingTechnique.defaultTechnique] + BreathingTechnique.presets + manager.userCustomTechniques
        var seen = Set<String>()
        return merged.filter { seen.insert($0.id).inserted }
    }

    private var selectedSavedScript: MeditationScript? {
        guard let selectedSavedScriptID else { return nil }
        return manager.savedMeditations.first(where: { $0.id == selectedSavedScriptID })
    }

    private var canSave: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDays = !selectedWeekdays.isEmpty
        let hasSavedScript = selectedSessionType != .savedScript || selectedSavedScriptID != nil
        let hasIntention = selectedSessionType != .guidedByIntention || selectedIntentionKey != nil
        return hasTitle && hasDays && hasSavedScript && hasIntention
    }

    private var orderedWeekdays: [(weekday: Int, symbol: String)] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday
        return (0..<7).compactMap { offset in
            let weekday = ((first - 1 + offset) % 7) + 1
            let idx = weekday - 1
            guard symbols.indices.contains(idx) else { return nil }
            return (weekday, symbols[idx])
        }
    }

    private func localizedText(for key: String) -> String {
        let value = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        return value == key ? key : value
    }

    private func minutesLabel(for minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }

    private func loadExisting() {
        guard let routine else {
            selectedIntentionKey = intentionKeys.first
            selectedSavedScriptID = manager.savedMeditations.first?.id
            return
        }

        title = routine.title
        selectedWeekdays = Set(routine.weekdays)
        selectedDuration = routine.durationMinutes
        selectedTechniqueID = routine.techniqueID
        selectedAmbientSoundRaw = routine.ambientSoundRaw
        selectedSessionType = routine.sessionType
        moodPrompt = routine.moodPrompt ?? ""
        selectedIntentionKey = routine.intentionKey ?? intentionKeys.first
        selectedPersonaID = routine.personaID ?? manager.selectedKaiPersonalityID
        selectedSavedScriptID = routine.savedScriptID ?? manager.savedMeditations.first?.id
        if selectedSessionType == .savedScript, let script = selectedSavedScript {
            selectedDuration = script.durationMinutes
        } else if (selectedSessionType == .guidedByMood || selectedSessionType == .guidedByIntention),
                  selectedDuration > KaiBrainService.maxAIGenerationDurationMinutes {
            selectedDuration = KaiBrainService.maxAIGenerationDurationMinutes
        }
        isEnabled = routine.isEnabled

        var components = DateComponents()
        components.hour = routine.hour
        components.minute = routine.minute
        selectedTime = Calendar.current.date(from: components) ?? Date()
    }

    private func saveRoutine() async {
        let final = buildRoutineDraft()

        await storeManager.updateCustomerProductStatus()
        let requiredGates = accessGatesRequired(for: final)
        if !requiredGates.isEmpty {
            pendingRoutineForSave = final
            pendingAccessGates = requiredGates
            gateToUnlock = requiredGates.first
            return
        }

        await completeSave(final)
    }

    private func completeSave(_ routineToSave: MeditationRoutine) async {
        if routineToSave.isEnabled {
            let granted = await NotificationManager.shared.requestAuthorization()
            if !granted {
                showingNotificationDeniedAlert = true
                return
            }
        }

        onSave(routineToSave)
        dismiss()
    }

    private func buildRoutineDraft() -> MeditationRoutine {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let resolvedDuration: Int
        if selectedSessionType == .savedScript, let script = selectedSavedScript {
            resolvedDuration = script.durationMinutes
        } else if selectedSessionType == .guidedByMood || selectedSessionType == .guidedByIntention {
            resolvedDuration = min(selectedDuration, KaiBrainService.maxAIGenerationDurationMinutes)
        } else {
            resolvedDuration = selectedDuration
        }

        return MeditationRoutine(
            id: routine?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            hour: timeComponents.hour ?? 8,
            minute: timeComponents.minute ?? 0,
            weekdays: Array(selectedWeekdays).sorted(),
            durationMinutes: resolvedDuration,
            techniqueID: selectedTechniqueID,
            isEnabled: isEnabled,
            sessionType: selectedSessionType,
            moodPrompt: selectedSessionType == .guidedByMood ? moodPrompt.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            intentionKey: selectedSessionType == .guidedByIntention ? selectedIntentionKey : nil,
            personaID: (selectedSessionType == .guidedByMood || selectedSessionType == .guidedByIntention) ? selectedPersonaID : nil,
            savedScriptID: selectedSessionType == .savedScript ? selectedSavedScriptID : nil,
            ambientSoundRaw: selectedAmbientSoundRaw
        )
    }

    private func accessGatesRequired(for routine: MeditationRoutine) -> [RoutineAccessGate] {
        var gates: [RoutineAccessGate] = []

        if routine.sessionType == .guidedByMood ||
            routine.sessionType == .guidedByIntention ||
            routine.sessionType == .savedScript {
            if !storeManager.isVindlaProSubscribed {
                gates.append(.pro)
            }
        }

        if let selectedTechnique = availableTechniques.first(where: { $0.id == routine.techniqueID }),
           selectedTechnique.isPurchasable,
           !storeManager.isPurchased(StoreKitManager.techniqueLibraryID) {
            gates.append(.techniqueLibrary)
        }

        if SoundEngine.AmbientSound.premiumForSoundBundle.contains(routine.ambientSound),
           !storeManager.isPurchased(StoreKitManager.soundBundleID) {
            gates.append(.soundLibrary)
        }

        return gates
    }

    private func routineAccessTitle(for gate: RoutineAccessGate) -> String {
        switch gate {
        case .pro:
            return String(localized: "routines.gate.pro.title")
        case .techniqueLibrary:
            return String(localized: "routines.gate.technique.title")
        case .soundLibrary:
            return String(localized: "routines.gate.sound.title")
        }
    }

    private func routineAccessMessage(for gate: RoutineAccessGate) -> String {
        let routineTitle = pendingRoutineForSave?.title ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch gate {
        case .pro:
            return String(format: String(localized: "routines.gate.pro.message_format"), routineTitle)
        case .techniqueLibrary:
            return String(format: String(localized: "routines.gate.technique.message_format"), routineTitle)
        case .soundLibrary:
            return String(format: String(localized: "routines.gate.sound.message_format"), routineTitle)
        }
    }

    private func routineAccessUnlockLabel(for gate: RoutineAccessGate) -> String {
        switch gate {
        case .pro:
            return String(localized: "routines.gate.unlock_pro")
        case .techniqueLibrary:
            let price = storeManager.displayPrice(for: StoreKitManager.techniqueLibraryID, fallback: "$1.99")
            return String(format: String(localized: "routines.gate.unlock_technique_format"), price)
        case .soundLibrary:
            let price = storeManager.displayPrice(for: StoreKitManager.soundBundleID, fallback: "$4.99")
            return String(format: String(localized: "routines.gate.unlock_sound_format"), price)
        }
    }

    private func unlockGateAndContinue(_ gate: RoutineAccessGate) async {
        let outcome: StoreKitManager.PurchaseOutcome
        switch gate {
        case .pro:
            outcome = await storeManager.purchase(StoreKitManager.vindlaProID)
        case .techniqueLibrary:
            outcome = await storeManager.purchase(StoreKitManager.techniqueLibraryID)
        case .soundLibrary:
            outcome = await storeManager.purchase(StoreKitManager.soundBundleID)
        }

        await storeManager.updateCustomerProductStatus()

        guard case .success = outcome else {
            presentPurchaseStatus(outcome)
            return
        }

        pendingAccessGates.removeAll(where: { $0 == gate })

        if let nextGate = pendingAccessGates.first {
            gateToUnlock = nextGate
            return
        }

        guard let pending = pendingRoutineForSave else { return }
        gateToUnlock = nil
        pendingAccessGates = []
        pendingRoutineForSave = nil
        await completeSave(pending)
    }

    private func presentPurchaseStatus(_ outcome: StoreKitManager.PurchaseOutcome) {
        switch outcome {
        case .success:
            return
        case .cancelled:
            purchaseStatusMessage = String(localized: "purchase.cancelled")
        case .pending:
            purchaseStatusMessage = String(localized: "purchase.pending")
        case .unavailable:
            purchaseStatusMessage = String(localized: "purchase.unavailable")
        case .failed(let message):
            purchaseStatusMessage = message
        }
        showingPurchaseStatus = true
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

    private let ambientDescriptions: [SoundEngine.AmbientSound: String] = [
        .delta: String(localized: "sound.delta.description"),
        .alpha: String(localized: "sound.alpha.description"),
        .beta: String(localized: "sound.beta.description"),
        .rain: String(localized: "sound.rain.description"),
        .whiteNoise: String(localized: "sound.white_noise.description"),
        .pinkNoise: String(localized: "sound.pink_noise.description"),
        .brownNoise: String(localized: "sound.brown_noise.description"),
        .solfeggioLove: String(localized: "sound.solfeggio_love.description"),
        .solfeggioNature: String(localized: "sound.solfeggio_nature.description"),
        .ancientFlora: String(localized: "sound.ancient_flora.description", defaultValue: "A gentle loop of ancient botanical tones."),
        .greenCanopy: String(localized: "sound.green_canopy.description", defaultValue: "A soothing loop of vibrant canopy rustling.")
    ]
    
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        ScrollView {
            if mode == .start || mode == .end {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "settings.chimes_help"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 4)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(SoundEngine.Sound.allCases, id: \.self) { sound in
                            toneCard(sound)
                        }
                    }
                }
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    soundSection(title: String(localized: "settings.nature_and_noise"), items: [.none, .rain, .brownNoise, .pinkNoise, .whiteNoise])
                    
                    soundSection(
                        title: String(localized: "settings.binaural_beats"),
                        helpText: String(localized: "settings.binaural_beats_help"),
                        items: [.delta, .alpha, .beta]
                    )

                    soundSection(title: String(localized: "settings.solfeggio_frequencies"), items: [.solfeggioNature, .solfeggioLove])
                    
                    soundSection(title: String(localized: "settings.soundscapes", defaultValue: "Soundscapes"), items: [.ancientFlora, .greenCanopy])
                }
                .padding()
            }
        }
        .background(Color(hue: 0.72, saturation: 0.4, brightness: 0.10).ignoresSafeArea())
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
    
    // MARK: - Grid Views
    
    private func soundSection(title: String, helpText: String? = nil, items: [SoundEngine.AmbientSound]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let helpText {
                    Text(helpText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.self) { ambient in
                    ambientCard(ambient)
                }
            }
        }
    }

    private func toneCard(_ sound: SoundEngine.Sound) -> some View {
        let isSelected = (mode == .start && manager.startSound == sound) || (mode == .end && manager.endSound == sound)
        let isPremium = premiumTones.contains(sound)
        let isLocked = isPremium && !storeManager.isPurchased(StoreKitManager.soundBundleID)
        
        return Button {
            handleToneTap(sound, isLocked: isLocked)
        } label: {
            cardContent(name: sound.rawValue, description: nil, isSelected: isSelected, isLocked: isLocked)
        }
        .buttonStyle(.plain)
    }
    
    private func ambientCard(_ ambient: SoundEngine.AmbientSound) -> some View {
        let isSelected = manager.ambientSound == ambient
        let isPremium = SoundEngine.AmbientSound.premiumForSoundBundle.contains(ambient)
        let isLocked = isPremium && !storeManager.isPurchased(StoreKitManager.soundBundleID)
        let desc = ambientDescriptions[ambient] ?? " "
        
        return Button {
            handleAmbientTap(ambient, isLocked: isLocked)
        } label: {
            cardContent(name: ambient.rawValue, description: desc, isSelected: isSelected, isLocked: isLocked)
        }
        .buttonStyle(.plain)
    }

    private func cardContent(name: String, description: String?, isSelected: Bool, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if name == "None" {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "speaker.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                } else {
                    Image(name)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                }

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                        .padding(8)
                        .foregroundStyle(.white)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .blue)
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: isSelected ? 3 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .lineLimit(1)
                
                if let description {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
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
            purchaseStatusMessage = String(localized: "purchase.cancelled")
        case .pending:
            purchaseStatusMessage = String(localized: "purchase.pending")
        case .unavailable:
            purchaseStatusMessage = String(localized: "purchase.unavailable")
        case .failed(let message):
            purchaseStatusMessage = message
        }
        showingPurchaseStatus = true
    }
}
