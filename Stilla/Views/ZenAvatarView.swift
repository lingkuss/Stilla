import SwiftUI
import RealityKit
import Combine
import AVFoundation
import Metal

/// Bundled offline model, animated from native speech playback and breathing phases.
struct ZenAvatarView: View {
    var speech = ZenSpeechMotion()
    var technique: BreathingTechnique?
    var onPhaseChange: ((String, Double) -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didLoad = false
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            if loadFailed {
                Image(KaiPersonality.zenMinimalist.imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                ZenAvatarScene(
                    speech: speech,
                    technique: technique,
                    onPhaseChange: onPhaseChange,
                    isActive: scenePhase == .active,
                    reduceMotion: reduceMotion,
                    didLoad: $didLoad,
                    loadFailed: $loadFailed
                )
                if !didLoad {
                    ProgressView().tint(.white.opacity(0.6))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(KaiPersonality.zenMinimalist.localizedName)
        .accessibilityValue(speech.isSpeaking ? String(localized: "zen.avatar.speaking") : String(localized: "zen.avatar.resting"))
    }
}

private struct ZenAvatarScene: UIViewRepresentable {
    typealias Coordinator = ZenAvatarController
    var speech: ZenSpeechMotion
    var technique: BreathingTechnique?
    var onPhaseChange: ((String, Double) -> Void)?
    var isActive: Bool
    var reduceMotion: Bool
    @Binding var didLoad: Bool
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.environment.background = .color(.clear)
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField]
        view.isUserInteractionEnabled = false
        context.coordinator.configure(view, didLoad: $didLoad, loadFailed: $loadFailed)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        view.isHidden = !isActive
        context.coordinator.speech = isActive ? speech : ZenSpeechMotion()
        context.coordinator.reduceMotion = reduceMotion
        context.coordinator.onPhaseChange = onPhaseChange
        context.coordinator.setTechnique(technique)
        context.coordinator.setActive(isActive)
        if !isActive { context.coordinator.resetPose() }
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.cancel()
        view.scene.anchors.removeAll()
    }

}

@MainActor
final class ZenAvatarController {
        var maxUpdatesPerSecond: Float = 30
        private var pendingDelta: Float = 0
        var speech = ZenSpeechMotion()
        var onPhaseChange: ((String, Double) -> Void)?
        var reduceMotion = false
        private var loader: AnyCancellable?
        private var updates: (any Cancellable)?
        private weak var view: ARView?
        private var isActive = true
        private var technique: BreathingTechnique?
        private var breathStartedAt = ProcessInfo.processInfo.systemUptime
        private var lastPhase = -1
        private struct DeformedPart {
            let entity: ModelEntity
            let isFace: Bool
            var materials: [CustomMaterial]
        }
        private var deformedParts: [DeformedPart] = []
        private var clothAmount: Float = 0
        #if DEBUG
        // Deterministic render checks in the separate QA simulator; no speech or AI.
        private let validatesOpenEyes = ProcessInfo.processInfo.arguments.contains("--zen-avatar-eyes-open")
        private let validatesSpeech = ProcessInfo.processInfo.arguments.contains("--zen-avatar-speech-cycle")
        private let validatesCloseup = ProcessInfo.processInfo.arguments.contains("--zen-avatar-closeup")
        private let diagnosesBreathing = ProcessInfo.processInfo.arguments.contains("--zen-avatar-breath-diagnostics")
        #endif
        private var eyeAmount: Float = 0
        private var nextBlink: Float = 3.4
        private var blinkStarted: Float = -.infinity
        private var camera: PerspectiveCamera?
        private var head: Entity?
        private var headPose = Transform()
        private var elapsed: Float = 0
        private var mouthPose = ZenMouthPose()

