import SwiftUI

enum GardenStyle {
    static let paper = Color(red: 0.965,green: 0.955,blue: 0.927)
    static let ink = Color(red: 0.23,green: 0.31,blue: 0.29)
    static let muted = Color(red: 0.42,green: 0.46,blue: 0.41)
    static func glow(_ kind: GardenKind) -> Color {
        switch kind {
        case .flower: Color(red: 0.90,green: 0.72,blue: 0.68)
        case .crystal: Color(red: 0.64,green: 0.77,blue: 0.80)
        case .tree: Color(red: 0.69,green: 0.78,blue: 0.60)
        }
    }
}

struct StillnessGardenView: View {
    @State var store = StillnessGardenStore.shared
    let onClose: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38.0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading,spacing: 32) {
                    VStack(alignment: .leading,spacing: 12) {
                        Text("garden.eyebrow").font(.caption).tracking(3).textCase(.uppercase)
                            .foregroundStyle(GardenStyle.muted)
                        Text("garden.title").font(.system(size: titleSize,weight: .regular,design: .serif))
                            .accessibilityAddTraits(.isHeader)
                        Text("garden.subtitle").font(.body).foregroundStyle(GardenStyle.muted)
                            .fixedSize(horizontal: false,vertical: true)
                    }.padding(.top,16)
                    if store.storageUnavailable {
                        Text("garden.storage.error").font(.body).foregroundStyle(GardenStyle.muted)
                    } else {
                        ForEach(GardenKind.allCases) { kind in
                            NavigationLink {
                                GardenCollectionView(kind: kind,store: store)
                            } label: { category(kind) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("garden.category.\(kind.rawValue)")
                        }
                        Text("garden.footer").font(.system(.subheadline,design: .serif)).italic()
                            .foregroundStyle(GardenStyle.muted).frame(maxWidth: .infinity).padding(.vertical,12)
                    }
                }.padding(.horizontal,26).padding(.bottom,32).frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
            }
            .background(GardenStyle.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) { Image(systemName: "xmark").frame(width: 44,height: 44) }
                        .accessibilityLabel(Text("garden.close"))
                        .accessibilityIdentifier("garden.close")
                }
            }
        }
        .tint(GardenStyle.ink).foregroundStyle(GardenStyle.ink).preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task { await GardenPortraits.shared.clear() }
        }
    }

    private func category(_ kind: GardenKind) -> some View {
        let items = store.specimens(kind)
        return VStack(alignment: .leading,spacing: 0) {
            ZStack {
                RadialGradient(colors: [GardenStyle.glow(kind).opacity(0.30),.clear],center: .center,startRadius: 12,endRadius: 150)
                if let latest = items.last { GardenPortrait(specimen: latest) }
                else {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 62,weight: .ultraLight))
                        .foregroundStyle(GardenStyle.ink.opacity(0.28)).accessibilityHidden(true)
                }
            }.frame(height: 190)
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(kind.titleKey)).font(.system(.title2,design: .serif))
                Text(items.count,format: .number).font(.subheadline.monospacedDigit()).foregroundStyle(GardenStyle.muted)
                Spacer()
                Image(systemName: "arrow.up.right").font(.body.weight(.light)).accessibilityHidden(true)
            }
            Text(LocalizedStringKey(kind.ruleKey)).font(.subheadline).foregroundStyle(GardenStyle.muted)
                .padding(.top,8).fixedSize(horizontal: false,vertical: true)
            Rectangle().fill(GardenStyle.ink.opacity(0.13)).frame(height: 1).padding(.top,22)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct GardenCollectionView: View {
    let kind: GardenKind
    let store: StillnessGardenStore
    @Environment(\.dynamicTypeSize) private var typeSize
    private var items: [GardenSpecimen] { store.specimens(kind) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 24) {
                Text(LocalizedStringKey(kind.ruleKey)).font(.system(.title3,design: .serif))
                    .foregroundStyle(GardenStyle.muted).fixedSize(horizontal: false,vertical: true)
                VStack(alignment: .leading,spacing: 8) {
                        ProgressView(value: Double(store.meditationCount % kind.interval),total: Double(kind.interval))
                            .tint(GardenStyle.ink.opacity(0.6))
                        Text(String(format: NSLocalizedString("garden." + kind.rawValue + ".remaining",comment: "Meditations to milestone"),store.remaining(kind)))
                            .font(.caption).foregroundStyle(GardenStyle.muted)
                }.accessibilityElement(children: .combine)
                if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 70,weight: .ultraLight)).foregroundStyle(GardenStyle.ink.opacity(0.30))
                        Text(LocalizedStringKey("garden." + kind.rawValue + ".empty"))
                            .font(.system(.title2,design: .serif)).multilineTextAlignment(.center)
                        Text("garden.empty.hint").font(.subheadline).foregroundStyle(GardenStyle.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical,70)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 145),spacing: 18)],spacing: 28) {
                        ForEach(items.reversed()) { item in
                            NavigationLink {
                                GardenDetailView(items: items,initial: item.id)
                            } label: {
                                VStack(alignment: .leading,spacing: 6) {
                                    GardenPortrait(specimen: item).frame(height: 210)
                                        .background(RadialGradient(colors: [GardenStyle.glow(kind).opacity(0.22),.clear],center: .center,startRadius: 0,endRadius: 120))
                                    Text(GardenWords.name(item)).font(.system(.headline,design: .serif))
                                    Text(item.earnedAt,format: .dateTime.day().month(.abbreviated))
                                        .font(.caption).foregroundStyle(GardenStyle.muted)
                                }.frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityLabel(GardenWords.name(item) + ", " + String(format: String(localized: "garden.specimen.number"),item.ordinal))
                                .accessibilityIdentifier("garden.specimen.\(item.ordinal)")
                        }
                    }
                }
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(GardenStyle.paper.ignoresSafeArea())
        .navigationTitle(Text(LocalizedStringKey(kind.titleKey)))
        .navigationBarTitleDisplayMode(.large)
    }
}

