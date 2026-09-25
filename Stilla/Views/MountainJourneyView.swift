import SwiftUI
import simd

#if DEBUG

private enum MountainPalette {
    static let paper = Color(red: 0.94, green: 0.92, blue: 0.86)
    static let ink = Color(red: 0.20, green: 0.29, blue: 0.27)
}

/// Quiet lettering; broad feathered shading does the contrast work instead
/// of outlining each glyph. The landscape itself keeps its clear colours.
private struct MountainWorldText: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color(red: 0.98,green: 0.97,blue: 0.94))
            .fontWeight(contrast == .increased ? .medium : .regular)
            .shadow(color: .black.opacity(contrast == .increased ? 0.35 : 0.18),radius: 3,y: 1)
    }
}

private struct MountainReadingShade: View {
    var top = false
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        LinearGradient(stops: [
            .init(color: .black.opacity(contrast == .increased ? 0.52 : 0.28),location: 0),
            .init(color: .black.opacity(contrast == .increased ? 0.32 : 0.17),location: 0.6),
            .init(color: .clear,location: 1)
        ],startPoint: top ? .top : .bottom,endPoint: top ? .bottom : .top)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct MountainJourneyEntry: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))
            layout {
                Image(systemName: "mountain.2")
                    .font(.system(size: 30, weight: .ultraLight))
                    .frame(width: 52, height: 58)
                VStack(alignment: .leading, spacing: 5) {
                    Text("mountain.title").font(.system(.title3, design: .serif))
                    Text("mountain.entry.subtitle").font(.caption)
                        .foregroundStyle(MountainPalette.ink.opacity(0.75))
                }
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.body.weight(.light))
                }
            }
            .padding(20)
            .foregroundStyle(MountainPalette.ink)
            .background(MountainPalette.paper.gradient, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mountainJourney.open")
    }
}

