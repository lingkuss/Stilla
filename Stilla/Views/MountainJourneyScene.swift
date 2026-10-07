import SwiftUI
import RealityKit
import Combine
import Metal
import simd

/// Two prepared worlds share immutable GPU resources with the live scene. CPU
/// batches are discarded after upload; repeated openings do not rebuild meshes.
@MainActor final class MountainWorldResources {
    static let shared=MountainWorldResources()
    struct Key: Hashable {
        let address: MountainPlaceAddress
        let seed: UInt64
        let economical: Bool
    }
    struct Prepared {
        let dna: MountainWorldDNA
        let economical: Bool
        let meshes: [(index: Int,mesh: MeshResource)]
        let triangles: Int
    }
    private var ready: [Key: Prepared]=[:]
    private var order: [Key]=[]
    private var pending: [Key: Task<Prepared,Error>]=[:]
    private var tickets: [Key: UUID]=[:]
    private var pendingOrder: [Key]=[]
    private var genomes: [(seed: UInt64,address: MountainPlaceAddress,dna: MountainWorldDNA)]=[]
    private var memoryObserver: NSObjectProtocol?
    private init() {
        memoryObserver=NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,queue: .main) { [weak self] _ in
                Task { @MainActor in self?.ready.removeAll(); self?.order.removeAll() }
            }
    }
    static var economical: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--mountain-economical") { return true }
        #endif
        let info=ProcessInfo.processInfo
        return info.isLowPowerModeEnabled || info.thermalState == .serious || info.thermalState == .critical
    }
    static func visualSeed(_ saved: UInt64) -> UInt64 {
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if let i=args.firstIndex(of: "--mountain-world"),args.indices.contains(i+1),let seed=UInt64(args[i+1]) { return seed }
        #endif
        return saved
    }
    func genome(seed: UInt64,address: MountainPlaceAddress) -> MountainWorldDNA {
        if let hit=genomes.first(where: { $0.seed==seed && $0.address==address }) { return hit.dna }
        let dna=MountainWorldDNA(seed: seed,address: address)
        remember(dna,seed: seed,address: address)
        return dna
    }
    private func remember(_ dna: MountainWorldDNA,seed: UInt64,address: MountainPlaceAddress) {
        genomes.removeAll { $0.seed==seed && $0.address==address }
        genomes.append((seed,address,dna))
        if genomes.count>3 { genomes.removeFirst() }
    }
    func prepare(_ key: Key) async throws -> Prepared {
        if let hit=ready[key] {
            order.removeAll { $0==key }; order.append(key)
            #if DEBUG
            print("Mountain resources: cache hit, \(key.address)")
            #endif
            return hit
        }
        if let task=pending[key] { return try await task.value }
        // Release older speculative resources before preparing a replacement.
        while ready.count+pending.count>=2,let oldest=order.first {
            ready[oldest]=nil; order.removeFirst()
        }
        if pending.count>=2,let oldest=pendingOrder.first {
            pending[oldest]?.cancel(); pending[oldest]=nil; tickets[oldest]=nil; pendingOrder.removeFirst()
        }
        let ticket=UUID()
        let started=ProcessInfo.processInfo.systemUptime
        let task=Task { @MainActor () throws -> Prepared in
            let cpu=Task.detached(priority: .userInitiated) {
                let dna=MountainWorldDNA(seed: key.seed,address: key.address)
                return (dna,MountainWildMesh.build(dna,economical: key.economical))
            }
            let (dna,batches)=await withTaskCancellationHandler { await cpu.value } onCancel: { cpu.cancel() }
            try Task.checkCancellation()
            var meshes: [(index: Int,mesh: MeshResource)]=[]
            for (index,batch) in batches.enumerated() where !batch.positions.isEmpty {
                try Task.checkCancellation()
                var descriptor=MeshDescriptor(name: "world.dna.\(index)")
                descriptor.positions=MeshBuffers.Positions(batch.positions)
                descriptor.normals=MeshBuffers.Normals(batch.normals)
                if index==6 {
                    descriptor.textureCoordinates=MeshBuffers.TextureCoordinates(Array(repeating: dna.floorDNA.shaderTraits,count: batch.positions.count))
                }
                descriptor.primitives = .triangles(Array(0..<UInt32(batch.positions.count)))
                meshes.append((index,try MeshResource.generate(from: [descriptor])))
                await Task.yield()
            }
            return Prepared(dna: dna,economical: key.economical,meshes: meshes,
                            triangles: batches.reduce(0) { $0+$1.positions.count/3 })
        }
        pending[key]=task; tickets[key]=ticket; pendingOrder.append(key)
        do {
            let result=try await task.value
            guard tickets[key]==ticket else { throw CancellationError() }
            pending[key]=nil; tickets[key]=nil; pendingOrder.removeAll { $0==key }
            remember(result.dna,seed: key.seed,address: key.address)
            ready[key]=result; order.removeAll { $0==key }; order.append(key)
            while order.count>2 { ready[order.removeFirst()]=nil }
            #if DEBUG
            print("Mountain resources: prepared in \(Int((ProcessInfo.processInfo.systemUptime-started)*1000))ms, retained=\(ready.count)")
            #endif
            return result
        } catch {
            if tickets[key]==ticket { pending[key]=nil; tickets[key]=nil; pendingOrder.removeAll { $0==key } }
            throw error
        }
    }
    func cancelPending() {
        for task in pending.values { task.cancel() }
        pending.removeAll(); pendingOrder.removeAll(); tickets.removeAll()
    }
    #if DEBUG
    static func prewarmCurrent() async {
        let store=MountainJourneyStore.shared
        guard !store.storageUnavailable else { return }
        let key=Key(address: store.progress.current,seed: visualSeed(store.progress.seed),economical: economical)
        let guide=UserDefaults.standard.string(forKey: "mountain.prototype.guide.v1") ?? KaiPersonality.default.id
        async let world: Prepared? = try? shared.prepare(key)
        if let asset=GuideAvatarAsset.asset(for: guide) { await GuideAvatarModelCache.shared.prewarm(asset) }
        _=await world
    }
    #endif
}