enum GardenWords {
    static func name(_ item: GardenSpecimen) -> String {
        let variant = Int(GardenDNA.value(item.seed,701)*6)
        return NSLocalizedString("garden.\(item.kind.rawValue).name.\(variant)",comment: "Seeded specimen name")
    }
}

private struct GardenDetailView: View {
    let items: [GardenSpecimen]
    let initial: String
    @State private var selection: String?
    @State private var rotation = SIMD2<Float>(0,0)
    @State private var zoom: Double = 1
    @State private var resetID = 0
    @State private var visible = false
    @State private var specimenVisible = true
    @GestureState private var drag = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var dragging = false
    @GestureState private var pinching = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var economical = MountainWorldResources.economical
    private var index: Int { items.firstIndex(where: { $0.id == (selection ?? initial) }) ?? 0 }
    private var item: GardenSpecimen { items[index] }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    Text(String(format: String(localized: "garden.specimen.number"),item.ordinal))
                        .font(.caption.monospacedDigit()).tracking(2).textCase(.uppercase).foregroundStyle(GardenStyle.muted)
                        .padding(.top,20)
                    ZStack {
                        RadialGradient(colors: [GardenStyle.glow(item.kind).opacity(0.35),.clear],center: .center,startRadius: 30,endRadius: 230)
                        GardenSpecimenScene(specimen: item,active: visible && specimenVisible && scenePhase == .active,economical: economical,
                            automaticRotation: !reduceMotion,
                            interacting: dragging || pinching,resetID: resetID,
                            rotation: rotation+SIMD2(Float(drag.width)*0.009,Float(drag.height)*0.009),
                            zoom: min(2.2,max(0.7,zoom*Double(magnification))))
                        .accessibilityHidden(true)
                    }
                    .frame(height: max(280,min(480,geometry.size.height*0.57)))
                    .background(GeometryReader { previewGeometry in
                        Color.clear.onChange(of: previewGeometry.frame(in: .global).intersects(geometry.frame(in: .global)),initial: true) { _,isVisible in
                            specimenVisible = isVisible
                        }
                    })
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).updating($drag) { value,state,_ in state = value.translation }
                        .updating($dragging) { _,state,_ in state = true }
                        .onEnded { value in
                            rotation += SIMD2(Float(value.translation.width)*0.009,Float(value.translation.height)*0.009)
                            rotation.x = rotation.x.truncatingRemainder(dividingBy: 2 * .pi)
                            rotation.y = rotation.y.truncatingRemainder(dividingBy: 2 * .pi)
                        })
                    .simultaneousGesture(MagnificationGesture().updating($magnification) { value,state,_ in state = value }
                        .updating($pinching) { _,state,_ in state = true }
                        .onEnded { zoom = min(2.2,max(0.7,zoom*Double($0))) })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(GardenWords.name(item))
                    .accessibilityValue(Text("\(Int(rotation.x * 180 / .pi))°"))
                    .accessibilityHint(Text("garden.orbit.hint"))
                    .accessibilityAdjustableAction { rotation.x += $0 == .increment ? 0.45 : -0.45 }
                    .accessibilityAction(named: Text("garden.view.above")) { rotation.y = .pi/2 }
                    .accessibilityAction(named: Text("garden.view.below")) { rotation.y = -.pi/2 }
                    .accessibilityAction(named: Text("garden.reset")) { reset() }
                    .accessibilityIdentifier("garden.orbit")
                    VStack(spacing: 9) {
                        Text(GardenWords.name(item)).font(.system(.largeTitle,design: .serif)).multilineTextAlignment(.center)
                        Text(item.earnedAt,format: .dateTime.day().month(.wide).year()).font(.subheadline).foregroundStyle(GardenStyle.muted)
                        Text(LocalizedStringKey("garden." + item.kind.rawValue + ".poem"))
                            .font(.system(.body,design: .serif)).italic().foregroundStyle(GardenStyle.muted)
                            .multilineTextAlignment(.center).padding(.top,8)
                    }.padding(.horizontal,24)
                    HStack {
                        Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 48,height: 48) }
                            .disabled(index == 0).accessibilityLabel(Text("garden.previous"))
                        Spacer()
                        Button(action: reset) {
                            Label("garden.reset",systemImage: "arrow.counterclockwise").font(.caption).frame(minHeight: 44)
                        }.accessibilityIdentifier("garden.reset")
                        Spacer()
                        Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 48,height: 48) }
                            .disabled(index == items.count-1).accessibilityLabel(Text("garden.next"))
                    }.padding(.horizontal,24)
                    Text("garden.orbit.hint").font(.caption).foregroundStyle(GardenStyle.muted)
                        .multilineTextAlignment(.center).padding(.horizontal,24).padding(.bottom,24)
                }.frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
        }
        .background(GardenStyle.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in economical = MountainWorldResources.economical }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in economical = MountainWorldResources.economical }
    }
    private func reset() { rotation = .zero; zoom = 1; resetID += 1 }
    private func move(_ step: Int) {
        let next = index+step
        guard items.indices.contains(next) else { return }
        selection = items[next].id
        reset()
    }
}

#if DEBUG
#Preview {
    @Previewable @State var presented = true
    Color.clear.sheet(isPresented: $presented) {
        StillnessGardenView(store: .preview(count: 100)) { presented = false }
    }
}
#endif