struct MountainJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(MeditationManager.self) private var manager
    @State private var store = MountainJourneyStore.shared
    @State private var address = MountainJourneyStore.shared.progress.current
    @State private var isMoving = false
    @State private var previewTarget: MountainPlaceAddress?
    @State private var isReady = false
    @State private var loadFailed = false
    @State private var avatarFailed = false
    @State private var retryID = 0
    @State private var veil: Double = 0
    @State private var clockDate = Date()
    @State private var previewHour: Float? = {
        let args=ProcessInfo.processInfo.arguments
        if let i=args.firstIndex(of: "--mountain-hour"),args.indices.contains(i+1),
           let hour=Float(args[i+1]),hour.isFinite { return hour }
        return nil
    }()
    @State private var setup: DockSheet?
    @State private var guidePreviewFrame: CGRect = .zero
    @AppStorage("mountain.prototype.guide.v1") private var selectedGuideID = KaiPersonality.zenMinimalist.id
    private var selectedGuide: KaiPersonality { .personality(for: selectedGuideID) }
    private var showsZenGuide: Bool { selectedGuide.id == KaiPersonality.zenMinimalist.id }
    private enum DockSheet: String, Identifiable {
        case meditate, sleep, guide
        var id: String { rawValue }
    }
    @AppStorage("mountain.prototype.meditation.preferences.v1") private var preferencesData = Data()
    @State private var notice: Notice?
    private enum Notice: String, Identifiable {
        case conversation, startFailed
        var id: String { rawValue }
    }
    private var preferences: MountainMeditationPreferences { .restore(preferencesData) }
    private func settings(_ mode: MountainSessionContext.Mode) -> Binding<MountainMeditationPreferences.Settings> {
        Binding(get: { preferences[mode] },set: { value in
            var updated = preferences
            updated[mode] = value
            if let data = try? JSONEncoder().encode(updated) { preferencesData = data }
        })
    }
    @State private var economical = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var sessionActive: Bool { manager.activeMountainSession != nil && manager.state == .meditating }
    private var completed: Bool { manager.activeMountainSession != nil && manager.state == .complete }
    private var visualSeed: UInt64 {
        let args=ProcessInfo.processInfo.arguments
        if let i=args.firstIndex(of: "--mountain-world"),args.indices.contains(i+1),let value=UInt64(args[i+1]) { return value }
        return store.progress.seed
    }
    private var daylight: MountainDaylight {
        if let previewHour { return MountainDaylight(hour: previewHour) }
        return MountainDaylight(date: clockDate)
    }
    private var paper: Color {
        color(simd_mix(SIMD3<Float>(0.035,0.05,0.09),SIMD3<Float>(0.94,0.92,0.86),SIMD3(repeating: daylight.daylight)))
    }
    private var ink: Color {
        color(simd_mix(SIMD3<Float>(0.82,0.85,0.90),SIMD3<Float>(0.20,0.29,0.27),SIMD3(repeating: daylight.daylight)))
    }
    private var dna: MountainWorldDNA { .init(seed: visualSeed,address: address) }
    private func color(_ rgb: SIMD3<Float>) -> Color { Color(red: Double(rgb.x),green: Double(rgb.y),blue: Double(rgb.z)) }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                skyBackground(size: geometry.size)
                MountainJourneyScene(address: address,seed: visualSeed,isActive: scenePhase == .active && setup != .sleep,
                    guidePreviewFrame: sessionActive ? .zero : guidePreviewFrame,showsZenGuide: showsZenGuide,
                    isMeditating: sessionActive,reduceMotion: reduceMotion,economical: economical,daylight: daylight,
                    speech: sessionActive ? GuruManager.shared.avatarSpeech : .init(),
                    isReady: $isReady,isMoving: $isMoving,loadFailed: $loadFailed,avatarFailed: $avatarFailed,veil: $veil) { arrived in
                        if arrived == previewTarget {
                            store.arriveForPreview(arrived)
                            previewTarget = nil
                        } else if arrived != store.progress.current { store.arrive(arrived) }
                    }
                    .id(retryID).accessibilityHidden(true)
                color(daylight.haze(dna)).opacity(veil).animation(reduceMotion ? nil : .easeInOut(duration: 1.4),value: veil)
                    .allowsHitTesting(false)
                if (avatarFailed || !showsZenGuide) && sessionActive {
                    Image(selectedGuide.imageName).resizable().scaledToFit()
                        .frame(height: geometry.size.height*0.30).clipShape(Circle())
                        .accessibilityLabel(Text(selectedGuide.localizedName))
                }
                if canPreviewNextWorld {
                    // A semantic button gives VoiceOver the same landscape action,
                    // while leaving the rendered world visually untouched.
                    Button(action: previewNextWorld) {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("mountain.preview.next"))
                    .accessibilityHint(Text("mountain.preview.next.hint"))
                    .accessibilityIdentifier("mountainJourney.nextWorld")
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) { header }
            .overlay(alignment: .bottom) {
                ScrollView { controls.padding(.horizontal,24).padding(.vertical,18) }
                    .frame(maxWidth: 560,maxHeight: geometry.size.height*(sessionActive ? (typeSize.isAccessibilitySize ? 0.35 : 0.18) : (typeSize.isAccessibilitySize ? 0.70 : 0.46)))
                    .defaultScrollAnchor(.top)
                    .background {
                        MountainReadingShade().padding(.top,-64).padding(.bottom,-60)
                    }
            }
            .overlay {
                if loadFailed || store.storageUnavailable {
                    VStack(spacing: 16) {
                        Text(store.storageUnavailable ? "mountain.storage.error" : "mountain.load.error")
                        if !store.storageUnavailable {
                            Button("mountain.retry") { loadFailed = false; isReady = false; retryID += 1 }
                        }
                    }.padding(28).background(paper,in: RoundedRectangle(cornerRadius: 22))
                } else if !isReady { ProgressView().accessibilityLabel(Text("mountain.loading")) }
            }
        }
        .foregroundStyle(ink).tint(ink)
        .preferredColorScheme(daylight.daylight < 0.3 ? .dark : .light)
        .interactiveDismissDisabled(sessionActive)
        .sheet(item: $setup,onDismiss: {
            // The existing sleep flow owns its player and ordinary session.
            if manager.state == .meditating && manager.activeMountainSession == nil { dismiss() }
        }) { selection in
            switch selection {
            case .meditate:
                MountainSessionSetup(address: address,personality: selectedGuide,guided: settings(.guided),silent: settings(.silent))
                    .environment(manager)
                    .presentationDetents([.medium,.large]).presentationDragIndicator(.visible)
            case .sleep:
                SleepStoriesExperienceView().environment(manager)
            case .guide:
                MountainGuidePicker(selectedID: $selectedGuideID)
                    .presentationDetents([.medium,.large]).presentationDragIndicator(.visible)
            }
        }
        .alert(item: $notice) { value in
            Alert(title: Text(value == .conversation ? "mountain.conversation.title" : "mountain.session.start.error"),
                  message: value == .conversation ? Text("mountain.conversation.soon") : nil,
                  dismissButton: .default(Text("mountain.close")))
        }
        .onChange(of: completed,initial: true) { _, finished in
            // finish() has already saved history/progression and stopped playback.
            // This scene returns directly to the dock; other app flows keep their
            // existing completion screens.
            if finished { manager.reset() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clockDate=Date(); manager.refreshMountainTimer(); updateQuality() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in updateQuality() }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in updateQuality() }
        .onReceive(Timer.publish(every: 30,on: .main,in: .common).autoconnect()) { date in
            if scenePhase == .active && previewHour == nil { clockDate=date }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            if scenePhase == .active { clockDate=Date() }
        }
        .onAppear { clockDate=Date(); updateQuality() }
        .onDisappear {
            if manager.activeMountainSession != nil {
                if sessionActive { manager.stop() }
                manager.reset()
            }
        }
    }
    private func skyBackground(size: CGSize) -> some View {
        let light=daylight
        let position=light.orbPosition(moon: false)
        let moon=light.orbPosition(moon: true)
        return ZStack {
            LinearGradient(colors: [color(light.sky(dna)),color(light.haze(dna))],startPoint: .top,endPoint: .bottom)
                .animation(reduceMotion ? nil : .easeInOut(duration: MountainJourneyScene.transitionDuration),value: address)
            Canvas { context,bounds in
                for i in 0..<85 {
                    let x=CGFloat(MountainWorldDNA.unit(MountainWorldDNA.mix(UInt64(i)*977+11)))*bounds.width
                    let y=CGFloat(MountainWorldDNA.unit(MountainWorldDNA.mix(UInt64(i)*871+93)))*bounds.height*0.62
                    let radius: CGFloat=i%7==0 ? 1.1 : 0.55
                    context.fill(Path(ellipseIn: CGRect(x: x,y: y,width: radius*2,height: radius*2)),with: .color(.white.opacity(i%3==0 ? 0.7 : 0.4)))
                }
            }.opacity(Double(1-light.daylight))
            Circle().fill(Color(red: 1,green: 0.9,blue: 0.65))
                .frame(width: 42,height: 42).opacity(Double(light.sunVisibility)*0.85)
                .position(x: size.width*CGFloat(position.x),y: size.height*CGFloat(position.y))
            Circle().fill(Color(red: 0.76,green: 0.84,blue: 1))
                .frame(width: 28,height: 28).opacity(Double(light.moonVisibility)*0.8)
                .position(x: size.width*CGFloat(moon.x),y: size.height*CGFloat(moon.y))
            Circle().fill(RadialGradient(colors: [Color(red: 1,green: 0.63,blue: 0.34).opacity(0.18),.clear],center: .center,startRadius: 10,endRadius: 100))
                .frame(width: 200,height: 200).opacity(Double(light.sunVisibility))
                .position(x: size.width*CGFloat(position.x),y: size.height*CGFloat(position.y))
        }.accessibilityHidden(true)
    }
    private var clockMenu: some View {
        Menu {
            Button("mountain.clock.live") { previewHour=nil; clockDate=Date() }
            Button("mountain.clock.dawn") { previewHour=6 }
            Button("mountain.clock.noon") { previewHour=12 }
            Button("mountain.clock.dusk") { previewHour=19 }
            Button("mountain.clock.night") { previewHour=0 }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: daylight.elevation >= 0 ? "sun.max" : "moon.stars")
                Text(String(format: "%02d:%02d",Int(daylight.hour),Int(daylight.hour*60)%60)).monospacedDigit()
            }.font(.subheadline).modifier(MountainWorldText()).frame(minHeight: 44)
        }
        .disabled(isMoving)
        .accessibilityLabel(Text("mountain.clock.label"))
        .accessibilityValue(Text(String(format: "%02d:%02d",Int(daylight.hour),Int(daylight.hour*60)%60)))
        .accessibilityIdentifier("mountainJourney.clock")
    }
    private var header: some View {
        HStack(alignment: .top) {
            if !sessionActive {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold))
                        .modifier(MountainWorldText()).frame(width: 44,height: 44)
                }.accessibilityLabel(Text("mountain.close")).accessibilityIdentifier("mountainJourney.close")
            }
            Spacer()
            VStack(alignment: .trailing,spacing: 5) {
                Text(LocalizedStringKey(dna.titleKey)).font(.system(.title3,design: .serif)).modifier(MountainWorldText())
                if !sessionActive { clockMenu }
            }.padding(.top,8)
        }.padding(.horizontal,24).padding(.top,8)
            .background {
                MountainReadingShade(top: true).padding(.top,-64).padding(.bottom,-40)
            }
    }
    @ViewBuilder private var controls: some View {
        VStack(spacing: 12) {
            if sessionActive {
                Text(manager.formattedTime).font(.system(.title2,design: .monospaced)).monospacedDigit()
                    .modifier(MountainWorldText())
                    .accessibilityLabel(Text("mountain.session.remaining")).accessibilityValue(manager.formattedTime)
                Button { manager.stop() } label: {
                    Text("mountain.session.stop").modifier(MountainWorldText())
                }.buttonStyle(.plain)
                    .frame(minHeight: 44).accessibilityIdentifier("mountainJourney.stop")
            } else {
                ZStack {
                    Color.clear
                    if avatarFailed || !showsZenGuide {
                        Image(selectedGuide.imageName).resizable().scaledToFill()
                            .frame(width: 150,height: 150).clipShape(Circle())
                    }
                }
                .frame(width: 190,height: typeSize.isAccessibilitySize ? 120 : 160)
                .background {
                    GeometryReader { proxy in
                        let frame=proxy.frame(in: .global)
                        Color.clear.onAppear { guidePreviewFrame=frame }
                            .onChange(of: frame) { _,value in guidePreviewFrame=value }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(selectedGuide.localizedName))
                Button { setup = .guide } label: {
                    Label("mountain.guide.change",systemImage: "arrow.left.arrow.right")
                        .font(.caption).modifier(MountainWorldText()).frame(minHeight: 44)
                }.buttonStyle(.plain).disabled(!canStartMeditation)
                    .accessibilityIdentifier("mountainJourney.changeGuide")
                HStack(alignment: .top,spacing: 12) {
                    dockAction("mountain.dock.meditate",icon: "sparkles",id: "meditate") { setup = .meditate }
                    dockAction("mountain.dock.sleep",icon: "moon",id: "sleep") { setup = .sleep }
                    dockAction("mountain.dock.talk",icon: "bubble.left",id: "conversation") { notice = .conversation }
                }.disabled(!canStartMeditation)
            }
        }
        .foregroundStyle(.white).tint(.white)
        .disabled((!isReady || loadFailed || store.storageUnavailable) && !sessionActive)
    }
    private func dockAction(_ key: LocalizedStringKey,icon: String,id: String,action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 24,weight: .light))
                    .frame(width: 52,height: 52)
                    .background(.white.opacity(0.07),in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.22),lineWidth: 0.7))
                Text(key).font(.subheadline).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false,vertical: true)
            }
            .modifier(MountainWorldText())
            .frame(maxWidth: .infinity,minHeight: 80).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mountainJourney.\(id)")
    }
    private var canStartMeditation: Bool {
        manager.state == .idle && !isMoving && isReady && !loadFailed &&
        !store.storageUnavailable && setup == nil && notice == nil && scenePhase == .active
    }
    private var canPreviewNextWorld: Bool { canStartMeditation && store.nextPreviewAddress != nil }
    private func previewNextWorld() {
        guard canPreviewNextWorld, let target = store.nextPreviewAddress else { return }
        previewTarget = target
        isMoving = true
        address = target
    }
    private func updateQuality() {
        let info = ProcessInfo.processInfo
        economical = info.isLowPowerModeEnabled || info.thermalState == .serious || info.thermalState == .critical
    }
}

