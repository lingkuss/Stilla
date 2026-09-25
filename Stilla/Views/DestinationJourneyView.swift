import SwiftUI

private enum JourneyStyle {
    static let paper = Color(red: 0.96, green: 0.945, blue: 0.905)
    static let ink = Color(red: 0.20, green: 0.255, blue: 0.225)
    static let gold = Color(red: 0.56, green: 0.43, blue: 0.23)
    static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }
}

struct DestinationJourneyEntry: View {
    var open: () -> Void
    private let store = DestinationJourneyStore.shared
    @AppStorage("destinationJourney.selectedID") private var selectedID = "borobudur"
    private var destination: JourneyDestination? { store.catalog?.destination(selectedID) ?? store.firstDestination }

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                Image(destination?.backgroundAsset ?? "JourneyBorobudur").resizable().scaledToFill()
                    .frame(height: 224).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 7) {
                    Text("journey.entry.eyebrow").font(.caption.weight(.medium)).tracking(2)
                    Text(destination?.name ?? "Borobudur").font(.system(size: 30, weight: .regular, design: .serif))
                    HStack {
                        if let destination {
                            Text(store.steps(for: destination) == 0 ? "journey.entry.start" : "journey.entry.continue")
                                .font(.subheadline)
                        }
                        Spacer()
                        Image(systemName: "arrow.right").font(.body)
                    }
                }
                .padding(22).foregroundStyle(.white)
            }
            .frame(height: 224).clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("destinationJourney.open")
    }
}

