import Foundation
import simd

extension GardenGeometry {
    enum TreeForm: Int, CaseIterable { case umbrella, willow, windswept, spire }

    static func tree(_ seed: UInt64, detail: Detail) -> GardenMesh {
        func g(_ i: Int) -> Float { GardenDNA.value(seed,i) }
        let form = TreeForm(rawValue: family(seed,count: TreeForm.allCases.count))!
        let fine = detail == .portrait
        var mesh = GardenMesh()
        let phase = g(2)*2*Float.pi
        let palettes: [SIMD2<Float>] = [[0.29,0.16],[0.40,0.27],[0.94,0.05],[0.12,0.06],[0.74,0.91],[0.33,0.48]]
        let palette = palettes[Int(g(3)*Float(palettes.count))]
        let bark: Float = 0.07+g(4)*0.04
        let lean: Float = form == .windswept ? 0.26 : (g(1)-0.5)*0.22
        let trunkHeight: Float = form == .spire ? 1.18 : 0.90+g(0)*0.12
        func trunk(_ u: Float) -> SIMD3<Float> {
            [lean*u*u+sin(u*4)*0.055,trunkHeight*u-0.68,cos(u*3+phase)*0.065*u]
        }
        mesh = treeStem(seed: seed,detail: detail,hue: bark,center: trunk)
        let arms = 5+Int(g(6)*3)
        for i in 0..<arms {
            let a = phase+Float(i)*2.39996
            let rise = Float(i)/Float(arms-1)
            let start = trunk(0.38+rise*0.46)
            let spread: Float = form == .spire ? 0.38-rise*0.23 : 0.38+g(20+i)*0.18
            let wind: Float = form == .windswept ? 0.19 : 0
            var end = trunk(1)+SIMD3<Float>(cos(a)*spread+wind,
                0.07+g(30+i)*0.15,sin(a)*spread*0.82)
            if form == .spire { end.y = start.y+0.12+rise*0.12 }
            let control = start+SIMD3<Float>(cos(a)*spread*0.58,0.21,sin(a)*spread*0.48)
            tube(&mesh,from: start,via: control,to: end,radius: 0.038-rise*0.013,tip: 0.009,
                 hue: bark,light: 0.27,rows: fine ? 10 : 4,sides: fine ? 7 : 4)
            for j in 0..<3 {
                let angle = a+(Float(j)-1)*0.88
                let length: Float = 0.14+g(100+i*10+j)*0.13
                let tip = end+SIMD3<Float>(cos(angle)*length,
                    form == .willow ? -0.14 : 0.05+g(180+i*10+j)*0.11,sin(angle)*length)
                tube(&mesh,from: simd_mix(control,end,SIMD3(repeating: 0.60)),via: end+[0,0.10,0],to: tip,
                     radius: 0.012,tip: 0.0025,hue: bark,light: 0.33,rows: fine ? 6 : 3,sides: 4)
                let leafCount = fine ? 15 : 6
                for k in 0..<leafCount {
                    // The same phyllotaxis in both LODs; low detail samples the
                    // full crown, rather than keeping only one side of it.
                    let sample = Float(k)/Float(leafCount)
                    let b = Float(k)*2.39996+angle
                    let ring: Float = sqrt(sample)*0.15
                    let droop: Float = form == .willow ? sample*0.33 : sample*0.06
                    let root = tip+SIMD3<Float>(cos(b)*ring,-droop,sin(b)*ring)
                    let direction = SIMD3<Float>(cos(b),form == .willow ? -1.8 : 0.4+g(200+i*50+k),sin(b))
                    let leafLength: Float = form == .willow ? 0.14 : 0.11+g(400+i*30+k)*0.055
                    let tint = palette.x+(palette.y-palette.x)*(0.18+sample*0.70)
                    // Small convex leaves make a lacy three-dimensional crown.
                    let (axis,side,normal) = frame(direction)
                    mesh.surface(rows: fine ? 5 : 2,columns: 2,pigment: { u,v in
                        [tint,0.40+g(600+i*30+k)*0.22+u*0.13+abs(v)*0.06]
                    }) { u,v in
                        let profile = pow(max(0,sin(u * .pi)),0.72)
                        return root+axis*(u*leafLength)+side*(v*profile*leafLength*(form == .willow ? 0.16 : 0.38))
                            + normal*(profile*leafLength*0.19-v*v*profile*leafLength*0.10)
                    }
                    if form == .willow && k > 0 && k%3 == 0 {
                        tube(&mesh,from: tip,via: tip+[cos(b)*ring,0,sin(b)*ring],to: root,
                             radius: 0.0025,tip: 0.001,hue: bark,light: 0.38,rows: fine ? 4 : 2,sides: 3)
                    }
                }
            }
        }
        return mesh
    }

