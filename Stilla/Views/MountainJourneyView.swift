import SwiftUI
import simd

private enum MountainPalette {
    static let paper = Color(red: 0.94, green: 0.92, blue: 0.86)
    static let ink = Color(red: 0.20, green: 0.29, blue: 0.27)
    static var allowsPreviewSelection: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
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

struct MountainJourneyView: View {
    var openSimpleTimer: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(MeditationManager.self) private var manager
    @State private var bloomNotice = false
    @State private var garden: StillnessGardenStore = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--garden-world-count"), args.indices.contains(i+1), let count = Int(args[i+1]) {
            return .preview(count: count)
        }
        #endif
        return .shared
    }()
    @State private var store = MountainJourneyStore.shared
    @State private var address = MountainJourneyStore.shared.progress.current
    @State private var isMoving = false
    @State private var previewTarget: MountainPlaceAddress?
    @State private var queuedWorldTap=false
    @State private var isReady = false
    @State private var loadFailed = false
    @State private var avatarFailed = false
    @State private var retryID = 0
    @State private var veil: Double = 0
    @State private var clockDate = Date()
    @State private var setup: DockSheet?
    @State private var choosingGuide = false
    @State private var introduction = GuideIntroductionPlayer()
    @State private var introductionManuallyControlled = false
    @State private var guidePage = 0
    @State private var guides = KaiPersonality.all
    @GestureState private var guideDrag: CGSize?
    @State private var guideCreationPlacement = GuideCreationPlacement()
    @State private var guidePreviewFrame: CGRect = .zero
    @AppStorage("mountain.prototype.guide.v1") private var selectedGuideID = KaiPersonality.zenMinimalist.id
    private var selectedGuide: KaiPersonality { .personality(for: selectedGuideID) }
    // -1 is an invitation to create, never a selectable meditation personality.
    private var carouselGuide: KaiPersonality? {
        guides.indices.contains(guidePage) ? guides[guidePage] : nil
    }
    private var introductionID: String? {
        guard choosingGuide, setup == nil, scenePhase == .active, !sessionActive, guideDrag == nil,
              isReady, !loadFailed else { return nil }
        return carouselGuide?.id
    }
    private var hasSceneGuide: Bool {
        GuideAvatarAsset.asset(for: selectedGuide.id) != nil || GuideCutoutAsset.asset(for: selectedGuide.id) != nil
    }
    private enum DockSheet: String, Identifiable {
        case meditate, sleep, garden, createGuide, techniques, audio, settings
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
    @State private var economical = MountainWorldResources.economical
    private var sessionActive: Bool { manager.activeMountainSession != nil && manager.state == .meditating }
    private var completed: Bool { manager.activeMountainSession != nil && manager.state == .complete }
    private var visualSeed: UInt64 { MountainWorldResources.visualSeed(store.progress.seed) }
    private var daylight: MountainDaylight {
        MountainDaylight(date: clockDate)
    }
    private var paper: Color {
        color(simd_mix(SIMD3<Float>(0.035,0.05,0.09),SIMD3<Float>(0.94,0.92,0.86),SIMD3(repeating: daylight.daylight)))
    }
    private var ink: Color {
        color(simd_mix(SIMD3<Float>(0.82,0.85,0.90),SIMD3<Float>(0.20,0.29,0.27),SIMD3(repeating: daylight.daylight)))
    }
    private var dna: MountainWorldDNA { MountainWorldResources.shared.genome(seed: visualSeed,address: address) }
    private func color(_ rgb: SIMD3<Float>) -> Color { Color(red: Double(rgb.x),green: Double(rgb.y),blue: Double(rgb.z)) }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                skyBackground(size: geometry.size)
                MountainJourneyScene(address: address,seed: visualSeed,isActive: scenePhase == .active && setup != .sleep && setup != .garden && setup != .createGuide,
                    // Earned specimens live in the collection for now; keep the mountain uncluttered.
                    specimens: [],
                    pausesWorldChanges: setup != nil || choosingGuide || notice != nil || sessionActive,
                    guidePreviewFrame: sessionActive ? .zero : guidePreviewFrame,
                    guides: guides,
                    selectedGuideID: choosingGuide ? (carouselGuide?.id ?? "create-guide") : selectedGuide.id,
                    guideSelection: choosingGuide ? Float(guidePage) - Float(min(1,max(-1,(guideDrag?.width ?? 0) / max(1,geometry.size.width*0.68)))) : nil,
                    isDraggingGuide: guideDrag != nil,
                    guideCreationPlacement: guideCreationPlacement,
                    meditationSession: sessionActive ? manager.activeMountainSession : nil,
                    breathingTechnique: manager.selectedTechnique,
                    reduceMotion: reduceMotion,economical: economical,daylight: daylight,
                    speech: sessionActive ? GuruManager.shared.avatarSpeech : introduction.speech,
                    isReady: $isReady,isMoving: $isMoving,loadFailed: $loadFailed,avatarFailed: $avatarFailed,veil: $veil) { arrived in
                        #if DEBUG
                        if arrived == previewTarget { store.arriveForPreview(arrived) }
                        #endif
                        if arrived != store.progress.current { store.arrive(arrived) }
                        // An interaction can settle at the incoming world, or stay at
                        // the last arrival if the next mesh is still being prepared.
                        address = arrived
                        previewTarget = nil
                    }
                    .id(retryID).accessibilityHidden(true)
                color(daylight.haze(dna)).opacity(veil).animation(reduceMotion ? nil : .easeInOut(duration: 1.4),value: veil)
                    .allowsHitTesting(false)
                if (avatarFailed || !hasSceneGuide) && sessionActive {
                    GuideArtwork.image(named: selectedGuide.imageName).resizable().scaledToFit()
                        .frame(height: geometry.size.height*0.30).clipShape(Circle())
                        .accessibilityLabel(Text(selectedGuide.localizedName))
                }
                if choosingGuide {
                    ZStack {
                        Color.clear.contentShape(Rectangle())
                            .accessibilityElement()
                            .accessibilityLabel(Text("mountain.guide.change"))
                            .accessibilityValue(Text(carouselGuide?.localizedName ?? GuideCreatorCopy.title))
                            .accessibilityAdjustableAction { direction in
                                moveGuide(direction == .increment ? 1 : -1)
                            }
                            .accessibilityIdentifier("mountainJourney.guideCarousel")
                        GuideCreationInvitation(placement: guideCreationPlacement, isSelected: guidePage == -1) {
                            introduction.stop(); setup = .createGuide
                        }
                    }
                    // One shared gesture handles the whole carousel and cancels
                    // a plus-button press once a horizontal or vertical drag begins.
                    .highPriorityGesture(guideCarouselDrag(width: geometry.size.width))
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
                Group {
                    if choosingGuide || typeSize.isAccessibilitySize {
                        ScrollView { Group { if choosingGuide { guideSelectionControls } else { controls } }.padding(.horizontal,24).padding(.vertical,18) }
                            .defaultScrollAnchor(.top)
                    } else {
                        // An idle ScrollView consumed taps across the transparent
                        // guide area. Only actual controls should receive touches.
                        controls.padding(.horizontal,24).padding(.vertical,18)
                    }
                }
                    .frame(maxWidth: 560,maxHeight: geometry.size.height*(choosingGuide ? (typeSize.isAccessibilitySize ? 0.44 : 0.30) : sessionActive ? (typeSize.isAccessibilitySize ? 0.35 : 0.18) : (typeSize.isAccessibilitySize ? 0.70 : 0.46)))
                    .background {
                        MountainReadingShade().padding(.top,-64).padding(.bottom,-60)
                    }
                    .padding(.bottom, !sessionActive && !choosingGuide ? 24 : 0)
            }
            .opacity(isReady ? 1 : 0)
            .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.4),value: isReady)
            .background(paper.ignoresSafeArea())
            .overlay {
                if loadFailed || store.storageUnavailable {
                    VStack(spacing: 16) {
                        Text(store.storageUnavailable ? "mountain.storage.error" : "mountain.load.error")
                        if !store.storageUnavailable {
                            Button("mountain.retry") { loadFailed = false; isReady = false; retryID += 1 }
                        }
                        Button("content.mode.simple_timer", action: openSimpleTimer)
                            .accessibilityIdentifier("mountainJourney.simpleTimerFallback")
                    }.padding(28).background(paper,in: RoundedRectangle(cornerRadius: 22))
                } else if !isReady { ProgressView().accessibilityLabel(Text("mountain.loading")) }
            }
        }
        .foregroundStyle(ink).tint(ink)
        .preferredColorScheme(daylight.daylight < 0.3 ? .dark : .light)
        .interactiveDismissDisabled(sessionActive)
        .onChange(of: isMoving) { wasMoving,moving in
            if wasMoving && !moving && queuedWorldTap {
                queuedWorldTap=false
                if canUseDock { previewNextWorld() }
            }
        }
        .task(id: introductionID) {
            introduction.stop()
            introductionManuallyControlled = false
            guard let id = introductionID, !UIAccessibility.isVoiceOverRunning else { return }
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            guard !Task.isCancelled, introductionID == id, !introductionManuallyControlled else { return }
            introduction.play(guideID: id)
        }
        .sheet(item: $setup) { selection in
            switch selection {
            case .meditate:
                MountainSessionSetup(address: store.progress.current,personality: selectedGuide,guided: settings(.guided),silent: settings(.silent))
                    .environment(manager)
                    .presentationDragIndicator(.visible)
            case .sleep:
                SleepStoriesExperienceView().environment(manager)
            case .garden:
                StillnessGardenView(store: garden) { setup = nil }
            case .createGuide:
                CustomGuideCreatorView()
            case .techniques:
                TechniqueLibraryView(allowsPreviewSelection: MountainPalette.allowsPreviewSelection).environment(manager).tint(.blue)
            case .audio:
                MountainAudioSettings(guided: settings(.guided), silent: settings(.silent))
                    .environment(manager)
            case .settings:
                SettingsView(showsMeditationAudio: false).environment(manager).tint(.blue)
            }
        }
        .alert(item: $notice) { value in
            Alert(title: Text(value == .conversation ? "mountain.conversation.title" : "mountain.session.start.error"),
                  message: value == .conversation ? Text("mountain.conversation.soon") : nil,
                  dismissButton: .default(Text("mountain.close")))
        }
        .onReceive(NotificationCenter.default.publisher(for: CustomGuideCatalog.didChange)) { notification in
            guides = KaiPersonality.all
            if let id = notification.object as? String, let index = guides.firstIndex(where: { $0.id == id }) {
                selectedGuideID = id
                manager.selectedKaiPersonalityID = id
                guidePage = index
                choosingGuide = true
            }
        }
        .onChange(of: completed,initial: true) { _, finished in
            // finish() has already saved history/progression and stopped playback.
            // This scene returns directly to the dock; other app flows keep their
            // existing completion screens.
            if finished {
                bloomNotice = manager.mountainReachedEnd && !garden.storageUnavailable && garden.earnedNoticeKey != nil
                manager.reset(preservingMountainEndingAudio: true)
            }
        }
        .task(id: bloomNotice) {
            guard bloomNotice else { return }
            do { try await Task.sleep(for: .seconds(7)) } catch { return }
            bloomNotice = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clockDate=Date(); manager.refreshMountainTimer(); updateQuality() }
            else { introduction.stop(); queuedWorldTap=false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in updateQuality() }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in updateQuality() }
        .onReceive(Timer.publish(every: 30,on: .main,in: .common).autoconnect()) { date in
            if scenePhase == .active { clockDate=date }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            if scenePhase == .active { clockDate=Date() }
        }
        .onAppear {
            guides = KaiPersonality.all
            clockDate=Date(); updateQuality()
            if !guides.contains(where: { $0.id == selectedGuideID }) {
                selectedGuideID=KaiPersonality.default.id
            }
        }
        .onDisappear {
            if choosingGuide { closeGuideSelection() }
            introduction.stop()
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
    private var reflectionKey: String {
        // Stable through clock/render updates; every consecutive world gets a new line.
        // Reduce modulo first so even a very long journey cannot overflow.
        let count=4
        let places=MountainRegionRecipe.PlaceID.allCases
        let place=places.firstIndex(of: address.place) ?? 0
        let offset=Int(MountainWorldDNA.mix(visualSeed) % UInt64(count))
        let variant=((address.region % count)*places.count+place+offset) % count
        let reflectionGuideID = CustomGuideCatalog.isCustomID(selectedGuide.id) ? KaiPersonality.zenMinimalist.id : selectedGuide.id
        return "mountain.reflection.\(reflectionGuideID).\(variant)"
    }
    private var header: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if !sessionActive {
                HStack(spacing: 8) {
                    if choosingGuide {
                        Button(action: closeGuideSelection) {
                            Image(systemName: "chevron.left").font(.body.weight(.semibold))
                                .modifier(MountainWorldText()).frame(width: 44,height: 44)
                        }
                        .accessibilityLabel(Text("content.mode.world"))
                        .accessibilityIdentifier("mountainJourney.closeGuideSelection")
                    } else {
                        Button(action: openSimpleTimer) {
                            Image(systemName: "timer").font(.system(size: 18, weight: .regular))
                                .modifier(MountainWorldText()).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Text("content.mode.simple_timer"))
                        .accessibilityIdentifier("mountainJourney.simpleTimer")
                    }
                    Spacer(minLength: 0)
                    if !choosingGuide {
                        HStack(spacing: 4) {
                            headerAction(.garden, icon: "camera.macro", label: "garden.eyebrow")
                            headerAction(.techniques, icon: "wind", label: "nav.techniques")
                                .accessibilityValue(manager.selectedTechnique.localizedName)
                            headerAction(.audio, icon: "speaker.wave.2", label: "mountain.audio.title")
                            headerAction(.settings, icon: "gearshape", label: "nav.settings")
                        }
                    }
                }
            }
            Text(LocalizedStringKey(choosingGuide ? "mountain.guide.change" : reflectionKey))
                .font(.system(.title3,design: .serif))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false,vertical: true)
                .frame(maxWidth: .infinity,alignment: .trailing)
                .modifier(MountainWorldText())
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7),value: reflectionKey)
                .accessibilityIdentifier("mountainJourney.reflection")
                .allowsHitTesting(false)
        }.padding(.horizontal,24).padding(.top,8)
            .overlay(alignment: .bottomTrailing) {
                if !sessionActive && !choosingGuide && isMoving && isReady {
                    ProgressView().tint(.white).controlSize(.mini).padding(.trailing,24).offset(y: 20)
                        .accessibilityLabel(Text("mountain.loading"))
                        .accessibilityIdentifier("mountainJourney.preparingWorld")
                }
            }
            .background {
                MountainReadingShade(top: true).padding(.top,-64).padding(.bottom,-40)
            }
    }

    private func headerAction(_ destination: DockSheet, icon: String, label: LocalizedStringKey) -> some View {
        Button { setup = destination } label: {
            Image(systemName: icon).font(.system(size: 18,weight: .regular))
                .modifier(MountainWorldText()).frame(width: 44,height: 44)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(Text(label))
            .accessibilityIdentifier("mountainJourney.\(destination.rawValue)")
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
                if bloomNotice {
                    Button { bloomNotice = false; setup = .garden } label: {
                        Text(LocalizedStringKey(garden.earnedNoticeKey ?? "garden.earned.flower"))
                            .font(.system(.body,design: .serif)).modifier(MountainWorldText())
                            .multilineTextAlignment(.center).frame(minHeight: 44)
                    }.accessibilityIdentifier("garden.earned")
                }
                ZStack {
                    Color.clear
                    if avatarFailed || !hasSceneGuide {
                        GuideArtwork.image(named: selectedGuide.imageName).resizable().scaledToFill()
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
                .allowsHitTesting(false)
                Button {
                    guidePage=guides.firstIndex(where: { $0.id == selectedGuideID }) ?? 0
                    choosingGuide=true
                } label: {
                    Label("mountain.guide.change",systemImage: "arrow.left.arrow.right")
                        .font(.caption).modifier(MountainWorldText()).frame(minHeight: 44)
                }.buttonStyle(.plain).disabled(!canUseDock)
                    .accessibilityIdentifier("mountainJourney.changeGuide")
                HStack(alignment: .top,spacing: 12) {
                    dockAction("mountain.dock.meditate",icon: "sparkles",id: "meditate") { setup = .meditate }
                    dockAction("mountain.dock.sleep",icon: "moon",id: "sleep") { setup = .sleep }
                    dockAction("mountain.dock.talk",icon: "bubble.left",id: "conversation") { notice = .conversation }
                }.disabled(!canUseDock)
            }
        }
        .foregroundStyle(.white).tint(.white)
        .disabled((!isReady || loadFailed || store.storageUnavailable) && !sessionActive)
    }
    private func guideCarouselDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($guideDrag) { value,state,_ in state=value.translation }
            .onEnded { value in
                // One intentional swipe visits one neighbour, even with a fast flick.
                let projected=value.translation.width + min(80,max(-80,
                    value.predictedEndTranslation.width-value.translation.width))
                if abs(projected)>width*0.15 {
                    moveGuide(projected<0 ? 1 : -1)
                }
            }
    }

    private func moveGuide(_ offset: Int) {
        introduction.stop()
        guidePage=min(guides.count-1,max(-1,guidePage+offset))
    }
    private func closeGuideSelection() {
        introduction.stop()
        if let personality = carouselGuide { selectedGuideID=personality.id }
        choosingGuide=false
    }
    private var guideSelectionControls: some View {
        let personality=carouselGuide
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { moveGuide(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44,height: 44)
                }.disabled(guidePage == -1)
                    .accessibilityLabel(Text("mountain.guide.previous"))
                    .accessibilityIdentifier("mountainJourney.previousGuide")
                Text(personality?.localizedName ?? GuideCreatorCopy.title).font(.system(.title2,design: .serif))
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Button { moveGuide(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44,height: 44)
                }.disabled(guidePage == guides.count-1)
                    .accessibilityLabel(Text("mountain.guide.next"))
                    .accessibilityIdentifier("mountainJourney.nextGuide")
            }
            Text(personality.map { GuideIntroductionLibrary.clip(for: $0.id)?.text ?? $0.localizedShortDescription } ?? GuideCreatorCopy.invitation)
                .font(.subheadline).multilineTextAlignment(.center).fixedSize(horizontal: false,vertical: true)
            if personality == nil {
                Button { introduction.stop(); setup = .createGuide } label: {
                    Label(GuideCreatorCopy.text("Begin creating", "Börja skapa"),systemImage: "plus")
                        .font(.subheadline).padding(.horizontal,22).frame(minHeight: 46)
                        .background(.white.opacity(0.10),in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25),lineWidth: 0.7))
                }.accessibilityIdentifier("mountainJourney.beginCreateGuide")
            }
            if let personality, let clip = GuideIntroductionLibrary.clip(for: personality.id) {
                Button {
                    introductionManuallyControlled = true
                    if introduction.isPlaying { introduction.stop() }
                    else { introduction.play(guideID: personality.id) }
                } label: {
                    Label(introduction.isPlaying ? "mountain.guide.voice.stop" : "mountain.guide.voice.play",
                          systemImage: introduction.isPlaying ? "stop.circle" : "speaker.wave.2")
                        .font(.caption).frame(minHeight: 44)
                }
                .accessibilityHint(Text(clip.text))
                .accessibilityIdentifier("mountainJourney.guideIntroduction")
                if introduction.unavailable {
                    Text("mountain.guide.voice.unavailable").font(.caption)
                }
            }
        }.buttonStyle(.plain).modifier(MountainWorldText()).tint(.white)
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
    private var canUseDock: Bool {
        manager.state == .idle && isReady && !loadFailed &&
        !store.storageUnavailable && !choosingGuide && setup == nil && notice == nil && scenePhase == .active
    }
    private var canPreviewNextWorld: Bool {
        #if DEBUG
        canUseDock && store.nextPreviewAddress != nil
        #else
        false
        #endif
    }
    private func previewNextWorld() {
        #if DEBUG
        guard canPreviewNextWorld, let target = store.nextPreviewAddress else { return }
        if isMoving { queuedWorldTap=true; return }
        previewTarget = target
        isMoving = true
        address = target
        #endif
    }
    private func updateQuality() {
        economical = MountainWorldResources.economical
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
    @State private var detent: PresentationDetent = .medium
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
                    if mode == .guided,
                       let practice = GuideMeditationLibrary.practice(minutes: guided.minutes, guideID: personality.id) {
                        VStack(spacing: 6) {
                            Text(practice.title).font(.system(.headline, design: .serif))
                            Text("mountain.session.englishGuidance").font(.caption).foregroundStyle(.secondary)
                        }.multilineTextAlignment(.center)
                    }
                    if mode == .guided,
                       let pack = CustomGuideMeditationLibrary.shared.pack(for: personality.id),
                       let practice = pack.sessions.first(where: { $0.minutes == guided.minutes }) {
                        VStack(spacing: 6) {
                            Text(practice.title).font(.system(.headline, design: .serif))
                            Text(CustomGuideLanguage(rawValue: pack.language)?.nativeName ?? pack.language)
                                .font(.caption).foregroundStyle(.secondary)
                        }.multilineTextAlignment(.center)
                    }
                    Button {
                        let saved=selection.wrappedValue
                        let ambience=SoundEngine.AmbientSound(rawValue: saved.ambience) ?? .none
                        let started=manager.startMountainSession(address: address,minutes: saved.minutes,mode: mode,
                            intention: saved.intention,ambience: ambience,personality: personality,audio: saved)
                        if started { dismiss() } else { startFailed=true }
                    } label: {
                        Text("mountain.session.begin").frame(maxWidth: .infinity,minHeight: 44)
                    }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        .accessibilityIdentifier("mountainJourney.begin")
                    if mode == .guided {
                        DisclosureGroup("mountain.choice.more",isExpanded: $showDetails) {
                            VStack(spacing: 18) {
                                TextField("mountain.session.intention",text: selection.intention,axis: .vertical)
                                    .lineLimit(2...4).textFieldStyle(.roundedBorder)
                                Text("mountain.choice.saved").font(.caption).foregroundStyle(.secondary)
                            }.padding(.top,12)
                        }
                        .accessibilityIdentifier("mountainJourney.moreOptions")
                    }
                    if startFailed { Text("mountain.session.start.error").foregroundStyle(.secondary) }
                }.padding(24)
            }
            .navigationTitle(Text("mountain.dock.meditate")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("mountain.close") { dismiss() } } }
        }.tint(MountainPalette.ink)
            .presentationDetents([.medium, .large], selection: $detent)
            .onChange(of: showDetails) { _, expanded in
                if expanded { withAnimation { detent = .large } }
            }
    }

}