        func configure(_ view: ARView, didLoad: Binding<Bool>, loadFailed: Binding<Bool>) {
            self.view = view
            let stage = AnchorEntity(world: .zero)
            let camera = PerspectiveCamera()
            self.camera = camera
            // The reference-textured model is authored for a near-frontal lens.
            // A long lens preserves the face's proportions and the robe silhouette.
            camera.camera.fieldOfViewInDegrees = 12
            camera.look(at: [0, 0.84, 0], from: [0, 0.84, 9.5], relativeTo: nil)
            stage.addChild(camera)

            let key = DirectionalLight()
            key.light.color = .white
            key.light.intensity = 900
            key.look(at: [0, 0.8, 0], from: [-2, 3, 4], relativeTo: nil)
            stage.addChild(key)
            let fill = DirectionalLight()
            fill.light.color = .white
            fill.light.intensity = 450
            fill.look(at: [0, 0.8, 0], from: [3, 2, 1], relativeTo: nil)
            stage.addChild(fill)
            let rim = DirectionalLight()
            rim.light.intensity = 350
            rim.look(at: [0, 0.9, 0], from: [1, 2, -3], relativeTo: nil)
            stage.addChild(rim)
            view.scene.addAnchor(stage)

            load(in: stage, view: view, didLoad: { didLoad.wrappedValue = true },
                 loadFailed: { loadFailed.wrappedValue = true })
        }

        /// Mount the same animated model into any existing scene, without a camera
        /// or another renderer. The caller owns placement and scene lighting.
        func load(in stage: Entity, view: ARView, didLoad: @escaping () -> Void,
                  loadFailed: @escaping () -> Void) {
            self.view = view
            loader = Entity.loadAsync(named: "ZenMinimalist", in: .main)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    if case .failure(let error) = completion {
                        loadFailed()
                        print("Zen avatar could not load: \(error.localizedDescription)")
                    }
                } receiveValue: { [weak self] model in
                    guard let self, self.view != nil else { return }
                    stage.addChild(model)
                    self.head = model.findEntity(named: "HeadPivot")
                    self.configureDeformation(in: model)
                    self.headPose = self.head?.transform ?? Transform()
                    didLoad()
                    self.setActive(self.isActive)
                }
        }

        private func configureDeformation(in model: Entity) {
            guard let device = MTLCreateSystemDefaultDevice(), let library = device.makeDefaultLibrary() else { return }
            let eyelids = try? TextureResource.load(named: "ZenEyelids.png", options: .init(semantic: .raw))
            func visit(_ entity: Entity, shader: String? = nil, eyeSide: Float = 0) {
                let eyeSide: Float = entity.name == "EyeLeftPivot" ? -1 : entity.name == "EyeRightPivot" ? 1 : eyeSide
                let shader = entity.name == "Layered_linen_robe" || entity.name == "Layered linen robe" ? "zenTorso"
                    : entity.name == "AnatomicalHead" ? "zenEyelids" : shader
                if eyeSide != 0, let mesh = entity as? ModelEntity, let component = mesh.model {
                    do {
                        let surface = CustomMaterial.SurfaceShader(named: "zenEyeSurface", in: library)
                        mesh.model?.materials = try component.materials.map { original in
                            var material = try CustomMaterial(from: original, surfaceShader: surface)
                            material.custom.value = [eyeSide, 0, 0, 0]
                            return material
                        }
                    } catch {
                        print("Zen eye shading unavailable: \(error.localizedDescription)")
                    }
                }
                if let shader, (shader != "zenEyelids" || eyelids != nil),
                   let mesh = entity as? ModelEntity, let component = mesh.model {
                    do {
                        let modifier = CustomMaterial.GeometryModifier(named: shader, in: library)
                        let materials = try component.materials.map { original -> CustomMaterial in
                            var material = try CustomMaterial(from: original, geometryModifier: modifier)
                            if shader == "zenEyelids", let eyelids { material.custom.texture = .init(eyelids) }
                            return material
                        }
                        mesh.model?.materials = materials
                        mesh.model?.boundsMargin = 0.06
                        deformedParts.append(DeformedPart(entity: mesh, isFace: shader == "zenEyelids", materials: materials))
                        #if DEBUG
                        if diagnosesBreathing { print("Zen motion: \(mesh.name), shader=\(shader), bounds=\(component.mesh.bounds)") }
                        #endif
                    } catch {
                        print("Zen deformation unavailable: \(error.localizedDescription)")
                    }
                }
                for child in entity.children { visit(child, shader: shader, eyeSide: eyeSide) }
            }
            visit(model)

        }