/// One next action, with the environment and guide present throughout setup, practice and arrival.
struct DestinationJourneyView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var minutes = 10
    @State private var mode = DestinationMeditationMode.guided
    @State private var showStopConfirmation = false
    @State private var showPlaces = false
    @AppStorage("destinationJourney.selectedID") private var selectedID = "borobudur"
    private var destination: JourneyDestination? {
        store.catalog?.destination(manager.activeDestinationSession?.destinationID ?? selectedID) ?? store.firstDestination
    }
    private let store = DestinationJourneyStore.shared

    private var isPracticing: Bool { manager.state == .meditating && manager.activeDestinationSession != nil }
    private var isFinished: Bool { manager.state == .complete && manager.activeDestinationSession != nil }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                if let destination {
                    VStack(spacing: 0) {
                        environment(destination, height: max(310, min(isPracticing ? 570 : 470,
                            geometry.size.height * (isPracticing ? 0.65 : 0.50))))
                        VStack(spacing: 22) {
                            if isPracticing { practiceControls }
                            else if isFinished { completion(destination) }
                            else { preparation(destination) }
                        }
                        .padding(.horizontal, 28).padding(.top, 14).padding(.bottom, 26)
                        .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    }
                } else {
                    ContentUnavailableView("journey.unavailable", systemImage: "leaf",
                        description: Text("journey.unavailable.detail"))
                        .padding(.top, 120)
                }
            }
            .background(JourneyStyle.paper)
            .overlay(alignment: .top) { navigation.padding(.horizontal, 20).padding(.top, 8) }
        }
        .background(JourneyStyle.paper.ignoresSafeArea())
        .foregroundStyle(JourneyStyle.ink).tint(JourneyStyle.ink)
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isPracticing)
        .sheet(isPresented: $showPlaces) { DestinationCatalogView(selectedID: $selectedID) }
        .confirmationDialog("journey.stop.title", isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button("journey.stop.confirm", role: .destructive) { manager.stop() }
            Button("journey.stop.continue", role: .cancel) { }
        } message: { Text("journey.stop.detail") }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { manager.refreshDestinationTimer() }
        }
    }

    private var navigation: some View {
        HStack {
            Button {
                if isPracticing { showStopConfirmation = true }
                else {
                    if isFinished { manager.reset() }
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44).background(JourneyStyle.paper.opacity(0.92), in: Circle())
            }
            .accessibilityLabel(Text("journey.close"))
            .accessibilityIdentifier("destinationJourney.close")
            Spacer()
            if !isPracticing {
                Button { showPlaces = true } label: {
                    Label("journey.your_journey", systemImage: "map")
                        .font(.system(size: 14)).padding(.horizontal, 16).frame(height: 44)
                        .background(JourneyStyle.paper.opacity(0.92), in: Capsule())
                }
                .accessibilityIdentifier("destinationJourney.places")
            }
        }
        .buttonStyle(.plain)
    }

    private func environment(_ destination: JourneyDestination, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            GeometryReader { frame in
                Image(destination.backgroundAsset ?? "JourneyBorobudur")
                    .resizable().scaledToFill()
                    .frame(width: frame.size.width, height: frame.size.height)
                    .scaleEffect(destination.milestone(at: store.steps(for: destination)).sceneScale, anchor: .top)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.5), value: store.steps(for: destination))
                    .clipped()
            }
            LinearGradient(stops: [
                .init(color: JourneyStyle.paper.opacity(0.88), location: 0),
                .init(color: JourneyStyle.paper.opacity(0.78), location: 0.65),
                .init(color: JourneyStyle.paper.opacity(0), location: 1)
            ], startPoint: .top, endPoint: .bottom)
                .frame(height: 175).frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            VStack(spacing: 5) {
                Text(JourneyStyle.text(destination.locationKey)).font(.system(size: 12, weight: .medium)).tracking(2)
                Text(destination.name).font(.system(size: 35, weight: .regular, design: .serif))
            }
            .foregroundStyle(JourneyStyle.ink)
            .padding(.top, 66).frame(maxHeight: .infinity, alignment: .top)

            // The live USDZ avatar is composited over the original illustrated environment.
            // Keep it small enough to sit within the terrace instead of obscuring the temple.
            ZenAvatarView(speech: isPracticing && mode == .guided ? GuruManager.shared.avatarSpeech : .init())
                .frame(width: 180, height: 195)
                .allowsHitTesting(false)
                .padding(.bottom, 5)
            LinearGradient(colors: [.clear, JourneyStyle.paper], startPoint: .top, endPoint: .bottom)
                .frame(height: 30).allowsHitTesting(false)
        }
        .frame(height: height).clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: JourneyStyle.text("journey.environment.accessibility"), destination.name)))
    }

    private func preparation(_ destination: JourneyDestination) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(JourneyStyle.text(destination.milestone(at: store.steps(for: destination)).titleKey))
                    .font(.system(.title2, design: .serif))
                Text("journey.invitation").font(.subheadline)
                    .foregroundStyle(JourneyStyle.ink.opacity(0.75)).multilineTextAlignment(.center)
                stepProgress(destination)
            }
            VStack(spacing: 10) {
                Text("journey.duration").font(.caption).foregroundStyle(JourneyStyle.ink.opacity(0.75))
                if dynamicTypeSize.isAccessibilitySize {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        durationButtons
                    }
                } else {
                    HStack(spacing: 8) { durationButtons }
                }
            }
            VStack(spacing: 10) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) { modeButtons }
                } else {
                    HStack(spacing: 8) { modeButtons }
                }
                Text(mode == .guided ? "journey.mode.guided.detail" : "journey.mode.silent.detail")
                    .font(.caption).foregroundStyle(JourneyStyle.ink.opacity(0.75))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            if store.storageUnavailable {
                Text("journey.unavailable.detail").font(.footnote).multilineTextAlignment(.center)
            }
            primaryButton("journey.begin", identifier: "destinationJourney.start") {
                _ = manager.startDestinationSession(destination, minutes: minutes, mode: mode)
            }
            .disabled(!store.canStart(destination) || manager.state != .idle)
        }
        .buttonStyle(.plain)
    }

    private var durationButtons: some View {
        ForEach(DestinationMeditationContent.durations, id: \.self) { value in
            Button { minutes = value } label: {
                Text("\(value) min").font(.subheadline.weight(minutes == value ? .semibold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                    .foregroundStyle(minutes == value ? JourneyStyle.paper : JourneyStyle.ink)
                    .background(minutes == value ? JourneyStyle.ink : .white.opacity(0.55), in: Capsule())
            }
            .accessibilityAddTraits(minutes == value ? .isSelected : [])
            .accessibilityIdentifier("destinationJourney.duration.\(value)")
        }
    }

    @ViewBuilder private var modeButtons: some View {
        modeButton(.guided, title: "journey.mode.guided", icon: "waveform")
        modeButton(.silent, title: "journey.mode.silent", icon: "speaker.slash")
    }

    private func modeButton(_ value: DestinationMeditationMode, title: LocalizedStringKey, icon: String) -> some View {
        Button { mode = value } label: {
            Label(title, systemImage: icon).font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(mode == value ? JourneyStyle.ink.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(
                    mode == value ? JourneyStyle.ink.opacity(0.45) : JourneyStyle.ink.opacity(0.16), lineWidth: 1))
        }
        .accessibilityAddTraits(mode == value ? .isSelected : [])
        .accessibilityIdentifier("destinationJourney.mode.\(value.rawValue)")
    }

    private var practiceControls: some View {
        VStack(spacing: 18) {
            Text("journey.present").font(.system(.title2, design: .serif))
            Text(manager.formattedTime).font(.system(size: 38, weight: .ultraLight, design: .rounded))
                .monospacedDigit().accessibilityIdentifier("destinationJourney.timer")
            Text(manager.activeDestinationSession?.mode == .silent ? "journey.mode.silent.detail" : "journey.practice.guided")
                .font(.subheadline).foregroundStyle(JourneyStyle.ink.opacity(0.75))
                .multilineTextAlignment(.center)
            Button { showStopConfirmation = true } label: {
                Text("journey.stop").font(.subheadline).padding(.horizontal, 30).frame(minHeight: 48)
                    .overlay(Capsule().strokeBorder(JourneyStyle.ink.opacity(0.25)))
            }
            .accessibilityIdentifier("destinationJourney.stop")
        }
    }

    private func completion(_ destination: JourneyDestination) -> some View {
        let summit = store.progress.completedDestinationIDs.contains(destination.id)
        let nextIsAvailable = store.catalog?.destinations.first(where: { $0.prerequisiteID == destination.id })
            .map { store.canStart($0) } ?? false
        return VStack(spacing: 18) {
            Image(systemName: manager.destinationReachedEnd ? "sun.horizon" : "leaf")
                .font(.system(size: 28, weight: .light)).foregroundStyle(JourneyStyle.gold)
                .accessibilityHidden(true)
            Text(manager.destinationReachedEnd
                 ? (summit ? "journey.complete.summit" : "journey.complete.title") : "journey.stopped.title")
                .font(.system(.title, design: .serif)).multilineTextAlignment(.center)
                .accessibilityIdentifier("destinationJourney.completion")
            Text(completionDetail(destination, summit: summit))
                .font(.subheadline).foregroundStyle(JourneyStyle.ink.opacity(0.75)).multilineTextAlignment(.center)
            stepProgress(destination)
            primaryButton(summit && !nextIsAvailable ? "journey.rest_again" : "journey.next", identifier: "destinationJourney.next") {
                manager.reset()
                if summit, let next = store.catalog?.destinations.first(where: { $0.prerequisiteID == destination.id }),
                   store.canStart(next) { selectedID = next.id }
            }
        }
    }

    private func completionDetail(_ destination: JourneyDestination, summit: Bool) -> String {
        guard manager.destinationReachedEnd else { return JourneyStyle.text("journey.stopped.detail") }
        guard summit else { return JourneyStyle.text("journey.complete.detail") }
        if let next = store.catalog?.destinations.first(where: { $0.prerequisiteID == destination.id }) {
            return String(format: JourneyStyle.text(next.isAvailable ? "journey.complete.next_available" : "journey.complete.summit.detail"),
                          destination.totalSteps, next.name)
        }
        return JourneyStyle.text("journey.complete.all")
    }

    private func stepProgress(_ destination: JourneyDestination) -> some View {
        let count = store.steps(for: destination)
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<min(destination.totalSteps, 10), id: \.self) { index in
                    Circle().fill(index < count ? JourneyStyle.gold : JourneyStyle.ink.opacity(0.15))
                        .frame(width: 5, height: 5)
                }
            }
            Text(String(format: JourneyStyle.text("journey.steps"), count, destination.totalSteps))
                .font(.caption).foregroundStyle(JourneyStyle.ink.opacity(0.75))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: JourneyStyle.text("journey.steps"), count, destination.totalSteps)))
        .accessibilityIdentifier("destinationJourney.progress")
    }

    private func primaryButton(_ title: LocalizedStringKey, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(.body.weight(.medium))
                Image(systemName: "arrow.right").font(.subheadline)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(JourneyStyle.paper).background(JourneyStyle.ink, in: Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
}

private struct DestinationCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    private let store = DestinationJourneyStore.shared
    @Binding var selectedID: String
    @State private var purchaseError: String?
    @State private var purchasingID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("journey.catalog.intro").font(.system(.title2, design: .serif))
                    ForEach(store.catalog?.destinations ?? []) { destination in
                        HStack(alignment: .top, spacing: 18) {
                            Image(systemName: store.progress.completedDestinationIDs.contains(destination.id)
                                  ? "checkmark.circle" : (destination.isAvailable ? "sun.horizon" : "mountain.2"))
                                .font(.title3).frame(width: 26).foregroundStyle(JourneyStyle.gold)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(destination.name).font(.system(.title3, design: .serif))
                                Text(JourneyStyle.text(destination.locationKey)).font(.caption)
                                if destination.isAvailable {
                                    Text(String(format: JourneyStyle.text("journey.steps"), store.steps(for: destination), destination.totalSteps))
                                        .font(.caption)
                                    if store.canStart(destination) {
                                        Button("journey.catalog.choose") { selectedID = destination.id; dismiss() }
                                            .frame(minHeight: 44)
                                    } else if let productID = destination.productID,
                                              let product = StoreKitManager.shared.products.first(where: { $0.id == productID }) {
                                        Button {
                                            purchasingID = destination.id
                                            Task { @MainActor in
                                                let result = await StoreKitManager.shared.purchase(productID)
                                                purchasingID = nil
                                                switch result {
                                                case .success:
                                                    if store.canStart(destination) { selectedID = destination.id; dismiss() }
                                                case .cancelled: break
                                                case .pending: purchaseError = JourneyStyle.text("journey.purchase.pending")
                                                default: purchaseError = JourneyStyle.text("journey.purchase.failed")
                                                }
                                            }
                                        } label: {
                                            Text(String(format: JourneyStyle.text("journey.purchase.unlock"), product.displayPrice))
                                        }
                                        .frame(minHeight: 44).disabled(purchasingID != nil)
                                    }
                                } else {
                                    Text(store.progress.hasAccess(to: destination) ? "journey.catalog.unlocked_soon" : "journey.catalog.soon")
                                        .font(.caption)
                                }
                            }
                            Spacer()
                        }
                        Divider().overlay(JourneyStyle.ink.opacity(0.1))
                    }
                    if let purchaseError { Text(purchaseError).font(.footnote) }
                    Text("journey.catalog.detail").font(.footnote).foregroundStyle(JourneyStyle.ink.opacity(0.75))
                }.padding(26)
            }
            .background(JourneyStyle.paper).foregroundStyle(JourneyStyle.ink)
            .navigationTitle(Text("journey.your_journey")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("ui.done") { dismiss() } } }
        }.tint(JourneyStyle.ink).preferredColorScheme(.light)
    }
}
