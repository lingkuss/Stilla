import Foundation
import simd

extension GardenGeometry {
    // Each family changes topology and silhouette, not just the petal colour.
    enum FlowerForm: Int, CaseIterable { case rosette, cosmos, lily, bells, orchid, umbel }

    static func flower(_ seed: UInt64, detail: Detail) -> GardenMesh {
        func g(_ i: Int) -> Float { GardenDNA.value(seed,i) }
        let form = FlowerForm(rawValue: family(seed,count: FlowerForm.allCases.count))!
        let fine = detail == .portrait
        var mesh = GardenMesh()
        let phase = g(2)*2*Float.pi
        // Related colours: rose/peach, violet/ice, apricot/cream, plum/rose,
        // blue/lilac, ivory/gold, coral/blush, green/ivory.
        let palettes: [SIMD2<Float>] = [[0.96,0.06],[0.73,0.57],[0.065,0.13],[0.85,0.96],
                                      [0.57,0.73],[0.12,0.10],[0.025,0.95],[0.30,0.15]]
        let palette = palettes[Int(g(3)*Float(palettes.count))]
        let hue = palette.x+(g(4)-0.5)*0.035
        var hueDelta = palette.y-palette.x
        if hueDelta > 0.5 { hueDelta -= 1 }; if hueDelta < -0.5 { hueDelta += 1 }
        let leafHue: Float = 0.24+g(5)*0.17
        let leafShape = Int(g(16)*3)
        let bend: Float = (g(1)-0.5)*0.45
        let height: Float = form == .rosette ? 0.82+g(0)*0.16 : 1.00+g(0)*0.28
        func stalk(_ u: Float) -> SIMD3<Float> { [bend*u*u,height*u-0.70,sin(u*2)*bend*0.5] }
        tube(&mesh,from: stalk(0),via: stalk(0.5),to: stalk(1),radius: 0.025,tip: 0.009,
             hue: leafHue,rows: fine ? 14 : 5,sides: fine ? 8 : 5)
        let leaves = form == .rosette || form == .orchid ? 5 : 3+Int(g(17)*3)
        for i in 0..<leaves {
            let a = phase+Float(i)*2.39996
            let basal = form == .rosette || form == .orchid
            let root = stalk(basal ? 0.06+Float(i)*0.026 : 0.14+Float(i)*0.12)
            let axis = SIMD3<Float>(cos(a),basal ? 0.7 : 0.35,sin(a))
            let length: Float = 0.32+g(20+i)*0.21
            if form == .umbel {
                let end = root+simd_normalize(axis)*length
                tube(&mesh,from: root,via: (root+end)*0.5,to: end,radius: 0.008,tip: 0.002,
                     hue: leafHue,rows: 3,sides: 4)
                for j in 0..<3 { for side: Float in [-1,1] {
                    let start = simd_mix(root,end,SIMD3(repeating: 0.18+Float(j)*0.24))
                    let direction = axis*0.3+SIMD3(-sin(a),0.3,cos(a))*side
                    leaf(&mesh,root: start,direction: direction,length: length*(0.42-Float(j)*0.07),
                         width: 0.025,shape: 0,hue: leafHue,light: 0.20,fine: fine)
                } }
            } else {
                leaf(&mesh,root: root,direction: axis,length: length,
                     width: length*(leafShape == 1 ? 0.37 : 0.20),shape: leafShape,
                     hue: leafHue,light: 0.15+g(30+i)*0.13,fine: fine,phase: a)
            }
        }
        // Petals receive coordinated throat-to-edge colour, a subtle vein and
        // optional picotee rim. DNA controls pattern independently of form.
        let pattern = Int(g(18)*3), tintDepth: Float = 0.36+g(19)*0.20
        func pigment(_ u: Float,_ v: Float,_ layer: Int) -> SIMD2<Float> {
            let edge = pow(abs(v),5)*sin(u * .pi)
            let vein = fine ? pow(max(0,cos(v*Float.pi*3)),12)*0.035*sin(u * .pi) : 0
            let rim: Float = pattern == 1 ? edge*0.18 : 0
            let flush = pattern == 2 ? sin(u * .pi)*0.09 : 0
            return [hue+hueDelta*(u*0.8+edge*0.2),min(0.96,tintDepth+u*0.35+Float(layer)*0.035-rim-flush-vein)]
        }
        func petals(at center: SIMD3<Float>, axis: SIMD3<Float>, radius: Float, count: Int,
                    layers: Int, width: Float, cup: Float, pointed: Bool, recurved: Bool = false,
                    bilateral: Bool = false) -> GardenMesh {
            var bloom = GardenMesh()
            let (up,x,z) = frame(axis)
            for layer in 0..<layers {
                let r = radius*pow(0.73,Float(layer))
                for i in 0..<count {
                    let a = phase+(Float(i)+Float(layer)*0.48)*2*Float.pi/Float(count)
                    let radial = x*cos(a)+z*sin(a), side = -x*sin(a)+z*cos(a)
                    let asymmetry: Float = 0.89+g(40+i+layer*16)*0.21
                    let size: Float = bilateral && i == 0 ? 1.22 : 1
                    bloom.surface(rows: fine ? 12 : 3,columns: fine ? 8 : 2,
                                  pigment: { pigment($0,$1,layer) }) { u,v in
                        let profile = pow(max(0,sin(u * .pi)),pointed ? 1.0 : 0.46)
                        let ruffle = sin(v*Float.pi*(3+g(13)*3)+a)*u*u*0.023*g(14)
                        let rise = cup*u*u+sin(u * .pi)*0.20+v*v*profile*0.23
                            - (recurved ? 1.1 : 0.20)*u*u*u
                        return center+radial*(r*(0.055+u)*asymmetry*size)
                            + side*(v*r*width*profile*size)
                            + up*(r*rise+ruffle+Float(layer)*0.035)
                    }
                }
            }
            let heart: Float = radius*(form == .cosmos ? 0.24 : 0.15)
            bloom.surface(rows: fine ? 6 : 3,columns: fine ? 14 : 6,pigment: { u,_ in [0.10+g(90)*0.04,0.44+u*0.35] }) { u,v in
                let a = (v+1)*Float.pi, lat = u*Float.pi
                let radial: SIMD3<Float> = (x*cos(a)+z*sin(a))*(sin(lat)*heart)
                let vertical: Float = 0.055+cos(lat)*heart*0.65
                return center+radial+up*vertical
            }
            if form == .lily || form == .orchid {
                for i in 0..<6 {
                    let a = Float(i)*Float.pi/3
                    let radial: SIMD3<Float> = (x*cos(a)+z*sin(a))*(radius*0.19)
                    let vertical: Float = 0.20+g(100+i)*0.08
                    let end: SIMD3<Float> = center+radial+up*vertical
                    tube(&bloom,from: center,via: center+up*0.13,to: end,radius: 0.005,tip: 0.003,
                         hue: 0.12,light: 0.58,rows: fine ? 4 : 2,sides: 4)
                    let d: Float = 0.020
                    bloom.facet(end-x*d,end+x*d,end+up*d+z*d,pigment: [0.095,0.49])
                    bloom.facet(end+z*d,end-z*d,end+up*d+x*d,pigment: [0.095,0.67])
                }
            }
            return bloom
        }
        let top = stalk(1)
        let axis = SIMD3<Float>(g(11)*0.25,1,0.2+g(12)*0.3)
        switch form {
        case .rosette:
            let count = 8+Int(g(6)*4)
            mesh.append(petals(at: top,axis: axis,radius: 0.44+g(8)*0.10,count: count,layers: 3+Int(g(7)*2),
                               width: 0.25,cup: 0.8+g(10)*0.4,pointed: false),at: .zero)
        case .cosmos:
            let count = 8+Int(g(6)*5)
            mesh.append(petals(at: top,axis: axis,radius: 0.49+g(8)*0.10,count: count,layers: 1+Int(g(7)*2),
                               width: 0.22,cup: 0.15+g(10)*0.22,pointed: false),at: .zero)
        case .lily:
            mesh.append(petals(at: top,axis: axis,radius: 0.49+g(8)*0.11,count: 6,layers: 1,
                               width: 0.36,cup: 0.9+g(10)*0.4,pointed: true,recurved: true),at: .zero)
        case .orchid:
            for i in 0..<2 {
                let a = phase+Float(i)*2.7
                let end = top+SIMD3<Float>(cos(a)*0.20,-Float(i)*0.23,sin(a)*0.20)
                tube(&mesh,from: stalk(0.65),via: top,to: end,radius: 0.012,tip: 0.007,
                     hue: leafHue,rows: fine ? 6 : 3,sides: 5)
                mesh.append(petals(at: end,axis: [cos(a)*0.4,0.55,0.8],radius: 0.32+g(8)*0.07,
                                   count: 5,layers: 1,width: 0.49,cup: 0.52,pointed: false,bilateral: true),at: .zero)
            }
        case .bells:
            for i in 0..<(3+Int(g(6)*3)) {
                let a = phase+Float(i)*2.39996
                let attach = stalk(0.56+Float(i)*0.075)
                let end = attach+SIMD3<Float>(cos(a)*0.29,0.16,sin(a)*0.29)
                tube(&mesh,from: attach,via: end+[0,0.18,0],to: end,radius: 0.010,tip: 0.005,
                     hue: leafHue,rows: fine ? 8 : 4,sides: 5)
                let length: Float = 0.26+g(110+i)*0.12, lobes: Float = g(6)<0.5 ? 5 : 6
                mesh.surface(rows: fine ? 14 : 6,columns: fine ? 30 : 12,pigment: { u,v in pigment(u,sin(v * .pi*lobes),0) }) { u,v in
                    let angle = (v+1)*Float.pi
                    let radius: Float = 0.025+sin(u * .pi*0.78)*0.105+pow(u,6)*0.025*cos(angle*lobes)
                    return end+[cos(angle)*radius,-u*length+pow(u,8)*0.04*cos(angle*lobes),sin(angle)*radius]
                }
            }
        case .umbel:
            for i in 0..<(7+Int(g(6)*3)) {
                let a = phase+Float(i)*2.39996
                let spread = sqrt(Float(i)/9)*0.43
                let end = top+SIMD3<Float>(cos(a)*spread,-spread*0.20+g(120+i)*0.05,sin(a)*spread)
                tube(&mesh,from: stalk(0.78),via: top,to: end,radius: 0.006,tip: 0.002,
                     hue: leafHue,rows: fine ? 4 : 2,sides: 4)
                mesh.append(petals(at: end,axis: axis,radius: 0.11+g(130+i)*0.055,count: 5,layers: 1,
                                   width: 0.43,cup: 0.3,pointed: false),at: .zero)
            }
        }
        return mesh
    }
}
