import Foundation
import simd

extension GardenGeometry {
    // Keep the six DNA buckets and their order stable. These now describe broad
    // growth habits, not six fixed arrangements. Saved reward seeds do not change.
    enum CrystalForm: Int, CaseIterable { case prismatic, acicular, intergrowth, tabular, druse, isometric }

    struct CrystalPalette {
        let hue: Float
        let zoning: Float
        let density: Float
        let milkiness: Float
    }

    static func crystalPalette(_ seed: UInt64) -> CrystalPalette {
        let palettes: [CrystalPalette] = [
            .init(hue: 0.755,zoning: 0.036,density: 3.4,milkiness: 0.05), // amethyst
            .init(hue: 0.370,zoning: 0.030,density: 3.4,milkiness: 0.02), // green fluorite
            .init(hue: 0.950,zoning: -0.020,density: 2.2,milkiness: 0.26), // rose
            .init(hue: 0.090,zoning: -0.035,density: 2.8,milkiness: 0.04), // smoky honey
            .init(hue: 0.560,zoning: -0.045,density: 1.5,milkiness: 0.03), // aquamarine
            .init(hue: 0.290,zoning: 0.035,density: 2.3,milkiness: 0.10), // pale green
            .init(hue: 0.115,zoning: -0.025,density: 2.4,milkiness: 0.04), // citrine
            .init(hue: 0.600,zoning: 0.020,density: 0.5,milkiness: 0.08)  // clear quartz
        ]
        return palettes[Int(GardenDNA.value(seed,0)*Float(palettes.count))]
    }

    /// Planes bound a convex growth volume. Moving a face changes its area but
    /// keeps it planar: no random vertex noise bending a polished crystal face.
    struct MineralPlane {
        let normal: SIMD3<Float>
        let distance: Float
        init(_ normal: SIMD3<Float>,_ distance: Float) {
            let length = simd_length(normal)
            self.normal = normal/length; self.distance = distance/length
        }
    }

    static func mineralPolyhedron(_ planes: [MineralPlane]) -> [[SIMD3<Float>]] {
        let m: Float = 3
        var faces: [[SIMD3<Float>]] = [
            [[-m,-m,-m],[-m,-m,m],[-m,m,m],[-m,m,-m]],
            [[m,-m,m],[m,-m,-m],[m,m,-m],[m,m,m]],
            [[-m,-m,m],[-m,-m,-m],[m,-m,-m],[m,-m,m]],
            [[-m,m,-m],[-m,m,m],[m,m,m],[m,m,-m]],
            [[m,-m,-m],[-m,-m,-m],[-m,m,-m],[m,m,-m]],
            [[-m,-m,m],[m,-m,m],[m,m,m],[-m,m,m]]
        ]
        let epsilon: Float = 0.00001
        for plane in planes {
            var clipped: [[SIMD3<Float>]] = []
            var cap: [SIMD3<Float>] = []
            for face in faces {
                var polygon: [SIMD3<Float>] = []
                for i in face.indices {
                    let a = face[i], b = face[(i+1)%face.count]
                    let da = simd_dot(plane.normal,a)-plane.distance
                    let db = simd_dot(plane.normal,b)-plane.distance
                    if da <= epsilon { polygon.append(a) }
                    if (da < -epsilon && db > epsilon) || (da > epsilon && db < -epsilon) {
                        let p = a+(b-a)*(da/(da-db))
                        polygon.append(p)
                        if !cap.contains(where: { simd_distance_squared($0,p)<epsilon*epsilon }) { cap.append(p) }
                    } else if abs(da)<=epsilon && !cap.contains(where: { simd_distance_squared($0,a)<epsilon*epsilon }) {
                        cap.append(a)
                    }
                }
                if polygon.count >= 3 { clipped.append(polygon) }
            }
            if cap.count >= 3 {
                let center = cap.reduce(SIMD3<Float>.zero,+)/Float(cap.count)
                let (_,u,v) = frame(plane.normal)
                cap.sort {
                    atan2(simd_dot($0-center,v),simd_dot($0-center,u))
                        < atan2(simd_dot($1-center,v),simd_dot($1-center,u))
                }
                clipped.append(cap)
            }
            faces = clipped
        }
        return faces
    }

