import SwiftUI
import SceneKit
import Metal

/// Shared static studio for portraits and detail. Only the visible specimen detail
/// adds rotation; no physics, shadows, scene captures or per-cell live renderers.
enum GardenSceneFactory {
    static func scene(mesh: GardenMesh, kind: GardenKind, seed: UInt64 = 0) -> (SCNScene, SCNNode) {
        let scene = SCNScene()
        let points = mesh.positions.map { SCNVector3($0.x,$0.y,$0.z) }
        let normals = mesh.normals.map { SCNVector3($0.x,$0.y,$0.z) }
        let surfaces = mesh.mineralSurfaces
        let colors: [SIMD4<Float>] = mesh.pigments.enumerated().map { index, pigment in
            var rgb = GardenMesh.rgb(pigment)
            let solidMineral = kind == .crystal && !surfaces.isEmpty && surfaces[index].x > 0.5
            if solidMineral {
                let light = max(0,simd_dot(mesh.normals[index],simd_normalize(SIMD3<Float>(-0.4,0.8,0.5))))
                rgb = surfaces[index].x > 1.5 ? SIMD3<Float>(0.66,0.43,0.16)*(0.70+light*0.30)
                    : simd_mix(rgb,SIMD3(repeating: rgb.max()),SIMD3(repeating: 0.55))*(0.55+light*0.45)
            }
            if kind != .crystal {
                // Soft two-sided botanical light. Thin petal backs must keep
                // their pigment instead of turning grey under specular light.
                let light = abs(simd_dot(mesh.normals[index],simd_normalize(SIMD3<Float>(-0.4,0.8,0.5))))
                rgb *= 0.80+light*0.20
            }
            return SIMD4(rgb.x,rgb.y,rgb.z,1)
        }
        let data = colors.withUnsafeBytes { Data($0) }
        let colorSource = SCNGeometrySource(data: data, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: 4,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride)
        var sources = [SCNGeometrySource(vertices: points),SCNGeometrySource(normals: normals),colorSource]
        // The shared optical texture requires UV0 for every material. Mineral
        // coordinates also align colour zones with each crystal's growth axis.
        let coordinates = surfaces.isEmpty ? Array(repeating: CGPoint.zero,count: points.count)
            : surfaces.map { CGPoint(x: CGFloat($0.x),y: CGFloat($0.y)) }
        sources.append(SCNGeometrySource(textureCoordinates: coordinates))
        var glassIndices: [UInt32] = [], solidIndices: [UInt32] = []
        if kind == .crystal && !surfaces.isEmpty {
            for i in stride(from: 0,to: mesh.indices.count,by: 3) {
                let triangle = mesh.indices[i..<(i+3)]
                if surfaces[Int(mesh.indices[i])].x > 0.5 { solidIndices.append(contentsOf: triangle) }
                else { glassIndices.append(contentsOf: triangle) }
            }
        } else { glassIndices = mesh.indices }
        var elements = [SCNGeometryElement(indices: glassIndices,primitiveType: .triangles)]
        if !solidIndices.isEmpty { elements.append(SCNGeometryElement(indices: solidIndices,primitiveType: .triangles)) }
        let geometry = SCNGeometry(sources: sources,elements: elements)
        let material = SCNMaterial()
        material.lightingModel = kind == .crystal ? .physicallyBased : .constant
        material.diffuse.contents = UIColor.white
        material.ambient.contents = UIColor.white
        material.specular.contents = UIColor(white: kind == .crystal ? 0.85 : 0.18,alpha: 1)
        material.shininess = kind == .crystal ? 85 : 18
        let lower = mesh.positions.reduce(SIMD3<Float>(repeating: .infinity)) { simd_min($0,$1) }
        let upper = mesh.positions.reduce(SIMD3<Float>(repeating: -.infinity)) { simd_max($0,$1) }
        GardenCrystalOptics.configure(material,kind: kind,seed: seed,lower: lower,upper: upper)
        material.isDoubleSided = true
        geometry.materials = [material]
        if !solidIndices.isEmpty {
            let solid = SCNMaterial()
            solid.lightingModel = .constant
            solid.diffuse.contents = UIColor.white
            solid.isDoubleSided = true
            // Opaque host rock and embedded needles write depth before glass.
            geometry.materials.append(solid)
        }
        let model = SCNNode(geometry: geometry)
        model.name = "specimen"
        let center = (lower+upper)*0.5
        let radius = mesh.positions.reduce(Float(0)) { max($0,simd_distance($1,center)) }
        model.pivot = SCNMatrix4MakeTranslation(center.x,center.y,center.z)
        model.position = SCNVector3(0,0.08,0)
        model.eulerAngles = SCNVector3(0.28,-0.45,-0.07)
        scene.rootNode.addChildNode(model)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = max(0.9,Double(radius)*1.30)
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 20
        camera.position = SCNVector3(0,0.35,5)
        camera.look(at: SCNVector3(0,0.08,0))
        camera.name = "camera"
        scene.rootNode.addChildNode(camera)
        func light(_ type: SCNLight.LightType, color: UIColor, intensity: CGFloat, position: SCNVector3) {
            let node = SCNNode()
            node.light = SCNLight()
            node.light?.type = type
            node.light?.color = color
            node.light?.intensity = intensity
            node.position = position
            node.look(at: SCNVector3(0,0,0))
            scene.rootNode.addChildNode(node)
        }
        light(.ambient,color: UIColor(red: 0.88,green: 0.91,blue: 1,alpha: 1),intensity: 480,position: SCNVector3Zero)
        light(.directional,color: UIColor(red: 1,green: 0.94,blue: 0.85,alpha: 1),intensity: 850,position: SCNVector3(-3,4,4))
        light(.directional,color: UIColor(red: 0.74,green: 0.85,blue: 1,alpha: 1),intensity: 450,position: SCNVector3(3,1,-2))
        return (scene,model)
    }
}