    /// One closed, indexed skin from the upper stem through its flared collar
    /// into every root. No buried root tubes or internal caps: those become
    /// visible through the translucent bark. Both LODs follow the same paths.
    static func treeStem(seed: UInt64, detail: Detail, hue: Float,
                         center: (Float) -> SIMD3<Float>) -> GardenMesh {
        func g(_ i: Int) -> Float { GardenDNA.value(seed,i) }
        let fine = detail == .portrait
        let count = 5+Int(g(1000)*3), sides = fine ? 8 : 4, half = sides/2
        let stemRows = fine ? 16 : 4, rootRows = fine ? 14 : 4
        let circumference = count*half
        let phase = g(2)*2*Float.pi, step = 2*Float.pi/Float(count)
        let angles: [Float] = (0..<count).map { i in
            let offset: Float = (g(1010+i)-0.5)*step*0.30
            return phase+Float(i)*step+offset
        }
        let collarU: Float = 0.16, baseRadius: Float = 0.095+g(5)*0.018
        let collarRadius = baseRadius+(0.025-baseRadius)*collarU
        let collar = center(collarU)
        var mesh = GardenMesh()
        func vertex(_ point: SIMD3<Float>, _ light: Float) -> UInt32 {
            let index = UInt32(mesh.positions.count)
            mesh.positions.append(point); mesh.normals.append(.zero)
            mesh.pigments.append([hue,light])
            return index
        }
        func triangle(_ a: UInt32,_ b: UInt32,_ c: UInt32) { mesh.indices += [a,b,c] }
        func quad(_ a: UInt32,_ b: UInt32,_ c: UInt32,_ d: UInt32) {
            triangle(a,b,c); triangle(a,c,d)
        }
        func boundary(_ i: Int) -> Float {
            let previous = i == 0 ? angles[count-1]-2*Float.pi : angles[i-1]
            return (previous+angles[i])*0.5
        }
        // Each root owns an arc of the trunk's bottom ring. Shared vertices at
        // sector seams make the shoulders continuous instead of overlapping.
        for row in 0...stemRows {
            let u = collarU+(1-collarU)*Float(row)/Float(stemRows)
            let radius = baseRadius+(0.025-baseRadius)*u
            for i in 0..<count {
                let a0 = boundary(i), a1 = i+1 == count ? boundary(0)+2*Float.pi : boundary(i+1)
                for j in 0..<half {
                    let angle = a0+(a1-a0)*Float(j)/Float(half)
                    let ripple = 1+0.035*sin(angle*Float(count)+phase)*pow(1-u,2)
                    _ = vertex(center(u)+SIMD3(cos(angle)*radius*ripple,0,sin(angle)*radius*ripple),
                               0.24+u*0.14+0.018*cos(angle*4))
                }
            }
        }
        for row in 0..<stemRows { for j in 0..<circumference {
            let a = UInt32(row*circumference+j), b = UInt32(row*circumference+(j+1)%circumference)
            quad(a,a+UInt32(circumference),b+UInt32(circumference),b)
        } }
        let top = vertex(center(1),0.38)
        for j in 0..<circumference {
            let a = UInt32(stemRows*circumference+j)
            triangle(top,UInt32(stemRows*circumference+(j+1)%circumference),a)
        }
        let underside = vertex(center(0)+SIMD3(0,0.022,0),0.24)
        var outlets: [[UInt32]] = []
        for i in 0..<count {
            let gene = 1050+i*12
            let angle = angles[i], radial = SIMD3<Float>(cos(angle),0,sin(angle))
            let sideways = SIMD3<Float>(-sin(angle),0,cos(angle))
            let length: Float = 0.38+g(gene)*0.34
            let curl: Float = (g(gene+1)-0.5)*0.36
            let wander: Float = (g(gene+2)-0.5)*0.10
            let thickness: Float = 0.034+g(gene+3)*0.014
            let lift: Float = 0.015+g(gene+4)*0.055
            let drop: Float = 0.006+g(gene+5)*0.008
            let origin = SIMD3<Float>(collar.x, -0.614+g(gene+6)*0.025, collar.z)
                + radial*(collarRadius+0.035)
            func path(_ t: Float) -> SIMD3<Float> {
                let ease = t*t*(3-2*t)
                let lateral = curl*ease+wander*sin(t*2*Float.pi)*t
                // The first tangent leaves the flared collar; later bends may
                // rise, sweep sideways and descend again, always tapering away.
                let y = origin.y+(-0.682-drop-origin.y)*ease+lift*sin(t*Float.pi)
                return SIMD3(origin.x,y,origin.z)+radial*(length*t)+sideways*lateral
            }
            var rings: [[UInt32]] = []
            for row in 0...rootRows {
                let t = Float(row)/Float(rootRows)
                let tangent = simd_normalize(path(min(1,t+0.001))-path(max(0,t-0.001)))
                let across = simd_normalize(simd_cross(tangent,SIMD3<Float>(0,1,0)))
                let up = simd_cross(across,tangent)
                let radius = thickness*pow(1-t,1.12)+0.002
                var ring: [UInt32] = []
                for side in 0..<sides {
                    let a = Float(side)*2*Float.pi/Float(sides)
                    ring.append(vertex(path(t)+up*(cos(a)*radius)+across*(sin(a)*radius),
                                       0.255+t*0.10+cos(a*2)*0.012))
                }
                rings.append(ring)
                if row>0 { for side in 0..<sides {
                    let next = (side+1)%sides
                    quad(rings[row-1][side],rings[row-1][next],ring[next],ring[side])
                } }
            }
            let mouth = rings[0]
            outlets.append(mouth)
            // Upper half: loft into the shared collar arc. Lower half: close
            // the underside of the root flare, without any faces inside it.
            for j in 0..<half {
                let a = UInt32((i*half+j)%circumference), b = UInt32((i*half+j+1)%circumference)
                let left = (sides*3/4+j)%sides, right = (left+1)%sides
                quad(a,b,mouth[right],mouth[left])
            }
            for j in sides/4..<(sides*3/4) {
                triangle(underside,mouth[j+1],mouth[j])
            }
            let tip = vertex(path(1),0.355)
            for side in 0..<sides {
                triangle(tip,rings[rootRows][side],rings[rootRows][(side+1)%sides])
            }
        }
        // Fill the concave crotches between neighbouring roots. The trunk,
        // shoulders, root rings and underside now form one connected skin.
        for i in 0..<count {
            let seam = UInt32(((i+1)*half)%circumference)
            let right = outlets[i][sides/4], left = outlets[(i+1)%count][sides*3/4]
            triangle(underside,right,seam); triangle(underside,seam,left)
        }
        // Area-weighted shared normals soften the joined shoulders and paths.
        for index in stride(from: 0,to: mesh.indices.count,by: 3) {
            let a = Int(mesh.indices[index]), b = Int(mesh.indices[index+1]), c = Int(mesh.indices[index+2])
            let normal = simd_cross(mesh.positions[b]-mesh.positions[a],mesh.positions[c]-mesh.positions[a])
            mesh.normals[a] += normal; mesh.normals[b] += normal; mesh.normals[c] += normal
        }
        for i in mesh.normals.indices {
            let n = mesh.normals[i]
            mesh.normals[i] = simd_length_squared(n)>1e-12 ? simd_normalize(n) : [0,1,0]
        }
        return mesh
    }
}