    static func crystal(_ seed: UInt64, detail: Detail) -> GardenMesh {
        func g(_ i: Int) -> Float { GardenDNA.value(seed,i) }
        let form = CrystalForm(rawValue: family(seed,count: 6))!
        let fine = detail == .portrait
        let palette = crystalPalette(seed)
        let hue = palette.hue+(g(1)-0.5)*0.026
        let phase = g(3)*2*Float.pi
        let slender = g(7), abundance = g(8), spread = g(9)
        let lean = SIMD3<Float>((g(10)-0.5)*0.45,1,(g(11)-0.5)*0.45)
        var mesh = GardenMesh()
        var serial = 0

        func emit(_ faces: [[SIMD3<Float>]],root: SIMD3<Float>,direction: SIMD3<Float>,
                  size: SIMD3<Float>,spin: Float,gene: Int,role: Float = 0) {
            let (axis,side,front) = frame(direction)
            let x = side*cos(spin)+front*sin(spin), z = -side*sin(spin)+front*cos(spin)
            func transform(_ p: SIMD3<Float>) -> SIMD3<Float> {
                root+x*(p.x*size.x)+axis*(p.y*size.y)+z*(p.z*size.z)
            }
            for (index,face) in faces.enumerated() where face.count >= 3 {
                let tone: Float = role == 1 ? 0.18+g(gene+index)*0.18 : role == 2 ? 0.18 : 0.45+g(gene+index)*0.18
                let colorHue: Float = role == 1 ? 0.10 : role == 2 ? 0.105 : hue+(g(gene+index+50)-0.5)*0.012
                for i in 1..<(face.count-1) {
                    let vertices = [face[0],face[i],face[i+1]]
                    let a = transform(vertices[0]), b = transform(vertices[1]), c = transform(vertices[2])
                    let before = mesh.positions.count
                    mesh.facet(a,b,c,pigment: [colorHue,tone])
                    if mesh.positions.count > before {
                        for (offset,p) in vertices.enumerated() {
                            let t = max(0,min(1,p.y))
                            mesh.mineralSurfaces.append([role,t])
                            if role == 0 {
                                // Continuous axial zoning rather than unrelated
                                // colours painted on neighbouring triangles.
                                mesh.pigments[before+offset] = [colorHue+palette.zoning*t,tone+t*0.16]
                            }
                        }
                    }
                }
            }
        }

        func prism(_ root: SIMD3<Float>,_ direction: SIMD3<Float>,_ height: Float,
                   _ radius: Float,flatten: Float = 1,doubleEnded: Bool = false,
                   blade: Bool = false,flatTop: Bool = false,overgrowth: Bool = false) {
            let gene = 2000+serial*137
            serial += 1
            var planes: [MineralPlane] = []
            let sides = blade ? 4 : 6
            for j in 0..<sides {
                let a = Float(j)*2*Float.pi/Float(sides)
                let support = 0.84+g(gene+j)*0.22
                planes.append(.init([cos(a),blade ? (j%2 == 0 ? -0.18 : 0.08) : 0,sin(a)],support))
                if fine && !blade {
                    let b = a+Float.pi/Float(sides)
                    planes.append(.init([cos(b),0,sin(b)],1.03+g(gene+10+j)*0.04))
                }
                let slope: Float = flatTop ? 0.09 : (blade ? 0.12+g(gene+30)*0.16 : 0.22+g(gene+30)*0.22)
                let capHeight: Float = flatTop ? 1.06 : 1+(j%2 == 0 ? 0 : 0.06+g(gene+31)*0.10)
                planes.append(.init([cos(a)*slope,1,sin(a)*slope],capHeight))
                if doubleEnded { planes.append(.init([cos(a)*0.22,-1,sin(a)*0.22],0)) }
            }
            if flatTop { planes.append(.init([0,1,0],1)) }
            if !doubleEnded { planes.append(.init([0,-1,0],0)) }
            let spin = phase+(g(gene+33)-0.5)*0.55
            emit(mineralPolyhedron(planes),root: root,direction: direction,size: [radius,height,radius*flatten],spin: spin,gene: gene)
            // A second growth generation widens just the head of some prisms.
            if overgrowth {
                let axis = simd_normalize(direction)
                emit(mineralPolyhedron(planes),root: root+axis*(height*0.53),direction: direction,
                     size: [radius*1.55,height*0.50,radius*flatten*1.55],spin: spin,gene: gene+60)
            }
            // A few embedded mineral needles, drawn opaque before the glass.
            // Only large, clear specimens get these; never a particle system.
            if fine && radius>0.15 && (palette.hue<0.15 || palette.density<1) && g(gene+80)>0.65 {
                let (axis,x,z) = frame(direction)
                for j in 0..<(2+Int(g(gene+81)*4)) {
                    let p = root+axis*(height*(0.20+g(gene+82+j)*0.27))
                        + x*((g(gene+92+j)-0.5)*radius*0.7)
                    let end = p+axis*(height*0.28)+z*((g(gene+102+j)-0.5)*radius)
                    let needle: [MineralPlane] = [.init([1,0,0],1),.init([-1,0,0],1),
                        .init([0,0,1],1),.init([0,0,-1],1),.init([0,1,0],1),.init([0,-1,0],0)]
                    emit(mineralPolyhedron(needle),root: p,direction: end-p,
                         size: [0.0025,simd_length(end-p),0.0025],spin: 0,gene: gene+j,role: 2)
                }
            }
        }

        func matrix(_ width: Float,_ depth: Float,_ thickness: Float) {
            let chunks = fine ? 5 : 2
            for i in 0..<chunks {
                let gene = 1200+i*40, angle = phase+Float(i)*2.39996
                var planes = [MineralPlane([0,1,0],0.28+g(gene)*0.2),MineralPlane([0,-1,0],0.65)]
                for j in 0..<9 {
                    let a = Float(j)*2*Float.pi/9
                    planes.append(.init([cos(a),0.35+g(gene+j+1)*0.45,sin(a)],0.65+g(gene+j+12)*0.2))
                    planes.append(.init([cos(a),-0.45,sin(a)],0.86))
                }
                let center: SIMD3<Float> = i == 0 ? [0,-0.63,0] : [cos(angle)*width*0.35,-0.64,sin(angle)*depth*0.35]
                let fraction: Float = i == 0 ? 1 : 0.55
                emit(mineralPolyhedron(planes),root: center,direction: [0,1,0],
                     size: [width*fraction,thickness,depth*fraction],spin: angle,gene: gene,role: 1)
            }
        }

        switch form {
        case .prismatic:
            let count = 1+Int(abundance*6)
            let height: Float = 0.95+slender*0.95
            let radius: Float = 0.16+(1-slender)*0.20
            let scepter = g(12)>0.64
            for i in 0..<count {
                let a = phase+Float(i)*2.39996
                let distance: Float = i == 0 ? 0 : radius*(0.65+g(40+i)*0.75)
                let scale: Float = i == 0 ? 1 : 0.20+pow(g(60+i),1.4)*0.56
                prism([cos(a)*distance,-0.65,sin(a)*distance],
                      lean+[cos(a)*spread*0.50,0,sin(a)*spread*0.50],
                      height*scale,radius*(i == 0 ? 1 : 0.40+g(80+i)*0.20),
                      doubleEnded: count == 1 && g(13)>0.45,flatTop: g(14)>0.85,
                      overgrowth: scepter && i == 0)
            }
            if count>2 && g(15)>0.48 { matrix(radius*1.9,radius*1.5,0.18) }
        case .acicular:
            let count = (fine ? 10 : 7)+Int(abundance*(fine ? 18 : 9))
            let arc: Float = 0.65+spread*1.8
            let radial = g(12)>0.55
            let bundled = g(16)<0.32
            let lowSpray = g(16)>0.70
            for i in 0..<count {
                let u = (Float(i)+g(40+i)*0.7)/Float(count)-0.5
                let a = phase+Float(i)*2.39996
                let direction: SIMD3<Float> = bundled ? lean+[cos(a)*0.10,0,sin(a)*0.10]
                    : radial ? [cos(a)*(lowSpray ? 1.35 : 0.25+spread),lowSpray ? 0.18+g(70+i)*0.25 : 0.4+g(70+i),sin(a)*(lowSpray ? 1.35 : 0.25+spread)]
                    : [sin(u*arc),cos(u*arc)*(lowSpray ? 0.32 : 1),(g(70+i)-0.5)*0.35]
                let length: Float = 0.35+pow(g(100+i),0.65)*(0.70+slender*0.65)
                prism([cos(a)*(bundled ? 0.13 : 0.09),-0.65,sin(a)*0.09],direction,length,
                      0.028+(1-slender)*0.05+g(130+i)*0.025,flatten: 0.55+g(13)*0.45)
            }
            matrix(0.24+spread*0.05,0.20,0.13)
        case .intergrowth:
            let height: Float = 1.05+slender*0.55
            let radius: Float = 0.17+(1-slender)*0.14
            prism([0,-0.65,0],lean,height,radius,doubleEnded: g(12)>0.55,overgrowth: g(13)>0.75)
            let count = 1+Int(abundance*5)
            for i in 0..<count {
                let a = phase+Float(i)*2.39996
                let attachment: Float = 0.06+g(40+i)*0.42
                let root = SIMD3<Float>(0,-0.65,0)+simd_normalize(lean)*(height*attachment)
                let lateral: Float = 0.38+spread*1.05
                let direction = SIMD3<Float>(cos(a)*lateral,0.45+g(70+i)*0.65,sin(a)*lateral)
                prism(root,direction,height*(0.32+g(100+i)*0.48),
                      radius*(0.40+g(130+i)*0.40),doubleEnded: g(14)>0.5,
                      overgrowth: i == 0 && g(15)>0.60)
            }
        case .tabular:
            let count = 3+Int(abundance*(fine ? 13 : 7))
            let bundled = g(12)>0.5
            for i in 0..<count {
                let a = phase+Float(i)*2.39996+(g(40+i)-0.5)*0.5
                let direction: SIMD3<Float> = bundled
                    ? lean+[cos(a)*spread*0.45,0,sin(a)*spread*0.45]
                    : [cos(a)*(0.45+spread),0.25+g(70+i)*0.8,sin(a)*(0.45+spread)]
                let length: Float = 0.4+g(100+i)*(0.65+slender*0.35)
                prism([cos(a)*0.07,-0.65,sin(a)*0.07],direction,length,
                      0.12+g(130+i)*0.19,flatten: 0.08+g(13)*0.19,
                      blade: true,flatTop: g(14)>0.5)
            }
            if g(15)>0.65 { matrix(0.35,0.28,0.16) }
        case .druse:
            // Druse grows over an irregular, opaque host rock. Avoid the old
            // translucent, perfectly round bowl silhouette.
            let width: Float = 0.45+spread*0.60
            let depth: Float = 0.20+g(12)*0.40
            matrix(width,depth,0.26+g(13)*0.16)
            let count = fine ? 22+Int(abundance*36) : 12+Int(abundance*12)
            let pinnacle = g(16)>0.62
            for i in 0..<count {
                let a = phase+Float(i)*2.39996
                let t = sqrt(g(40+i))*0.84
                let p = SIMD3<Float>(cos(a)*width*t,-0.61+0.05*(1-t),sin(a)*depth*t)
                let length: Float = pinnacle && i == 0 ? 0.85+slender*0.55
                    : 0.10+pow(g(110+i),2)*(0.22+slender*0.28)
                prism(p,lean+[cos(a)*t*0.6,0,sin(a)*t*0.6],length,
                      0.045+length*(0.12+g(14)*0.12),flatTop: g(15)>0.8)
            }
        case .isometric:
            let count = 1+Int(abundance*(fine ? 8 : 5))
            let truncation: Float = 0.82+g(12)*1.60
            let mainRadius: Float = 0.37+slender*0.14
            for i in 0..<count {
                let a = phase+Float(i)*2.39996
                let fraction: Float = i == 0 ? 1 : 0.28+g(40+i)*0.48
                let radius: Float = mainRadius*fraction
                var planes: [MineralPlane] = [
                    .init([1,0,0],1),.init([-1,0,0],1),.init([0,1,0],1),
                    .init([0,-1,0],1),.init([0,0,1],1),.init([0,0,-1],1)]
                for x: Float in [-1,1] { for y: Float in [-1,1] { for z: Float in [-1,1] {
                    planes.append(.init([x,y,z],truncation))
                } } }
                let direction = lean+[cos(a)*g(13)*0.85,0,sin(a)*g(13)*0.85]
                // Secondary crystals intergrow with the central volume, even
                // when a heavily truncated octahedron has a narrow footprint.
                let distance: Float = i == 0 ? 0 : (mainRadius*min(1,truncation)*0.5+radius*0.35)*(0.65+spread*0.4)
                emit(mineralPolyhedron(planes),
                     root: [cos(a)*distance,-0.15+Float(i%3)*0.10,sin(a)*distance],
                     direction: direction,size: [radius,radius,radius],spin: phase+g(14)*Float(i)*0.55,gene: 2000+i*137)
            }
            if count>3 && g(15)>0.65 { matrix(0.55,0.38,0.17) }
        }
        if let base = mesh.positions.map(\.y).min() {
            for i in mesh.positions.indices { mesh.positions[i].y += -0.70-base }
        }
        return mesh
    }
}