private struct MountainGuidePicker: View {
    @Binding var selectedID: String
    @State private var pageID = KaiPersonality.zenMinimalist.id
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TabView(selection: $pageID) {
                    ForEach(KaiPersonality.all) { personality in
                        ScrollView {
                            VStack(spacing: 12) {
                                Image(personality.imageName).resizable().scaledToFill()
                                    .frame(width: 150,height: 150).clipShape(Circle())
                                    .accessibilityHidden(true)
                                Text(personality.localizedName).font(.title3.weight(.medium))
                                Text(personality.localizedShortDescription).font(.subheadline)
                                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }.padding(.horizontal,32).padding(.top,8).padding(.bottom,32)
                        }.tag(personality.id)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .always))
                Button {
                    selectedID=pageID
                    dismiss()
                } label: {
                    Text("mountain.guide.select").frame(maxWidth: .infinity,minHeight: 44)
                }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .padding(.horizontal,24).padding(.bottom,16)
                    .accessibilityIdentifier("mountainJourney.selectGuide")
            }
            .navigationTitle(Text("mountain.guide.change")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("mountain.close") { dismiss() } } }
            .onAppear { pageID=KaiPersonality.personality(for: selectedID).id }
        }.tint(MountainPalette.ink)
    }
}

private struct MountainSessionSetup: View {
    let address: MountainPlaceAddress
    let personality: KaiPersonality
    @Binding var guided: MountainMeditationPreferences.Settings
    @Binding var silent: MountainMeditationPreferences.Settings
    @AppStorage("mountain.prototype.meditation.lastMode.v1") private var mode = MountainSessionContext.Mode.guided
    @Environment(\.dismiss) private var dismiss
    @Environment(MeditationManager.self) private var manager
    @State private var startFailed = false
    @State private var showDetails = false
    private var selection: Binding<MountainMeditationPreferences.Settings> { mode == .guided ? $guided : $silent }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("mountain.session.mode",selection: $mode) {
                        Text("mountain.session.guided").tag(MountainSessionContext.Mode.guided)
                        Text("mountain.session.silent").tag(MountainSessionContext.Mode.silent)
                    }.pickerStyle(.segmented)
                    Picker("mountain.session.duration",selection: selection.minutes) {
                        ForEach(mode.durations,id: \.self) { value in Text("\(value) min").tag(value) }
                    }.pickerStyle(.menu).frame(minHeight: 44)
                        .accessibilityIdentifier("mountainJourney.duration")
                    Button {
                        let saved=selection.wrappedValue
                        let ambience=SoundEngine.AmbientSound(rawValue: saved.ambience) ?? .none
                        let started=manager.startMountainSession(address: address,minutes: saved.minutes,mode: mode,
                            intention: saved.intention,ambience: ambience,personality: personality)
                        if started { dismiss() } else { startFailed=true }
                    } label: {
                        Text("mountain.session.begin").frame(maxWidth: .infinity,minHeight: 44)
                    }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        .accessibilityIdentifier("mountainJourney.begin")
                    DisclosureGroup("mountain.choice.more",isExpanded: $showDetails) {
                        VStack(spacing: 18) {
                            if mode == .guided {
                                TextField("mountain.session.intention",text: selection.intention,axis: .vertical)
                                    .lineLimit(2...4).textFieldStyle(.roundedBorder)
                            }
                            Picker("mountain.session.ambience",selection: selection.ambience) {
                                Text("mountain.sound.none").tag(SoundEngine.AmbientSound.none.rawValue)
                                Text("mountain.sound.rain").tag(SoundEngine.AmbientSound.rain.rawValue)
                                Text("mountain.sound.brown").tag(SoundEngine.AmbientSound.brownNoise.rawValue)
                            }
                            Text("mountain.choice.saved").font(.caption).foregroundStyle(.secondary)
                        }.padding(.top,12)
                    }
                    if startFailed { Text("mountain.session.start.error").foregroundStyle(.secondary) }
                }.padding(24)
            }
            .navigationTitle(Text("mountain.dock.meditate")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("mountain.close") { dismiss() } } }
        }.tint(MountainPalette.ink)
    }
}
#endif