        private func updateDeformation(breath: Float, eyes: Float, cloth: Float) {
            for index in deformedParts.indices {
                for material in deformedParts[index].materials.indices {
                    deformedParts[index].materials[material].custom.value = deformedParts[index].isFace
                        ? [breath, eyes, mouthPose.rounding, mouthPose.opening]
                        : [breath, eyes, cloth, 0]
                }
                deformedParts[index].entity.model?.materials = deformedParts[index].materials
            }
        }

        func setTechnique(_ value: BreathingTechnique?) {
            guard technique != value else { return }
            technique = value
            breathStartedAt = ProcessInfo.processInfo.systemUptime
            lastPhase = -1
        }

        func setActive(_ active: Bool) {
            isActive = active
            if !active || reduceMotion {
                updates?.cancel()
                updates = nil
                resetPose()
            } else if updates == nil, head != nil, let view {
                updates = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                    self?.animate(delta: Float(event.deltaTime))
                }
            }
        }

        private func animate(delta: Float) {
            pendingDelta += delta
            guard pendingDelta >= 1 / maxUpdatesPerSecond else { return }
            let dt = min(pendingDelta, 0.1)
            pendingDelta = 0
            if let view, view.bounds.width > 0, view.bounds.height > 0 {
                let aspect = Float(view.bounds.width / view.bounds.height)
                camera?.camera.fieldOfViewInDegrees = 2 * atan(max(1.0, 0.98 / aspect) / 9.5) * 180 / .pi
                #if DEBUG
                if validatesCloseup {
                    camera?.look(at: [0, 1.40, 0], from: [0, 1.40, 2], relativeTo: nil)
                    camera?.camera.fieldOfViewInDegrees = 2 * atan(max(0.22, 0.18 / aspect) / 2) * 180 / .pi
                }
                #endif
            }
            let now = ProcessInfo.processInfo.systemUptime
            elapsed += dt
            let sample = ZenBreathMotion.sample(at: now - breathStartedAt, technique: technique ?? .defaultTechnique)
            if technique != nil, sample.index != lastPhase {
                lastPhase = sample.index
                onPhaseChange?(sample.phase, sample.duration)
                #if DEBUG
                if diagnosesBreathing { print("Zen breath: \(sample.phase), duration=\(sample.duration), reduceMotion=\(reduceMotion)") }
                #endif
            }
            // Rib cage and fabric deform locally in the GPU. No whole-body scale.
            let expansion: Float = reduceMotion ? 0 : sample.expansion
            clothAmount += (expansion - clothAmount) * min(1, dt * 4)

            var headTransform = headPose
            if !reduceMotion {
                let nod = simd_quatf(angle: 0.004 * sin(elapsed * 0.7), axis: [1, 0, 0])
                let turn = simd_quatf(angle: 0.005 * sin(elapsed * 0.31), axis: [0, 0, 1])
                headTransform.rotation = headPose.rotation * nod * turn
            }
            headTransform.translation.z += 0.006 * expansion
            head?.transform = headTransform

            let voicing = speech.isVoicing(at: now)
            if voicing && elapsed >= nextBlink {
                blinkStarted = elapsed
                nextBlink = elapsed + Float.random(in: 3.0...6.2)
            }
            let blinkAge = elapsed - blinkStarted
            let blink: Float = blinkAge < 0.20 ? sin(blinkAge / 0.20 * .pi) : 0
            let targetEye: Float = voicing ? 1 : 0
            eyeAmount = reduceMotion ? targetEye : eyeAmount + (targetEye - eyeAmount) * min(1, dt * (voicing ? 24 : 7))
            var aperture = eyeAmount * (reduceMotion ? 1 : 1 - blink)
            #if DEBUG
            if validatesOpenEyes {
                aperture = 1
            }
            #endif
            var target = reduceMotion ? ZenMouthPose() : speech.mouthPose(at: now)
            #if DEBUG
            if validatesSpeech && !reduceMotion {
                let phase = elapsed.truncatingRemainder(dividingBy: 6)
                target = phase < 4
                    ? ZenMouthPose(opening: 0.65 * pow(sin(phase * .pi / 2), 2),
                                   rounding: phase > 2 ? 0.65 * pow(sin(phase * .pi / 2), 2) : 0)
                    : ZenMouthPose()
                aperture = phase < 4 ? 1 - blink : 0
            }
            #endif
            // Frame-rate independent coarticulation; the whole facial surface
            // eases into each sound and returns to its exact rest pose in pauses.
            mouthPose = reduceMotion ? .init() : mouthPose.blended(toward: target, amount: 1 - exp(-dt * 18))
            updateDeformation(breath: expansion, eyes: aperture, cloth: clothAmount)
        }

        func resetPose() {
            mouthPose = .init()
            eyeAmount = 0
            clothAmount = 0
            updateDeformation(breath: 0, eyes: 0, cloth: 0)
            head?.transform = headPose
        }

        func cancel() {
            loader?.cancel()
            updates?.cancel()
            loader = nil
            updates = nil
        }
    }