/// Serial background rendering and a bounded image cache keep long collections
/// from allocating hundreds of scenes or competing for the GPU while scrolling.
actor GardenPortraits {
    static let shared = GardenPortraits()
    private let cache = NSCache<NSString,UIImage>()
    private var renderer: SCNRenderer?
    init() { cache.countLimit = 60; cache.totalCostLimit = 24*1024*1024 }
    func image(for specimen: GardenSpecimen) throws -> UIImage {
        try Task.checkCancellation()
        let key = "v\(GardenGeometry.revision).optics\(GardenCrystalOptics.revision).\(specimen.id).\(specimen.seed)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let mesh = GardenGeometry.build(specimen,detail: .portrait)
        try Task.checkCancellation()
        let (scene,_) = GardenSceneFactory.scene(mesh: mesh,kind: specimen.kind,seed: specimen.seed)
        if renderer == nil { renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(),options: nil) }
        guard let renderer else { throw CancellationError() }
        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: "camera",recursively: false)
        defer { renderer.scene = nil; renderer.pointOfView = nil }
        let image = renderer.snapshot(atTime: 0,with: CGSize(width: 360,height: 420),antialiasingMode: .multisampling2X)
        cache.setObject(image,forKey: key,cost: 360*420*4)
        return image
    }
    func clear() { cache.removeAllObjects(); renderer = nil }
}

