import SceneKit
import UIKit

/// Bounded studio refraction: three wavelength samples, one reflection sample,
/// Beer–Lambert absorption and Fresnel edges. Botanicals use a softer, pigment-
/// preserving version of the same light. No ray marching or scene captures.
enum GardenCrystalOptics {
    static let revision = 3
    private static let environment: UIImage = {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 512,height: 256),format: format).image { context in
            let colors = [UIColor(red: 0.98,green: 0.96,blue: 0.91,alpha: 1).cgColor,
                          UIColor(red: 0.62,green: 0.73,blue: 0.84,alpha: 1).cgColor,
                          UIColor(red: 0.17,green: 0.23,blue: 0.34,alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),colors: colors,locations: [0,0.52,1]) {
                context.cgContext.drawLinearGradient(gradient,start: .zero,end: CGPoint(x: 0,y: 256),options: [])
            }
            // Tall softboxes and a warm sunlit opening give facets something
            // distinct to reflect, with sharp boundaries for spectral separation.
            UIColor(red: 1,green: 0.98,blue: 0.92,alpha: 1).setFill()
            context.fill(CGRect(x: 54,y: 24,width: 52,height: 146))
            context.fill(CGRect(x: 320,y: 8,width: 28,height: 168))
            UIColor(red: 0.93,green: 0.98,blue: 1,alpha: 1).setFill()
            context.fill(CGRect(x: 199,y: 38,width: 12,height: 134))
            context.fill(CGRect(x: 432,y: 34,width: 8,height: 148))
        }
    }()

    static func configure(_ material: SCNMaterial, kind: GardenKind, seed: UInt64,
                          lower: SIMD3<Float>, upper: SIMD3<Float>) {
        let botanical = kind != .crystal
        // The fragment modifier supplies the complete optical lighting.
        material.lightingModel = .constant
        material.metalness.contents = 0.0
        material.roughness.contents = 0.10
        material.transparency = botanical ? 1.0 : 0.85
        material.isDoubleSided = true
        material.transparencyMode = .dualLayer
        material.blendMode = .alpha
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = true
        material.shaderModifiers = [.fragment: fragment]
        let sky = SCNMaterialProperty(contents: environment)
        sky.wrapS = .repeat; sky.wrapT = .clamp
        sky.minificationFilter = .linear; sky.magnificationFilter = .linear
        material.setValue(sky,forKey: "crystalSky")
        material.setValue(1.47+GardenDNA.value(seed,910)*0.10,forKey: "crystalIOR")
        material.setValue(0.025+GardenDNA.value(seed,911)*0.023,forKey: "crystalDispersion")
        material.setValue(botanical ? 1.0 : 0.0,forKey: "gardenBotanical")
        material.setValue(kind == .tree ? 0.79 : 0.73,forKey: "gardenOpacity")
        let palette = GardenGeometry.crystalPalette(seed)
        material.setValue(palette.density*(0.80+GardenDNA.value(seed,912)*0.5),forKey: "crystalDensity")
        material.setValue(palette.milkiness+GardenDNA.value(seed,913)*0.08,forKey: "crystalCloud")
        let smoky = palette.hue<0.10 ? 0.35+GardenDNA.value(seed,916)*0.35 : 0.0
        material.setValue(smoky,forKey: "crystalSmoke")
        material.setValue(2.0+GardenDNA.value(seed,914)*5.0,forKey: "crystalZones")
        material.setValue(GardenDNA.value(seed,915)*6.28,forKey: "crystalPhase")
        material.setValue(NSValue(scnVector3: SCNVector3(lower.x,lower.y,lower.z)),forKey: "crystalLower")
        let span = simd_max(upper-lower,SIMD3(repeating: 0.001))
        material.setValue(NSValue(scnVector3: SCNVector3(span.x,span.y,span.z)),forKey: "crystalSpan")
    }

    private static let fragment = """
    #pragma arguments
    texture2d crystalSky;
    float crystalIOR;
    float crystalDispersion;
    float crystalDensity;
    float crystalCloud;
    float crystalSmoke;
    float crystalZones;
    float crystalPhase;
    float gardenBotanical;
    float gardenOpacity;
    float3 crystalLower;
    float3 crystalSpan;
    #pragma declaration
    float3 gardenSky(float3 ray, texture2d<float> sky) {
        constexpr sampler skySampler(coord::normalized, address::repeat, filter::linear);
        float2 uv = float2(atan2(ray.z, ray.x) * 0.15915494 + 0.5,
                          acos(clamp(ray.y, -1.0, 1.0)) * 0.31830989);
        return sky.sample(skySampler, uv).rgb;
    }
    #pragma transparent
    #pragma body
    float3 v = normalize(_surface.view);
    float3 n = normalize(_surface.normal);
    if (dot(n, v) < 0.0) n = -n;
    float facing = clamp(dot(n, v), 0.001, 1.0);
    float f0 = pow((crystalIOR - 1.0) / (crystalIOR + 1.0), 2.0);
    float fresnel = f0 + (1.0 - f0) * pow(1.0 - facing, 5.0);
    float3 worldN = normalize((scn_frame.inverseViewTransform * float4(n, 0.0)).xyz);
    float3 worldV = normalize((scn_frame.inverseViewTransform * float4(v, 0.0)).xyz);
    float3 reflected = reflect(-worldV, worldN);
    float3 redRay = refract(-worldV, worldN, 1.0 / (crystalIOR - crystalDispersion));
    float3 greenRay = refract(-worldV, worldN, 1.0 / crystalIOR);
    float3 blueRay = refract(-worldV, worldN, 1.0 / (crystalIOR + crystalDispersion));
    float3 transmitted = float3(gardenSky(redRay, crystalSky).r,
                                gardenSky(greenRay, crystalSky).g,
                                gardenSky(blueRay, crystalSky).b);
    float3 reflectedLight = gardenSky(reflected, crystalSky);
    float3 pigment = clamp(_surface.diffuse.rgb, float3(0.06), float3(1.0));
    float3 sun = normalize(float3(-0.42, 0.66, 0.62));
    float glint = pow(max(0.0, dot(reflected, sun)), 140.0);
    if (gardenBotanical > 0.5) {
        // Thin coloured glass: retain the petal/leaf gradient and baked soft
        // light, adding a quiet spectral window and grazing reflections.
        // Dark stems and bark stay denser so the silhouette remains grounded.
        float peak = max(pigment.r, max(pigment.g, pigment.b));
        float3 tint = pigment / max(0.001, peak);
        float woody = 1.0 - smoothstep(0.20, 0.55, peak);
        // Compensate for the pale collection background showing through. This
        // deepens the existing hue instead of replacing it with a glass colour.
        float3 richPigment = max(float3(0.02), pigment - (float3(peak) - pigment) * 0.35);
        float3 window = transmitted * mix(float3(1.0), tint, 0.85);
        float3 body = mix(richPigment, window, 0.22 - woody * 0.08);
        float3 color = mix(body, reflectedLight, 0.05 + fresnel * 0.34);
        color += float3(1.0, 0.96, 0.86) * glint * 0.24;
        float opacity = clamp(gardenOpacity + woody * 0.10 + fresnel * 0.14, 0.70, 0.97);
        _output.color = float4(saturate(color) * opacity, opacity);
    } else {
        float3 local = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
        float3 position = saturate((local - crystalLower) / crystalSpan);
        float depth = (0.32 + 0.68 * (1.0 - position.y)) / (0.55 + 0.45 * facing);
        // Preserve the earned colour; thick paths absorb more of its complement.
        float3 tint = pigment / max(0.001, max(pigment.r, max(pigment.g, pigment.b)));
        float axial = _surface.diffuseTexcoord.y;
        float zone = 0.83 + 0.17 * smoothstep(-0.5, 0.5, sin(axial * crystalZones * 6.283 + crystalPhase));
        float3 absorption = exp(-((1.0 - tint) * crystalDensity + crystalSmoke) * depth * zone);
        float3 body = transmitted * absorption;
        // A quiet, stationary veil inside some specimens. Two analytic waves keep
        // this bounded; no volume textures, particles or ray marching.
        float veil = smoothstep(0.35, 0.85, sin(dot(position, float3(9.0, 6.0, 4.0)) + crystalPhase)
            * sin(dot(position, float3(-5.0, 8.0, 7.0))));
        body = mix(body, float3(0.86, 0.88, 0.90), veil * crystalCloud * 0.40);
        float3 color = mix(body, reflectedLight, saturate(0.12 + fresnel * 0.82));
        // Fine growth striations affect a highlight, not the silhouette.
        float striation = smoothstep(0.94, 1.0, sin(axial * 310.0 + crystalPhase));
        color += float3(1.0, 0.96, 0.86) * (glint * 0.48 + striation * fresnel * 0.06);
        // Front surfaces stay translucent; grazing facets retain a crisp silhouette.
        float opacity = clamp(0.54 + depth * 0.13 + fresnel * 0.24 + glint * 0.16, 0.50, 0.96);
        _output.color = float4(saturate(color) * opacity, opacity);
    }
    """
}