@MainActor
@Observable
final class ZenAvatarVoice: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let recordedVoice = ZenRecordedVoice()
    private var utterance: AVSpeechUtterance?
    private(set) var avatarSpeech = ZenSpeechMotion()
    private(set) var isPlaying = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(_ text: String = String(localized: "zen.avatar.sample")) {
        stop()
        if let clip = ZenVoiceLibrary.clip(for: text),
           recordedVoice.play(clip, volume: MeditationManager.shared.mimirVoiceVolume,
               onLevel: { [weak self] level in self?.avatarSpeech.speak(level: level) },
               completion: { [weak self] _ in
                   self?.avatarSpeech.stop()
                   self?.isPlaying = false
               }) {
            isPlaying = true
            return
        }
        let speech = AVSpeechUtterance(string: text)
        let savedID = MeditationManager.shared.kaiVoiceIdentifier
        let saved = AVSpeechSynthesisVoice(identifier: savedID)
        let language = AppLocalization.preferredLanguageCodes.first ?? "en"
        speech.voice = saved.flatMap {
            Locale(identifier: $0.language).language.languageCode?.identifier == language
                && !$0.voiceTraits.contains(.isNoveltyVoice)
                && $0.quality != .default ? $0 : nil
        } ?? GuruManager.shared.findBestAvailableVoice()
        speech.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        speech.volume = MeditationManager.shared.mimirVoiceVolume
        utterance = speech
        isPlaying = true
        synthesizer.speak(speech)
    }

    func stop() {
        recordedVoice.stop()
        utterance = nil
        avatarSpeech.stop()
        isPlaying = false
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.utterance === utterance else { return }
            self.avatarSpeech.begin()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        let text = utterance.speechString as NSString
        guard NSMaxRange(range) <= text.length else { return }
        let word = text.substring(with: range)
        Task { @MainActor [weak self] in
            guard let self, self.utterance === utterance else { return }
            self.avatarSpeech.speak(word: word)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {
        guard marker.mark == .phoneme else { return }
        let phoneme = marker.phoneme
        Task { @MainActor [weak self] in
            guard let self, self.utterance === utterance else { return }
            self.avatarSpeech.speak(phoneme: phoneme)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.utterance === utterance else { return }
            self.avatarSpeech.stop()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    nonisolated private func finish(_ utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.utterance === utterance else { return }
            self.utterance = nil
            self.avatarSpeech.stop()
            self.isPlaying = false
        }
    }
}