private struct MountainAudioSettings: View {
    @Binding var guided: MountainMeditationPreferences.Settings
    @Binding var silent: MountainMeditationPreferences.Settings
    @AppStorage("mountain.prototype.meditation.lastMode.v1") private var mode = MountainSessionContext.Mode.guided
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    private var selection: Binding<MountainMeditationPreferences.Settings> { mode == .guided ? $guided : $silent }

    var body: some View {
        @Bindable var manager = manager
        NavigationStack {
            Form {
                Section {
                    Picker("mountain.session.mode",selection: $mode) {
                        Text("mountain.session.guided").tag(MountainSessionContext.Mode.guided)
                        Text("mountain.session.silent").tag(MountainSessionContext.Mode.silent)
                    }.pickerStyle(.segmented)
                } footer: { Text("mountain.audio.saved") }
                Section {
                    soundLibraryLink("settings.ambience", mode: .ambience, sound: selection.ambience, id: "ambience")
                    if selection.wrappedValue.ambience != "None" {
                        volumeSlider("settings.ambience", value: selection.ambienceVolume, id: "ambienceVolume")
                    }
                }
                Section {
                    Toggle("mountain.audio.breathing", isOn: selection.breathingCues)
                        .accessibilityIdentifier("mountainJourney.breathingCues")
                } footer: { Text("mountain.audio.technique.help") }
                Section {
                    soundLibraryLink("settings.start_sound", mode: .start, sound: selection.startSound, id: "startSound")
                    soundLibraryLink("settings.end_sound", mode: .end, sound: selection.endSound, id: "endSound")
                    if selection.wrappedValue.startSound != "None" || selection.wrappedValue.endSound != "None" || selection.wrappedValue.breathingCues {
                        volumeSlider("settings.chimes_and_cues", value: selection.cueVolume, id: "cueVolume")
                    }
                }
                Section {
                    volumeSlider("settings.mimir_voice", value: $manager.mimirVoiceVolume, id: "guideVolume")
                }
            }
            .navigationTitle(Text("mountain.audio.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("ui.done") { dismiss() } } }
        }
    }

    private func soundLibraryLink(_ label: LocalizedStringKey, mode: SoundSelectionMode, sound: Binding<String>, id: String) -> some View {
        NavigationLink {
            SoundSelectionView(mode: mode, configuration: SoundSelectionConfiguration(
                selection: sound,
                toneVolume: selection.wrappedValue.cueVolume,
                ambientVolume: selection.wrappedValue.ambienceVolume,
                allowsPreviewSelection: MountainPalette.allowsPreviewSelection
            ))
        } label: {
            HStack(spacing: 12) {
                if sound.wrappedValue == "None" {
                    Image(systemName: "speaker.slash")
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.secondary)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(sound.wrappedValue)
                        .resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                    Text(localizedSound(sound.wrappedValue))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("mountainJourney.\(id)")
    }

    private func volumeSlider(_ label: LocalizedStringKey, value: Binding<Float>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Slider(value: value, in: 0...1)
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier("mountainJourney.\(id)")
        }
    }

    private func localizedSound(_ name: String) -> String {
        Bundle.main.localizedString(forKey: name, value: name, table: nil)
    }
}