#if DEBUG
/// A repeatable visual regression sheet using the actual portrait renderer.
/// Explicit launch flag only; never records practice or touches the real ledger.
@MainActor enum GardenVisualReview {
    static func export() async {
        let names: [[String]] = [["Rosett", "Kosmos", "Lilja", "Klockor", "Orkidé", "Blomflock"],
                                ["Prismor & spiror", "Nålar & solfjädrar", "Sammanväxningar", "Flak & blad", "Druser", "Kubiska former"],
                                ["Vid krona", "Hängande grenar", "Vindböjt", "Spira"]]
        let directory = URL.documentsDirectory.appending(path: "GardenReview",directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
            for (kindIndex,kind) in GardenKind.allCases.enumerated() {
                let count = kind == .tree ? 4 : 6
                var samples: [Int: UIImage] = [:]
                for candidate in 0..<200 where samples.count < count {
                    let seed = GardenDNA.mix(UInt64(candidate))
                    let family = GardenGeometry.family(seed,count: count)
                    guard samples[family] == nil else { continue }
                    let item = GardenSpecimen(sessionID: UUID(),seed: seed,kind: kind,ordinal: family+1,earnedAt: .now)
                    samples[family] = try await GardenPortraits.shared.image(for: item)
                    do {
                        // Preserve alpha for checking actual translucent coverage,
                        // which the composited contact sheet cannot reveal.
                        try samples[family]?.pngData()?.write(to: directory.appending(path: "\(kind.rawValue)-\(family).png"))
                        let mesh = GardenGeometry.build(item,detail: .portrait)
                        let (scene,model) = GardenSceneFactory.scene(mesh: mesh,kind: kind,seed: seed)
                        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(),options: nil)
                        renderer.scene = scene
                        renderer.pointOfView = scene.rootNode.childNode(withName: "camera",recursively: false)
                        for (angle,rotation) in [SCNVector3(0.75,1.2,0),SCNVector3(-1.1,2.6,0)].enumerated() {
                            model.eulerAngles = rotation
                            let view = renderer.snapshot(atTime: 0,with: CGSize(width: 360,height: 420),antialiasingMode: .multisampling2X)
                            try view.pngData()?.write(to: directory.appending(path: "\(kind.rawValue)-\(family)-angle\(angle).png"))
                        }
                    }
                }
                let columns = kind == .tree ? 2 : 3
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let sheet = UIGraphicsImageRenderer(size: CGSize(width: columns*360,height: 980),format: format).image { context in
                    UIColor(red: 0.965,green: 0.955,blue: 0.927,alpha: 1).setFill()
                    context.fill(CGRect(x: 0,y: 0,width: columns*360,height: 980))
                    for i in 0..<count {
                        let x = (i%columns)*360, y = (i/columns)*470
                        samples[i]?.draw(in: CGRect(x: x,y: y,width: 360,height: 420))
                        let text = names[kindIndex][i] as NSString
                        text.draw(at: CGPoint(x: x+24,y: y+420),withAttributes: [
                            .font: UIFont.systemFont(ofSize: 20,weight: .light),
                            .foregroundColor: UIColor(red: 0.23,green: 0.31,blue: 0.29,alpha: 1)])
                    }
                }
                try sheet.pngData()?.write(to: directory.appending(path: "\(kind.rawValue)-families.png"))
            }
            try await exportCrystalVariation(to: directory)
            print("Garden review exported: \(directory.path)")
        } catch { print("Garden review failed: \(error)") }
    }

    private static func exportCrystalVariation(to directory: URL) async throws {
        var samples = Array(repeating: [UIImage](),count: 6)
        for candidate in 0..<400 where samples.contains(where: { $0.count<4 }) {
            let seed = GardenDNA.mix(UInt64(candidate))
            let family = GardenGeometry.family(seed,count: 6)
            guard samples[family].count<4 else { continue }
            let item = GardenSpecimen(sessionID: UUID(),seed: seed,kind: .crystal,ordinal: candidate+1,earnedAt: .now)
            let image = try await GardenPortraits.shared.image(for: item)
            try image.pngData()?.write(to: directory.appending(path: "crystal-variant-\(family)-\(samples[family].count).png"))
            samples[family].append(image)
        }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1080,height: 2010),format: format).image { context in
            UIColor(red: 0.965,green: 0.955,blue: 0.927,alpha: 1).setFill()
            context.fill(CGRect(x: 0,y: 0,width: 1080,height: 2010))
            for row in 0..<6 { for column in 0..<samples[row].count {
                samples[row][column].draw(in: CGRect(x: column*270,y: row*335,width: 270,height: 315))
            } }
        }
        try sheet.pngData()?.write(to: directory.appending(path: "crystal-variation.png"))
    }
}
#endif

struct GardenPortrait: View {
    let specimen: GardenSpecimen
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { ProgressView().tint(GardenStyle.ink.opacity(0.5)) }
        }
        .accessibilityHidden(true)
        .task(id: specimen.id) {
            image = nil
            guard let rendered = try? await GardenPortraits.shared.image(for: specimen), !Task.isCancelled else { return }
            image = rendered
        }
        .onDisappear { image = nil }
    }
}