struct MountainJourneyScene: UIViewRepresentable {
    static let transitionDuration: TimeInterval = 3
    let address: MountainPlaceAddress
    let seed: UInt64
    let isActive: Bool
    let specimens: [GardenSpecimen]
    let pausesWorldChanges: Bool
    let guidePreviewFrame: CGRect
    let guides: [KaiPersonality]
    let selectedGuideID: String
    let guideSelection: Float?
    let isDraggingGuide: Bool
    let guideCreationPlacement: GuideCreationPlacement
    let meditationSession: MountainSessionContext?
    let breathingTechnique: BreathingTechnique
    private var isMeditating: Bool { meditationSession != nil }
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
        c.onFailure={ loadFailed=true }; c.onAvatarFailure={ avatarFailed=$0 }
        c.onVeil={ veil=$0 }; c.onArrival=onArrival
        c.guideCreationPlacement=guideCreationPlacement
        c.guides=guides
        c.selectedGuideID=selectedGuideID
        c.reduceMotion=reduceMotion
        c.setSurfaceMotion(enabled: !reduceMotion && !economical)
        c.avatarFPS=economical ? 15 : 30
        c.avatarSpeech=speech
        c.breathingTechnique=breathingTechnique
        c.setDaylight(daylight)
        c.setGuidePreviewFrame(guidePreviewFrame)
        c.setWorldInteraction(pausesWorldChanges)
        c.setActive(isActive)
        c.setSpecimens(specimens)
        c.focusMeditation(meditationSession)
        c.setGuideSelection(guideSelection, isDragging: isDraggingGuide)
        if !pausesWorldChanges && !isMeditating && guideSelection == nil { c.show(address: address,seed: seed,economical: economical) }
        // A drag updates this representable every frame. Refresh controllers
        // once after all inputs are set, rather than once per setter.
        c.updateGuideActivity()
    }
    static func dismantleUIView(_ view: ARView,coordinator: Coordinator) {
        coordinator.cancel(); view.scene.anchors.removeAll()
    }
    @MainActor final class Coordinator {
        var onReady: ((Bool)->Void)?
        var onMoving: ((Bool)->Void)?
        var onFailure: (()->Void)?
        var onAvatarFailure: ((Bool)->Void)?
        var onVeil: ((Double)->Void)?
        var onArrival: ((MountainPlaceAddress)->Void)?
        weak var guideCreationPlacement: GuideCreationPlacement?
        var reduceMotion=false
        var guides = KaiPersonality.all
        var selectedGuideID=KaiPersonality.zenMinimalist.id
        var avatarFPS: Float=30
        var avatarSpeech=ZenSpeechMotion()
        var breathingTechnique=BreathingTechnique.defaultTechnique
        @MainActor private final class AvatarInstance {
            let entity=Entity()
            let controller: GuideAvatarController
            var requested=false
            var loaded=false
            var failed=false
            init(_ asset: GuideAvatarAsset) { controller=GuideAvatarController(asset: asset) }
        }
        private var avatars: [String: AvatarInstance]=[:]
        private var cutouts: [String: ModelEntity]=[:]
        private var failedCutouts: Set<String>=[]
        private var reportedAvatarFailure=false
        private let anchor=AnchorEntity(world: .zero)
        private let camera=PerspectiveCamera()
        private let key=DirectionalLight()
        private let fill=DirectionalLight()
        private var daylight=MountainDaylight(hour: 12)
        private var surfaceMotion=true
        private var hoverElapsed: Float=0
        private var guidePreviewFrame: CGRect = .zero
        private var world: Entity?
        private var outgoingWorld: Entity?
        private var sourceDNA: MountainWorldDNA?
        private var requestedSeed: UInt64?
        private weak var view: ARView?
        private var generation: Task<Void,Never>?
        private var prefetch: Task<Void,Never>?
        private var hasPresented=false
        private var updates: (any Cancellable)?
        private var requested: MountainPlaceAddress?
        private var arrived: MountainPlaceAddress?
        private var builtEconomical: Bool?
        private var dna: MountainWorldDNA?
        private var active=true
        private var meditating=false
        private var meditationID: UUID?
        private var meditationJourney=MountainMeditationJourney(durationSeconds: 600)
        private var meditationTravelTime: TimeInterval=0
        private var meditationEntrance=Transform.identity
        private var preparing=false
        private var worldInteraction=false
        private var generationID=UUID()
        private var transition: MountainPlaceAddress?
        private var elapsed: Float=0
        private var lastUptime: TimeInterval=0
        // These guides stay fixed in the world. Only the camera moves sideways.
        private let gallery=Entity()
        private var galleryBase=Transform.identity
        private var galleryOrigin: Float=0
        private var galleryTarget: Float?
        private var galleryDragging=false
        private var galleryPosition: Float=0
        private var galleryFocus: Float=0
        private var galleryPortraits: [Int: ModelEntity]=[:]
        private var galleryTask: Task<Void,Never>?
        // Leave breathing room between full-width seated guides and portraits.
        // Camera travel uses the same spacing, keeping each selection centred.
        private let gallerySpacing: Float=2.6
        private var galleryAnimating: Bool {
            abs(galleryFocus-(galleryTarget == nil ? 0 : 1))>0.001 ||
            (galleryTarget.map { abs($0-galleryPosition)>0.001 } ?? false)
        }
        private var shader: CustomMaterial.SurfaceShader?
        private var specimens: [GardenSpecimen] = []
        private var rewardTask: Task<Void,Never>?
        private var terrainTriangles = 0

        func configure(_ view: ARView) {
            self.view=view
            camera.camera.fieldOfViewInDegrees=55
            camera.camera.near=0.1; camera.camera.far=MountainWildMesh.horizonDistance+600
            anchor.addChild(camera); anchor.addChild(gallery)
            gallery.isEnabled=false
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
            let started=ProcessInfo.processInfo.systemUptime
            requested=address; requestedSeed=seed; builtEconomical=economical
            generation?.cancel(); generationID=UUID()
            let ticket=generationID
            generation=Task { [weak self] in
                guard let self else { return }
                preparing=true
                defer { if generationID == ticket { preparing=false } }
                do {
                    onMoving?(true)
                    let prepared=try await MountainWorldResources.shared.prepare(.init(address: address,seed: seed,economical: economical))
                    try Task.checkCancellation()
                    let entity=try await makeEntity(prepared)
                    try Task.checkCancellation()
                    outgoingWorld?.removeFromParent()
                    outgoingWorld=world
                    sourceDNA=self.dna
                    world=entity; anchor.addChild(entity)
                    self.dna=prepared.dna
                    onVeil?(0)
                    if initial || reduceMotion || !changed { finish(address) }
                    else {
                        transition=address; elapsed=0
                        blendWorlds(0)
                        placeCamera(travel: 1); updateGuideActivity(); subscribe()
                    }
                    #if DEBUG
                    print("Mountain scene: installed in \(Int((ProcessInfo.processInfo.systemUptime-started)*1000))ms; DNA=\(String(prepared.dna.code,radix: 16)), triangles=\(prepared.triangles), economical=\(economical)")
                    #endif
                } catch is CancellationError { }
                catch {
                    onFailure?(); onMoving?(false); onVeil?(0)
                    print("Wild landscape failed: \(error.localizedDescription)")
                }
            }
        }
        private func makeEntity(_ prepared: MountainWorldResources.Prepared) async throws -> Entity {
            guard let shader else { throw LandscapeError.noMetal }
            let dna=prepared.dna
            let root=Entity(), colors=dna.palette
            for (index,mesh) in prepared.meshes {
                try Task.checkCancellation()
                var material=try CustomMaterial(surfaceShader: shader,lightingModel: .unlit)
                let color=colors[index]
                material.baseColor = .init(tint: UIColor(red: CGFloat(color.x),green: CGFloat(color.y),blue: CGFloat(color.z),alpha: 1))
                // Hue occupies [0,1); the higher bit selects the economical
                // optical branch without adding uniforms or update work.
                material.custom.value=[index == 6 && !surfaceMotion ? -6 : Float(index),
                                       dna.hue+(prepared.economical ? 2 : 0),daylight.hour,0]
                // A restrained translucent trial across the scenery. Opacity
                // is authored per surface in the shader; geometry stays batched.
                material.blending = prepared.economical ? .opaque : .transparent(opacity: .init(floatLiteral: 1))
                material.faceCulling = (18...21).contains(index) ? .none : .back
                root.addChild(ModelEntity(mesh: mesh,materials: [material]))
                await Task.yield()
            }
            terrainTriangles = prepared.triangles
            let rewards = try await rewardEntities(dna: dna, economical: builtEconomical ?? false)
            for reward in rewards { root.addChild(reward) }
            return root
        }
        func setSpecimens(_ value: [GardenSpecimen]) {
            guard value != specimens else { return }
            specimens = value
            rewardTask?.cancel()
            guard let dna, let world else { return }
            rewardTask = Task { [weak self, weak world] in
                guard let self, let world else { return }
                do {
                    let rewards = try await rewardEntities(dna: dna, economical: builtEconomical ?? false)
                    try Task.checkCancellation()
                    guard world === self.world else { return }
                    for child in Array(world.children) where child.name.hasPrefix("garden.") { child.removeFromParent() }
                    for reward in rewards { world.addChild(reward) }
                } catch is CancellationError { }
                catch { onFailure?() }
            }
        }
        private func rewardEntities(dna: MountainWorldDNA, economical: Bool) async throws -> [ModelEntity] {
            guard !specimens.isEmpty else { return [] }
            guard let shader else { throw LandscapeError.noMetal }
            let saved = specimens
            let budget = min(economical ? 28_000 : 70_000,max(0,248_000-terrainTriangles))
            let worker = Task.detached(priority: .userInitiated) {
                GardenGeometry.world(saved,dna: dna,economical: economical,triangleBudget: budget)
            }
            let batches = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            try Task.checkCancellation()
            #if DEBUG
            print("Garden world: \(saved.count) candidates, \(batches.reduce(0) { $0+$1.triangleCount }) triangles, budget=\(budget)")
            #endif
            var result: [ModelEntity] = []
            for (index,batch) in batches.enumerated() where !batch.positions.isEmpty {
                var descriptor = MeshDescriptor(name: "garden.\(index)")
                descriptor.positions = MeshBuffers.Positions(batch.positions)
                descriptor.normals = MeshBuffers.Normals(batch.normals)
                descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(batch.pigments)
                descriptor.primitives = .triangles(batch.indices)
                let mesh = try MeshResource.generate(from: [descriptor])
                var material = try CustomMaterial(surfaceShader: shader,lightingModel: .unlit)
                material.custom.value = [Float(30+index),0,daylight.hour,0]
                material.blending = .opaque
                material.faceCulling = .none
                let entity = ModelEntity(mesh: mesh,materials: [material])
                entity.name = "garden.\(index)"
                result.append(entity)
                await Task.yield()
                try Task.checkCancellation()
            }
            return result
        }
        func setWorldInteraction(_ value: Bool) {
            guard worldInteraction != value else { return }
            worldInteraction=value
            guard value else { prefetchNextWorld(); return }
            prefetch?.cancel(); prefetch=nil
            MountainWorldResources.shared.cancelPending()
            // Controls can open immediately. Cancel unfinished preparation and
            // invalidate its ticket before it can install a mesh behind a session.
            generation?.cancel(); generation=nil; generationID=UUID(); preparing=false
            if let transition {
                // The incoming mesh is ready: settle it before focusing the guide.
                finish(transition)
            } else if let arrived {
                // Keep the last complete world if preparation has not finished.
                requested=arrived
                onArrival?(arrived)
                onMoving?(false)
            }
        }
        func setGuideSelection(_ selection: Float?, isDragging: Bool) {
            let bounded=selection.map { min(Float(guides.count-1),max(-1,$0)) }
            let dragging=isDragging && bounded != nil
            guard galleryTarget != bounded || galleryDragging != dragging else { return }
            if let bounded,galleryTarget == nil {
                // Capture the same viewpoint so entering doesn't replace the landscape.
                placeCamera()
                galleryBase=camera.transform
                galleryOrigin=bounded.rounded(); galleryPosition=bounded
                gallery.transform=galleryBase
                prepareGallery()
            }
            galleryTarget=bounded
            galleryDragging=dragging
            // Direct manipulation must track the finger, not chase it through
            // the settling animation. Only releasing or using arrows eases.
            if dragging,let bounded { galleryPosition=bounded }
            if reduceMotion {
                galleryFocus=bounded == nil ? 0 : 1
                if let bounded { galleryPosition=bounded }
            }
            placeCamera()
        }
        private func prepareGallery() {
            guard galleryTask == nil,galleryPortraits.isEmpty else { return }
            galleryTask=Task { [weak self] in
                guard let self else { return }
                defer { galleryTask=nil }
                do {
                    // Small shared disc geometry; texture uploads are spread across yields.
                    var descriptor=MeshDescriptor(name: "guide.portrait")
                    var points: [SIMD3<Float>]=[[0,0,0]]
                    var uv: [SIMD2<Float>]=[[0.5,0.5]]
                    var indices: [UInt32]=[]
                    for i in 0...64 {
                        let a=Float(i)/64 * 2 * Float.pi
                        points.append([cos(a)*1.1,sin(a)*1.1,0])
                        uv.append([0.5+cos(a)*0.5,0.5+sin(a)*0.5])
                        if i>0 { indices += [0,UInt32(i),UInt32(i+1)] }
                    }
                    descriptor.positions=MeshBuffers.Positions(points)
                    descriptor.normals=MeshBuffers.Normals(Array(repeating: [0,0,1],count: points.count))
                    descriptor.textureCoordinates=MeshBuffers.TextureCoordinates(uv)
                    descriptor.primitives = .triangles(indices)
                    let mesh=try MeshResource.generate(from: [descriptor])
                    for (index,personality) in guides.enumerated() {
                        try Task.checkCancellation()
                        guard !CustomGuideCatalog.isCustomID(personality.id), let original=GuideArtwork.uiImage(named: personality.imageName) else { continue }
                        let format=UIGraphicsImageRendererFormat(); format.scale=1
                        let portrait=UIGraphicsImageRenderer(size: CGSize(width: 512,height: 512),format: format).image { _ in
                            original.draw(in: CGRect(x: 0,y: 0,width: 512,height: 512))
                        }
                        guard let cg=portrait.cgImage else { continue }
                        let texture=try TextureResource.generate(from: cg,options: .init(semantic: .color))
                        var material=UnlitMaterial()
                        material.color = .init(tint: .white,texture: .init(texture))
                        let entity=ModelEntity(mesh: mesh,materials: [material])
                        galleryPortraits[index]=entity; gallery.addChild(entity)
                        placeGallery()
                        await Task.yield()
                    }
                } catch { print("Guide gallery unavailable: \(error.localizedDescription)") }
            }
        }
        private func placeGallery() {
            gallery.isEnabled=active && galleryTarget != nil
            for (index,entity) in galleryPortraits {
                let instance=avatars[guides[index].id]
                let modelReady=(instance?.loaded == true && instance?.failed == false)
                    || cutouts[guides[index].id] != nil
                entity.isEnabled=abs(Float(index)-galleryPosition)<2 && !modelReady
                let hover: Float=reduceMotion ? 0 : sin(hoverElapsed * 2 * .pi/10+Float(index)*0.7)*0.035
                entity.position=[(Float(index)-galleryOrigin)*gallerySpacing,0.35+hover,-8]
            }
        }
        func setGuidePreviewFrame(_ frame: CGRect) {
            guard guidePreviewFrame != frame else { return }
            guidePreviewFrame=frame
        }
        func focusMeditation(_ session: MountainSessionContext?) {
            if meditationID != session?.id {
                meditationEntrance=camera.transform
                meditationID=session?.id
                meditating=session != nil; hoverElapsed=0; meditationTravelTime=reduceMotion ? 4 : 0
                meditationJourney=MountainMeditationJourney(durationSeconds: session?.durationSeconds ?? 600)
                if transition == nil { placeCamera() }
            }
        }
        private func placeGuide() {
            guard dna != nil else { return }
            let hover: Float=reduceMotion ? 0 : sin(hoverElapsed*2 * .pi/10)
            let renderedGuides=avatars.map { ($0.key,$0.value.entity) }
                + cutouts.map { ($0.key,$0.value as Entity) }
            for (id,guide) in renderedGuides {
                if galleryTarget != nil {
                    if guide.parent !== gallery { guide.setParent(gallery) }
                    guide.scale=SIMD3(repeating: 1.3)
                    guide.orientation=simd_quatf(angle: 0,axis: [0,1,0])
                    let index=Float(guides.firstIndex(where: { $0.id == id }) ?? 0)
                    guide.position=[(index-galleryOrigin)*gallerySpacing,-0.84*1.3+0.35+hover*0.035,-8]
                } else if id == selectedGuideID && meditating {
                    // Camera-relative placement keeps every guide front-facing
                    // and centred as the route turns, with only a gentle hover.
                    if guide.parent !== camera { guide.setParent(camera) }
                    guide.scale=SIMD3(repeating: 1.6)
                    guide.orientation=simd_quatf(angle: 0,axis: [0,1,0])
                    guide.position=[0,-0.84*1.6+hover*0.06,-7.5]
                } else if id == selectedGuideID,let view,view.bounds.height>0,view.bounds.width>0,!guidePreviewFrame.isEmpty {
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
        }
        private var animatedGuideVisible: Bool {
            avatars.values.contains { $0.entity.isEnabled } || cutouts.values.contains { $0.isEnabled }
        }

        private func makeCutout(_ asset: GuideCutoutAsset) throws -> ModelEntity {
            guard let image=GuideArtwork.uiImage(named: asset.imageName),let cg=image.cgImage else {
                throw CocoaError(.fileReadCorruptFile)
            }
            // Preserve RGBA and aspect ratio. A transparent rectangle replaces
            // the portrait disc; its bottom/centre match the shared guide anchors.
            let height: Float=1.68
            let width=height*Float(cg.width)/Float(cg.height)
            var descriptor=MeshDescriptor(name: "guide.cutout.\(asset.personalityID)")
            descriptor.positions=MeshBuffers.Positions([
                [-width/2,0,0],[width/2,0,0],[width/2,height,0],[-width/2,height,0]
            ])
            descriptor.normals=MeshBuffers.Normals(Array(repeating: [0,0,1],count: 4))
            descriptor.textureCoordinates=MeshBuffers.TextureCoordinates([[0,0],[1,0],[1,1],[0,1]])
            descriptor.primitives = .triangles([0,1,2,0,2,3])
            let mesh=try MeshResource.generate(from: [descriptor])
            let texture=try TextureResource.generate(from: cg,options: .init(semantic: .color))
            var material=UnlitMaterial()
            material.color = .init(tint: .white,texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: 1))
            let entity=ModelEntity(mesh: mesh,materials: [material])
            entity.name="guide.cutout.\(asset.personalityID)"
            return entity
        }
        fileprivate func updateGuideActivity() {
            for asset in GuideAvatarAsset.all {
                let index=Float(guides.firstIndex(where: { $0.id == asset.personalityID }) ?? 0)
                let visible=active && dna != nil && (galleryTarget != nil
                    ? abs(galleryPosition-index)<2
                    : asset.personalityID == selectedGuideID && (meditating || !guidePreviewFrame.isEmpty))
                guard visible || avatars[asset.personalityID] != nil else { continue }
                let instance: AvatarInstance
                if let cached=avatars[asset.personalityID] { instance=cached }
                else {
                    instance=AvatarInstance(asset); avatars[asset.personalityID]=instance
                    anchor.addChild(instance.entity)
                }
                instance.entity.isEnabled=visible && !instance.failed
                instance.controller.reduceMotion=reduceMotion
                instance.controller.maxUpdatesPerSecond=avatarFPS
                instance.controller.speech=asset.personalityID == selectedGuideID ? avatarSpeech : .init()
                instance.controller.setTechnique(meditating && asset.personalityID == selectedGuideID ? breathingTechnique : nil)
                if visible,!instance.requested,let view {
                    instance.requested=true
                    instance.controller.load(in: instance.entity,view: view,didLoad: { [weak self,weak instance] in
                        instance?.loaded=true; self?.placeGallery(); self?.updateGuideActivity()
                    },loadFailed: { [weak self,weak instance] in
                        instance?.failed=true; self?.placeGallery(); self?.updateGuideActivity()
                    })
                }
                instance.controller.setActive(instance.entity.isEnabled)
            }
            for asset in GuideCutoutAsset.all {
                let index=Float(guides.firstIndex(where: { $0.id == asset.personalityID }) ?? 0)
                let visible=active && dna != nil && (galleryTarget != nil
                    ? abs(galleryPosition-index)<2
                    : asset.personalityID == selectedGuideID && (meditating || !guidePreviewFrame.isEmpty))
                if visible,cutouts[asset.personalityID] == nil,!failedCutouts.contains(asset.personalityID) {
                    do {
                        let entity=try makeCutout(asset)
                        cutouts[asset.personalityID]=entity; anchor.addChild(entity)
                    } catch {
                        failedCutouts.insert(asset.personalityID)
                        print("Guide cutout unavailable: \(error.localizedDescription)")
                    }
                }
                cutouts[asset.personalityID]?.isEnabled=visible
            }
            placeGallery()
            let failed=(avatars[selectedGuideID]?.failed ?? false) || failedCutouts.contains(selectedGuideID)
            if reportedAvatarFailure != failed { reportedAvatarFailure=failed; onAvatarFailure?(failed) }
            placeGuide()
            if !hasPresented,world != nil {
                let model=avatars[selectedGuideID]
                let guideReady=(model?.loaded == true) || (model?.failed == true)
                    || cutouts[selectedGuideID] != nil || failedCutouts.contains(selectedGuideID)
                    || (GuideAvatarAsset.asset(for: selectedGuideID)==nil && GuideCutoutAsset.asset(for: selectedGuideID)==nil)
                if guideReady {
                    hasPresented=true
                    onReady?(true)
                }
            }
            if active && (transition != nil || galleryAnimating || ((meditating || animatedGuideVisible || galleryTarget != nil) && !reduceMotion)) { subscribe() }
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
            if galleryTarget != nil || galleryFocus>0 {
                camera.transform=galleryBase
                let offset=SIMD3<Float>((galleryPosition-galleryOrigin)*gallerySpacing*galleryFocus,0,-0.8*galleryFocus)
                camera.position=galleryBase.translation+galleryBase.rotation.act(offset)
            } else if meditating {
                let pose=meditationJourney.pose(in: dna,elapsed: max(0,meditationTravelTime-4))
                camera.look(at: pose.target,from: pose.position,relativeTo: nil)
                if !reduceMotion,meditationTravelTime<4 {
                    let t=Float(meditationTravelTime/4)
                    let blend=t*t*t*(t*(t*6-15)+10)
                    camera.position=simd_mix(meditationEntrance.translation,camera.position,SIMD3(repeating: blend))
                    camera.orientation=simd_slerp(meditationEntrance.rotation,camera.orientation,blend)
                }
            } else {
                let previous=sourceDNA ?? dna
                let from=simd_mix(dna.cameraPosition,previous.cameraPosition,SIMD3(repeating: travel))
                let target=simd_mix(dna.cameraTarget,previous.cameraTarget,SIMD3(repeating: travel))
                // A small forward arc accompanies the spatial change, ending at a stable seat.
                let arc=SIMD3<Float>(sin(travel * .pi)*1.2,0,sin(travel * .pi)*2)
                camera.look(at: target,from: from+arc,relativeTo: nil)
            }
            projectGuideCreationInvitation()
        }
        private func projectGuideCreationInvitation() {
            guard let placement=guideCreationPlacement else { return }
            guard galleryTarget != nil,abs(-1-galleryPosition)<2,let view else {
                if !placement.frame.isEmpty { placement.frame = .zero }
                return
            }
            // A fixed slot in the same gallery, at the same depth and scale as
            // the guides. Project the actual camera pose, including its easing,
            // entry dolly and bounds, instead of running a separate 2D animation.
            let bounds=GuideCreationSilhouette.visibleBounds
            let side: Float=1.68*1.3/Float(bounds.height)
            let x=(-1-galleryOrigin)*gallerySpacing
            let y: Float=0.35+(Float(bounds.midY)-0.5)*side
            let topLeft=gallery.convert(position: [x-side/2,y+side/2,-8],to: nil)
            let bottomRight=gallery.convert(position: [x+side/2,y-side/2,-8],to: nil)
            guard let a=view.project(topLeft),let b=view.project(bottomRight),
                  a.x.isFinite,a.y.isFinite,b.x.isFinite,b.y.isFinite else { return }
            let frame=CGRect(x: a.x,y: a.y,width: b.x-a.x,height: b.y-a.y)
            if placement.frame != frame { placement.frame=frame }
        }
        private func subscribe() {
            guard active,(transition != nil || galleryAnimating || ((meditating || animatedGuideVisible || galleryTarget != nil) && !reduceMotion)),updates == nil,let view else { return }
            lastUptime=ProcessInfo.processInfo.systemUptime
            updates=view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in self?.tick() }
        }
        private func tick() {
            let now=ProcessInfo.processInfo.systemUptime,delta=now-lastUptime
            // Follow the display during a swipe or snap. Keep idle hover and
            // avatar deformation on their existing economical update budget.
            guard galleryDragging || galleryAnimating || delta >= 1.0/Double(avatarFPS) else { return }
            lastUptime=now
            if galleryTarget != nil || galleryFocus>0 {
                let easing=reduceMotion ? Float(1) : 1-exp(-Float(min(delta,0.1))*10)
                let targetFocus: Float=galleryTarget == nil ? 0 : 1
                galleryFocus += (targetFocus-galleryFocus)*easing
                if abs(galleryFocus-targetFocus)<0.001 { galleryFocus=targetFocus }
                if let target=galleryTarget {
                    let settling=reduceMotion ? Float(1) : 1-exp(-Float(min(delta,0.1))*18)
                    if galleryDragging { galleryPosition=target }
                    else { galleryPosition += (target-galleryPosition)*settling }
                    if abs(target-galleryPosition)<0.001 { galleryPosition=target }
                }
                if !reduceMotion { hoverElapsed+=Float(min(delta,0.1)) }
                placeGallery(); placeCamera(); updateGuideActivity()
                return
            }
            guard let transition else {
                if meditating,!reduceMotion {
                    // Clamp stalls; resuming after a screen lock must not cause
                    // a burst of travel. The session's timer remains independent.
                    meditationTravelTime += min(delta,0.1)
                    placeCamera()
                }
                if animatedGuideVisible,!reduceMotion {
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
            prefetchNextWorld()
        }
        private func prefetchNextWorld() {
            #if DEBUG
            guard active,!meditating,!worldInteraction,let seed=requestedSeed,let quality=builtEconomical,
                  let next=MountainJourneyStore.shared.nextPreviewAddress else { return }
            prefetch?.cancel()
            prefetch=Task {
                // Let the arrival render before speculative CPU/GPU work starts.
                do {
                    try await Task.sleep(for: .milliseconds(350))
                    _=try await MountainWorldResources.shared.prepare(.init(address: next,seed: seed,economical: quality))
                } catch { }
            }
            #endif
        }
        func setActive(_ value: Bool) {
            guard active != value else { return }
            active=value; view?.isHidden = !value
            if value { subscribe() }
            else {
                prefetch?.cancel(); prefetch=nil
                MountainWorldResources.shared.cancelPending()
                updates?.cancel(); updates=nil
                if preparing { generation?.cancel(); requested=nil }
            }
        }
        func cancel() {
            MountainWorldResources.shared.cancelPending()
            rewardTask?.cancel(); rewardTask = nil
            prefetch?.cancel(); prefetch=nil
            cutouts.values.forEach { $0.removeFromParent() }; cutouts.removeAll(); failedCutouts.removeAll()
            generation?.cancel(); generation=nil; galleryTask?.cancel(); galleryTask=nil; updates?.cancel(); updates=nil; avatars.values.forEach { $0.controller.cancel() }; avatars.removeAll()
            onReady=nil; onMoving=nil; onFailure=nil; onAvatarFailure=nil; onVeil=nil; onArrival=nil
        }
        private enum LandscapeError: Error { case noMetal }
    }
}
