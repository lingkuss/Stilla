import SwiftUI
import RealityKit
import Combine
import Metal
import simd

struct MountainJourneyScene: UIViewRepresentable {
    static let transitionDuration: TimeInterval = 3
    let address: MountainPlaceAddress
    let seed: UInt64
    let isActive: Bool
    let guidePreviewFrame: CGRect
    let showsZenGuide: Bool
    let isMeditating: Bool
    let reduceMotion: Bool
    let economical: Bool
    let daylight: MountainDaylight
    let speech: ZenSpeechMotion
    @Binding var isReady: Bool
    @Binding var isMoving: Bool
    @Binding var loadFailed: Bool
    @Binding var avatarFailed: Bool
    @Binding var veil: Double
    var onArrival: (MountainPlaceAddress) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero,cameraMode: .nonAR,automaticallyConfigureSession: false)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.environment.background = .color(.clear)
        view.renderOptions = [.disableMotionBlur,.disableDepthOfField,.disableCameraGrain]
        view.isUserInteractionEnabled = false
        context.coordinator.configure(view)
        return view
    }
    func updateUIView(_ view: ARView,context: Context) {
        let c=context.coordinator
        c.onReady={ isReady=$0 }; c.onMoving={ isMoving=$0 }
        c.onFailure={ loadFailed=true }; c.onAvatarFailure={ avatarFailed=true }
        c.onVeil={ veil=$0 }; c.onArrival=onArrival
        c.showsZenGuide=showsZenGuide
        c.reduceMotion=reduceMotion
        c.setSurfaceMotion(enabled: !reduceMotion && !economical)
        c.avatar.reduceMotion=reduceMotion
        c.avatar.maxUpdatesPerSecond=economical ? 15 : 30
        c.avatar.speech=speech
        c.setDaylight(daylight)
        c.setGuidePreviewFrame(guidePreviewFrame)
        c.setActive(isActive)
        c.focusMeditation(isMeditating)
        if !isMeditating { c.show(address: address,seed: seed,economical: economical) }
    }
    static func dismantleUIView(_ view: ARView,coordinator: Coordinator) {
        coordinator.cancel(); view.scene.anchors.removeAll()
    }
    @MainActor final class Coordinator {
        var onReady: ((Bool)->Void)?
        var onMoving: ((Bool)->Void)?
        var onFailure: (()->Void)?
        var onAvatarFailure: (()->Void)?
        var onVeil: ((Double)->Void)?
        var onArrival: ((MountainPlaceAddress)->Void)?
        var reduceMotion=false
        var showsZenGuide=true
        let avatar=ZenAvatarController()
        private let anchor=AnchorEntity(world: .zero)
        private let guide=Entity()
        private let camera=PerspectiveCamera()
        private let key=DirectionalLight()
        private let fill=DirectionalLight()
        private var daylight=MountainDaylight(hour: 12)
        private var avatarRequested=false
        private var surfaceMotion=true
        private var hoverElapsed: Float=0
        private var guidePreviewFrame: CGRect = .zero
        private var world: Entity?
        private var outgoingWorld: Entity?
        private var sourceDNA: MountainWorldDNA?
        private var requestedSeed: UInt64?
        private weak var view: ARView?
        private var generation: Task<Void,Never>?
        private var updates: (any Cancellable)?
        private var requested: MountainPlaceAddress?
        private var arrived: MountainPlaceAddress?
        private var builtEconomical: Bool?
        private var dna: MountainWorldDNA?
        private var active=true
        private var meditating=false
        private var preparing=false
        private var generationID=UUID()
        private var transition: MountainPlaceAddress?
        private var elapsed: Float=0
        private var lastUptime: TimeInterval=0
        private var shader: CustomMaterial.SurfaceShader?

        func configure(_ view: ARView) {
            self.view=view
            camera.camera.fieldOfViewInDegrees=55
            camera.camera.near=0.1; camera.camera.far=850
            anchor.addChild(camera); anchor.addChild(guide)
            guide.scale=SIMD3(repeating: 1.6)
            guide.isEnabled=false
            view.scene.addAnchor(anchor)
            anchor.addChild(key); anchor.addChild(fill)
            fill.look(at: .zero,from: [3,2,2],relativeTo: nil)
            updateLighting()
            if let library=MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() {
                shader = .init(named: "mountainWildSurface",in: library)
            }
        }
        func show(address: MountainPlaceAddress,seed: UInt64,economical: Bool) {
            guard active, requested != address || requestedSeed != seed || builtEconomical != economical else { return }
            let initial=world == nil, changed=arrived != address
            requested=address; requestedSeed=seed; builtEconomical=economical
            generation?.cancel(); generationID=UUID()
            let ticket=generationID
            generation=Task { [weak self] in
                guard let self else { return }
                preparing=true
                defer { if generationID == ticket { preparing=false } }
                do {
                    onMoving?(true)
                    let dna=MountainWorldDNA(seed: seed,address: address)
                    let builder=Task.detached(priority: .userInitiated) {
                        MountainWildMesh.build(dna,economical: economical)
                    }
                    let batches=await withTaskCancellationHandler {
                        await builder.value
                    } onCancel: { builder.cancel() }
                    try Task.checkCancellation()
                    let entity=try await makeEntity(batches,dna: dna)
                    try Task.checkCancellation()
                    outgoingWorld?.removeFromParent()
                    outgoingWorld=world
                    sourceDNA=self.dna
                    world=entity; anchor.addChild(entity)
                    self.dna=dna
                    onReady?(true); onVeil?(0)
                    if initial || reduceMotion || !changed { finish(address) }
                    else {
                        transition=address; elapsed=0
                        blendWorlds(0)
                        placeCamera(travel: 1); updateGuideActivity(); subscribe()
                    }
                    #if DEBUG
                    print("Mountain DNA: \(String(dna.code,radix: 16)), triangles=\(batches.reduce(0) { $0+$1.positions.count/3 }), economical=\(economical)")
                    #endif
                } catch is CancellationError { }
                catch {
                    onFailure?(); onMoving?(false); onVeil?(0)
                    print("Wild landscape failed: \(error.localizedDescription)")
                }
            }
        }
        private func makeEntity(_ batches: [MountainMeshBatch],dna: MountainWorldDNA) async throws -> Entity {
            guard let shader else { throw LandscapeError.noMetal }
            let root=Entity(), colors=dna.palette
            for (index,batch) in batches.enumerated() where !batch.positions.isEmpty {
                try Task.checkCancellation()
                var descriptor=MeshDescriptor(name: "world.dna.\(index)")
                descriptor.positions=MeshBuffers.Positions(batch.positions)
                descriptor.normals=MeshBuffers.Normals(batch.normals)
                if index == 6 {
                    descriptor.textureCoordinates=MeshBuffers.TextureCoordinates(Array(repeating: dna.floorDNA.shaderTraits,count: batch.positions.count))
                }
                descriptor.primitives = .triangles(Array(0..<UInt32(batch.positions.count)))
                let mesh=try MeshResource.generate(from: [descriptor])
                var material=try CustomMaterial(surfaceShader: shader,lightingModel: .unlit)
                let color=colors[index]
                material.baseColor = .init(tint: UIColor(red: CGFloat(color.x),green: CGFloat(color.y),blue: CGFloat(color.z),alpha: 1))
                material.custom.value=[index == 6 && !surfaceMotion ? -6 : Float(index),dna.hue,daylight.hour,0]
                material.faceCulling = .none
                root.addChild(ModelEntity(mesh: mesh,materials: [material]))
                await Task.yield()
            }
            return root
        }
        func setGuidePreviewFrame(_ frame: CGRect) {
            guard guidePreviewFrame != frame else { return }
            guidePreviewFrame=frame
            updateGuideActivity()
        }
        func focusMeditation(_ value: Bool) {
            if meditating != value {
                meditating=value; hoverElapsed=0
                if transition == nil { placeCamera() }
            }
            updateGuideActivity()
        }
        private func placeGuide() {
            guard let dna else { return }
            let hover: Float=reduceMotion ? 0 : sin(hoverElapsed*2 * .pi/10)
            if meditating {
                if guide.parent !== anchor { guide.setParent(anchor) }
                guide.scale=SIMD3(repeating: 1.6)
                guide.orientation=simd_quatf(angle: 0,axis: [0,1,0])
                guide.position=dna.guide+[0,hover*0.06,0]
            } else if let view,view.bounds.height>0,view.bounds.width>0,!guidePreviewFrame.isEmpty {
                // Project the SwiftUI dock's measured frame into the existing camera.
                // One model and one renderer, always facing the viewer head-on.
                let frame=view.convert(guidePreviewFrame,from: nil)
                let distance: Float=2
                let halfHeight=tan(camera.camera.fieldOfViewInDegrees * .pi/360)*distance
                let unitsPerPoint=2*halfHeight/Float(view.bounds.height)
                let scale=min(Float(frame.height)/1.68,Float(frame.width)/1.98)*unitsPerPoint
                let x=Float(frame.midX-view.bounds.midX)*unitsPerPoint
                let y=Float(view.bounds.midY-frame.midY)*unitsPerPoint
                if guide.parent !== camera { guide.setParent(camera) }
                guide.scale=SIMD3(repeating: scale)
                guide.orientation=simd_quatf(angle: 0,axis: [0,1,0])
                guide.position=[x,y-0.84*scale+hover*scale*0.025,-distance]
            }
        }
        private func updateGuideActivity() {
            guide.isEnabled=active && showsZenGuide && dna != nil && (meditating || !guidePreviewFrame.isEmpty)
            if guide.isEnabled,!avatarRequested,let view {
                avatarRequested=true
                avatar.load(in: guide,view: view,didLoad: {},loadFailed: { [weak self] in self?.onAvatarFailure?() })
            }
            placeGuide()
            avatar.setActive(guide.isEnabled)
            if active && (transition != nil || (guide.isEnabled && !reduceMotion)) { subscribe() }
            else { updates?.cancel(); updates=nil }
        }
        func setSurfaceMotion(enabled: Bool) {
            guard surfaceMotion != enabled else { return }
            surfaceMotion=enabled
            for root in [world,outgoingWorld] {
                guard let root else { continue }
                for child in root.children {
                    guard let model=child as? ModelEntity,var component=model.model else { continue }
                    component.materials=component.materials.map { original in
                        guard var material=original as? CustomMaterial,abs(material.custom.value.x)==6 else { return original }
                        material.custom.value.x=enabled ? 6 : -6
                        return material
                    }
                    model.model=component
                }
            }
        }
        func setDaylight(_ value: MountainDaylight) {
            guard daylight != value else { return }
            daylight=value; updateLighting()
            setHour(world); setHour(outgoingWorld)
        }
        private func updateLighting() {
            let d=daylight.sunDirection
            key.look(at: .zero,from: d*10,relativeTo: nil)
            key.light.intensity=1100*daylight.daylight
            key.light.color=UIColor(red: 1,green: CGFloat(0.96-daylight.twilight*0.23),blue: CGFloat(0.88-daylight.twilight*0.36),alpha: 1)
            fill.look(at: .zero,from: -d*10,relativeTo: nil)
            fill.light.color=UIColor(red: 0.58,green: 0.69,blue: 1,alpha: 1)
            fill.light.intensity=280-100*daylight.daylight
        }
        private func setHour(_ entity: Entity?) {
            guard let entity else { return }
            for child in entity.children {
                guard let model=child as? ModelEntity,var component=model.model else { continue }
                component.materials=component.materials.map { original in
                    guard var material=original as? CustomMaterial else { return original }
                    material.custom.value.z=daylight.hour
                    return material
                }
                model.model=component
            }
        }
        private func placeCamera(travel: Float=0) {
            guard let dna else { return }
            if meditating {
                // Match the model's front (+Z) and seated visual centre. Keep the
                // camera still so the gentle hover remains visible in the frame.
                let centre=dna.guide+[0,Float(0.84)*1.6,0]
                camera.look(at: centre,from: centre+[0,0,7.5],relativeTo: nil)
            } else {
                let previous=sourceDNA ?? dna
                let from=simd_mix(dna.cameraPosition,previous.cameraPosition,SIMD3(repeating: travel))
                let target=simd_mix(dna.cameraTarget,previous.cameraTarget,SIMD3(repeating: travel))
                // A small forward arc accompanies the spatial change, ending at a stable seat.
                let arc=SIMD3<Float>(sin(travel * .pi)*1.2,0,sin(travel * .pi)*2)
                camera.look(at: target,from: from+arc,relativeTo: nil)
            }
        }
        private func subscribe() {
            guard active,(transition != nil || (guide.isEnabled && !reduceMotion)),updates == nil,let view else { return }
            lastUptime=ProcessInfo.processInfo.systemUptime
            updates=view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in self?.tick() }
        }
        private func tick() {
            let now=ProcessInfo.processInfo.systemUptime,delta=now-lastUptime
            guard delta >= 1.0/Double(avatar.maxUpdatesPerSecond) else { return }
            lastUptime=now
            guard let transition else {
                if guide.isEnabled,!reduceMotion {
                    hoverElapsed+=Float(min(delta,0.1))
                    placeGuide()
                }
                return
            }
            elapsed+=Float(delta)
            let t=reduceMotion ? 1 : min(1,elapsed/Float(MountainJourneyScene.transitionDuration))
            let eased=t*t*t*(t*(t*6-15)+10)
            blendWorlds(eased)
            placeCamera(travel: 1-eased)
            if t >= 1 { finish(transition) }
        }
        private func blendWorlds(_ progress: Float) {
            setBlend(world,value: 1+progress)
            setBlend(outgoingWorld,value: -1-progress)
        }
        private func setBlend(_ entity: Entity?,value: Float) {
            guard let entity else { return }
            for child in entity.children {
                guard let model=child as? ModelEntity, var component=model.model else { continue }
                component.materials=component.materials.map { original in
                    guard var material=original as? CustomMaterial else { return original }
                    material.custom.value.w=value
                    return material
                }
                model.model=component
            }
        }
        private func finish(_ address: MountainPlaceAddress) {
            outgoingWorld?.removeFromParent(); outgoingWorld=nil; sourceDNA=nil
            setBlend(world,value: 0)
            transition=nil; updates?.cancel(); updates=nil; arrived=address
            placeCamera()
            updateGuideActivity()
            onMoving?(false); onArrival?(address)
        }
        func setActive(_ value: Bool) {
            active=value; view?.isHidden = !value
            updateGuideActivity()
            if value { subscribe() }
            else {
                updates?.cancel(); updates=nil
                if preparing { generation?.cancel(); requested=nil }
            }
        }
        func cancel() {
            generation?.cancel(); generation=nil; updates?.cancel(); updates=nil; avatar.cancel()
            onReady=nil; onMoving=nil; onFailure=nil; onAvatarFailure=nil; onVeil=nil; onArrival=nil
        }
        private enum LandscapeError: Error { case noMetal }
    }
}