struct GardenSpecimenScene: UIViewRepresentable {
    let specimen: GardenSpecimen
    let active: Bool
    let economical: Bool
    let automaticRotation: Bool
    let interacting: Bool
    let resetID: Int
    var rotation: SIMD2<Float>
    var zoom: Double
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.rendersContinuously = false
        view.isPlaying = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.isUserInteractionEnabled = false // SwiftUI owns accessible orbit/pinch gestures.
        return view
    }
    func updateUIView(_ view: SCNView,context: Context) {
        let c = context.coordinator
        view.isHidden = !active
        // Slow idle motion needs fewer frames than direct manipulation.
        view.preferredFramesPerSecond = interacting ? (economical ? 30 : 60) : (economical ? 15 : 30)
        c.rotation = rotation; c.zoom = zoom
        c.setMotion(active: active,automatic: automaticRotation,interacting: interacting,view: view)
        if c.id != specimen.id {
            c.id = specimen.id
            c.task?.cancel()
            c.resumeTask?.cancel()
            c.resumeTask = nil
            c.spinNode?.removeAllActions()
            c.model = nil; c.spinNode = nil
            view.scene = nil; view.pointOfView = nil
            let item = specimen
            c.task = Task { @MainActor [weak view, weak c] in
                let worker = Task.detached(priority: .userInitiated) { GardenGeometry.build(item,detail: .portrait) }
                let mesh = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled,let view,let c,c.id == item.id else { return }
                let (scene,model) = GardenSceneFactory.scene(mesh: mesh,kind: item.kind,seed: item.seed)
                // Manual orbit and automatic yaw have separate nodes, so a drag
                // never overwrites the angle already reached by the slow turn.
                let orbit = SCNNode()
                orbit.position = model.position
                model.removeFromParentNode()
                model.position = SCNVector3Zero
                model.eulerAngles = SCNVector3Zero
                orbit.addChildNode(model)
                scene.rootNode.addChildNode(orbit)
                c.model = orbit; c.spinNode = model
                c.startTurn()
                view.scene = scene
                view.pointOfView = scene.rootNode.childNode(withName: "camera",recursively: false)
                c.baseScale = view.pointOfView?.camera?.orthographicScale ?? 1.18
                c.apply(view)
                c.updatePlayback(view)
            }
        }
        if c.resetID != resetID {
            c.resetID = resetID
            c.spinNode?.removeAllActions()
            c.spinNode?.eulerAngles = SCNVector3Zero
            c.startTurn()
        }
        c.apply(view)
    }
    static func dismantleUIView(_ view: SCNView,coordinator: Coordinator) {
        coordinator.task?.cancel(); coordinator.resumeTask?.cancel()
        coordinator.spinNode?.removeAllActions()
        coordinator.model = nil; coordinator.spinNode = nil
        view.isPlaying = false
        view.scene = nil; view.pointOfView = nil
    }
    @MainActor final class Coordinator {
        var id: String?
        var task: Task<Void,Never>?
        var model: SCNNode?
        var spinNode: SCNNode?
        var resumeTask: Task<Void,Never>?
        var resetID: Int?
        var active = false
        var automatic = false
        var interacting = false
        var rotation = SIMD2<Float>(0,0)
        var zoom: Double = 1
        var baseScale: Double = 1.18
        func startTurn() {
            guard automatic,let spinNode,spinNode.action(forKey: "slowTurn") == nil else { return }
            let turn = SCNAction.rotateBy(x: 0,y: .pi*2,z: 0,duration: 90)
            turn.timingMode = .linear
            spinNode.runAction(.repeatForever(turn),forKey: "slowTurn")
        }
        func setMotion(active: Bool,automatic: Bool,interacting: Bool,view: SCNView) {
            let released = self.interacting && !interacting
            self.active = active; self.automatic = automatic; self.interacting = interacting
            if !active || !automatic || interacting {
                resumeTask?.cancel(); resumeTask = nil
            } else if released {
                resumeTask?.cancel()
                resumeTask = Task { @MainActor [weak self,weak view] in
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    guard let self,let view else { return }
                    self.resumeTask = nil
                    self.updatePlayback(view)
                }
            }
            startTurn()
            updatePlayback(view)
        }
        func updatePlayback(_ view: SCNView) {
            let playing = active && automatic && !interacting && resumeTask == nil && spinNode != nil
            spinNode?.isPaused = !playing
            view.isPlaying = playing
        }
        func apply(_ view: SCNView) {
            model?.simdOrientation = simd_quatf(angle: rotation.y+0.28,axis: [1,0,0]) * simd_quatf(angle: rotation.x-0.45,axis: [0,1,0])
            view.pointOfView?.camera?.orthographicScale = baseScale/zoom
        }
    }
}
