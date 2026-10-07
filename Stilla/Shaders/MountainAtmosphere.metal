#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// A quiet, illustrative light model with depth and low-lying mist. No textures,
// external assets, animated noise, or per-frame material updates are required.
[[visible]] void mountainAtmosphere(realitykit::surface_parameters params) {
    float3 world = params.geometry().world_position();
    float4 view = params.uniforms().world_to_view() * float4(world, 1);
    float3 n = normalize((params.uniforms().model_to_world()
                          * float4(params.geometry().normal(), 0)).xyz);
    float light = max(0.0f, dot(n, normalize(float3(-0.6, 0.85, 0.35))));
    float3 base = float3(params.material_constants().base_color_tint());
    float3 shade = mix(float3(0.65,0.76,0.77), float3(1.12,1.06,0.88), light);
    float3 color = base * shade;
    float4 controls = params.uniforms().custom_parameter();
    float kind = controls.x;
    if (controls.w > 0.5 && kind > 3.5 && kind < 4.5) {
        // A shared valley palette warms slowly toward the upper temple grove.
        float ascent = smoothstep(0.0f,136.0f,-world.z);
        color *= mix(float3(0.94,1.02,0.96),float3(1.16,1.04,0.84),ascent);
    }
    // Rock strata and soft moss patches are tied to mesh coordinates, so floating
    // origin updates cannot make details swim across the surface.
    float3 local = params.geometry().model_position();
    if (kind < 0.5) {
        float strata = sin(local.y*6.0 + sin(local.x*0.9)*1.3 + local.z*0.17 + controls.y);
        color *= 0.95 + 0.05*strata;
        float moss = smoothstep(0.35,0.85,n.y) * smoothstep(0.0,0.7,sin(local.x*0.7)*cos(local.z*0.45 + controls.z));
        color = mix(color,color*float3(0.84,1.01,0.80),moss*0.6);
    } else if (kind > 7.5 && kind < 8.5) {
        float ripples = pow(0.5+0.5*sin(local.x*11 + local.z*4 + sin(local.z*2)),10.0);
        color = mix(base*0.87,float3(0.82,0.88,0.80),0.2+ripples*0.16);
    }
    float depth = length(view.xyz);
    float4x4 worldToView = params.uniforms().world_to_view();
    float3x3 rotation(worldToView[0].xyz, worldToView[1].xyz, worldToView[2].xyz);
    float3 cameraPosition = -(transpose(rotation) * worldToView[3].xyz);
    float lowMist = 1 - exp(-max(0.0f, cameraPosition.y - world.y - 17) * 0.055);
    float distanceMist = 1 - exp(-max(0.0f, depth - 42) * 0.014);
    float mist = clamp(max(lowMist, distanceMist), 0.0f, 0.97f);
    color = mix(color, float3(0.73,0.78,0.72), mist);
    params.surface().set_emissive_color(half3(color));
}

float wildHash(float2 p) { return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
float wildNoise(float2 p) {
    float2 i=floor(p),f=fract(p); f=f*f*(3-2*f);
    return mix(mix(wildHash(i),wildHash(i+float2(1,0)),f.x),
               mix(wildHash(i+float2(0,1)),wildHash(i+float2(1,1)),f.x),f.y);
}
float3 dreamTint(float hue, float saturation, float value) {
    float3 h=fract(hue+float3(0,2.0/3.0,1.0/3.0))*6;
    return value*mix(float3(1),clamp(abs(h-3)-1,0.0,1.0),saturation);
}
// A bounded procedural light environment for the translucent-world experiment.
// Four analytic samples replace a scene capture, cube map or ray-marched volume.
float3 mountainPrismSky(float3 ray, float daylight, float twilight, float3 sun) {
    float high=smoothstep(-0.12,0.85,ray.y);
    float3 horizon=mix(float3(0.10,0.13,0.23),float3(0.88,0.91,0.95),daylight);
    horizon=mix(horizon,float3(0.96,0.69,0.55),twilight*0.30);
    float3 zenith=mix(float3(0.035,0.055,0.12),float3(0.44,0.66,0.87),daylight);
    float3 sky=mix(horizon,zenith,high);
    float below=1-smoothstep(-0.65,0.04,ray.y);
    float3 ground=mix(float3(0.08,0.09,0.15),float3(0.57,0.52,0.63),daylight);
    sky=mix(sky,ground,below*0.72);
    float glow=pow(max(0.0,dot(ray,sun)),64.0)*daylight;
    // The narrow warm opening gives wavelength-separated rays a gentle edge
    // to refract. It follows the existing local-time sun, without an animation.
    sky+=mix(float3(1.0,0.94,0.82),float3(1.0,0.70,0.49),twilight)*glow*0.55;
    return sky;
}
[[visible]] void mountainWildSurface(realitykit::surface_parameters params) {
    float3 world=params.geometry().world_position();
    float3 n=normalize((params.uniforms().model_to_world()*float4(params.geometry().normal(),0)).xyz);
    float4 view=params.uniforms().world_to_view()*float4(world,1);
    float4 genes=params.uniforms().custom_parameter();
    float kind=abs(genes.x), hue=fract(genes.y);
    bool economical=genes.y>1.5;
    float3 base=float3(params.material_constants().base_color_tint());
    if (kind > 29.5) {
        float2 pigment = params.geometry().uv0();
        base = dreamTint(pigment.x,0.70*(1-pigment.y*0.8),0.40+0.60*pigment.y);
    }
    float elapsed=fmod(genes.z+18.0,24.0);
    float angle=elapsed<=13.0 ? elapsed/13.0*3.14159265 : 3.14159265+(elapsed-13.0)/11.0*3.14159265;
    float elevation=sin(angle);
    float daylight=smoothstep(-0.15,0.30,elevation);
    float twilight=exp(-pow(elevation/0.24,2.0));
    float3 haze=mix(float3(0.055,0.075,0.14),float3(0.84,0.85,0.91),daylight);
    haze=mix(haze,float3(0.86,0.46,0.30),twilight*0.42);
    float grain=wildNoise(world.xz*0.8+world.y*0.15);
    float broad=wildNoise(world.xz*0.036+world.y*0.018);
    if (kind<0.5 || (kind>8.5 && kind<9.5)) {
        float layers=0.5+0.5*sin(world.y*0.28+broad*3+sin(world.x*0.06));
        base*=0.94+0.035*grain+0.025*layers;
    }
    if (kind>11.5 && kind<12.5) {
        // Flower drifts follow broad contour bands, with exposed warm stone on
        // steep faces. Fine detail fades by pixel footprint, avoiding shimmer.
        float meadow=smoothstep(0.57,0.91,n.y)*(1-smoothstep(250.0,1100.0,-world.z)*0.72);
        float drift=wildNoise(world.xz*0.055+float2(hue*17,0));
        float ribbons=0.5+0.5*sin(world.y*0.42+world.x*0.07+broad*4);
        float3 lavender=dreamTint(hue,0.35,0.55);
        float3 rose=float3(0.59,0.38,0.47);
        float3 sage=float3(0.41,0.47,0.36);
        float3 bloom=mix(lavender,rose,smoothstep(0.48,0.78,drift));
        bloom=mix(sage,bloom,smoothstep(0.22,0.48,drift)*0.86+0.14);
        bloom*=0.94+0.06*ribbons;
        float detail=1-smoothstep(0.2,0.9,length(fwidth(world.xz)));
        bloom*=1+(grain-0.5)*0.13*detail;
        float3 limestone=float3(0.48,0.45,0.53)*(0.96+0.04*broad);
        base=mix(limestone,bloom,meadow);
    }
    if (kind>1.5 && kind<2.5) {
        base*=0.97+0.03*grain;
    }
    if (kind>17.5 && kind<18.5) {
        float bark=0.5+0.5*sin(world.y*1.4+wildNoise(world.xz*3)*4);
        base*=0.87+0.13*bark;
    } else if ((kind>18.5 && kind<29.5) || kind>31.5) {
        // Leaf-scale mottling and darker undersides give the canopy depth,
        // with no shadow maps, alpha sorting or individual leaf entities.
        float foliage=wildNoise(world.xz*2.4+world.y*1.1);
        base*=0.78+0.22*foliage;
        base*=0.80+0.20*smoothstep(-0.6,0.7,n.y);
    }
    float3 solar=normalize(float3(-cos(angle)*0.85,elevation,0.4));
    float3 sun=solar;
    float diffuse=max(0.0,dot(n,sun));
    float sky=clamp(n.y*0.5+0.5,0.0,1.0);
    float3 shadow=float3(0.48,0.49,0.61);
    float3 sunlight=mix(float3(1.10,0.99,0.88),float3(1.24,0.75,0.51),twilight);
    float moonDiffuse=max(0.0,dot(n,-sun));
    float ambient=0.13+daylight*0.87;
    float3 direct=sunlight*diffuse*daylight*0.86
        +float3(0.20,0.30,0.53)*moonDiffuse*(1-daylight)*0.38;
    float3 color=base*(shadow*(0.54+sky*0.46)*ambient+direct);
    // Soft edge illumination, restrained enough to retain sculptural depth.
    float3 eye=normalize(-view.xyz);
    float3 viewNormal=normalize((params.uniforms().world_to_view()*float4(n,0)).xyz);
    float rim=pow(1-abs(dot(viewNormal,eye)),3.0)*max(0.0,n.y*0.5+0.5);
    color+=base*float3(0.32,0.25,0.20)*rim*ambient;
    if ((kind>3.5 && kind<5.5) || (kind>9.5 && kind<10.5) || (kind>12.5 && kind<17.5) || kind>18.5) {
        color+=base*(max(0.0,-dot(n,sun))*daylight+diffuse*(1-daylight)*0.2)*0.3*ambient;
    }
    if (kind>5.5 && kind<6.5) {
        float2 traits=params.geometry().uv0();
        float family=floor(traits.x),energy=fract(traits.x)/0.9,variation=traits.y;
        float direction=variation*6.2831853;
        float2 wind=float2(cos(direction),sin(direction));
        float u=dot(world.xz,wind),v=dot(world.xz,float2(-wind.y,wind.x));
        if (family<0.5) {
            float strength=max(0.0,(energy-0.28)/0.72);
            float time=genes.x>0 ? params.uniforms().time() : 0;
            float frequency=0.12+variation*0.22;
            float wave=u*frequency-time*(0.25+strength*0.5);
            float crossWave=v*frequency*0.63+time*0.17;
            float2 slope=wind*cos(wave)*strength*0.30
                +float2(-wind.y,wind.x)*cos(crossWave)*strength*0.14;
            float3 waterNormal=normalize(float3(slope.x,1,slope.y));
            float3 waterView=normalize((params.uniforms().world_to_view()*float4(waterNormal,0)).xyz);
            float fresnel=pow(1-abs(dot(waterView,eye)),4.0);
            float3 reflectedSky=mix(base*0.75,haze,0.25+fresnel*0.58);
            color=reflectedSky*ambient;
            float3 viewSun=normalize((params.uniforms().world_to_view()*float4(sun,0)).xyz);
            float glint=pow(max(0.0,dot(reflect(-viewSun,waterView),eye)),mix(180.0,45.0,strength));
            color+=sunlight*glint*daylight*0.6;
            // Broad broken crests rather than uniform horizontal stripe marks.
            float crest=pow(0.5+0.5*sin(wave+sin(crossWave)*0.4),10.0);
            color+=base*crest*strength*0.17*ambient;
        } else if (family<1.5) {
            float ripples=sin(u*(1.2+energy)+sin(v*0.07)*2);
            color*=0.88+0.12*ripples;
            color+=base*grain*0.035*ambient;
        } else if (family<2.5) {
            float patches=wildNoise(world.xz*0.055);
            color*=0.70+patches*0.55;
            color=mix(color,color*dreamTint(hue+0.4,0.5,1.2),grain*0.20);
        } else {
            float veins=pow(1-abs(sin(u*0.10+sin(v*0.045)*2+grain*0.15)),12.0);
            color*=0.86+grain*0.18;
            color+=base*veins*0.28*ambient;
        }
    }
    float depth=length(view.xyz);
    if (kind > 30.5 && kind < 31.5) {
        float glint = pow(max(0.0,dot(n,normalize(float3(-0.35,0.6,0.72)))),24.0);
        color += float3(0.82,0.92,1.0)*glint*(0.12+daylight*0.35);
    }
    // Keep rock and trail solid and colourful even at dusk. The separate cloud
    // bank provides the destination, rather than a veil over the entire world.
    float distanceFog=(1-exp(-max(0.0,depth-180)*0.001))*(1-daylight)*0.12;
    color=mix(color,haze,distanceFog);
    if (kind>10.5 && kind<11.5) {
        float billow=0.38+0.38*sky+0.24*diffuse;
        billow*=0.94+0.06*wildNoise(world.xz*0.055+world.y*0.03);
        float3 cloudDay=mix(float3(0.92,0.95,1.0),float3(1.0,0.94,0.84),daylight);
        cloudDay=mix(cloudDay,float3(1.0,0.77,0.61),twilight*0.32);
        color=mix(float3(0.10,0.14,0.23),cloudDay,daylight)*billow;
    }

    float opacity=1;
    if (kind<29.5) {
        bool cloud=kind>10.5 && kind<11.5;
        bool foliage=kind>18.5 && kind<21.5;
        bool terrain=kind>11.5 && kind<12.5;
        bool path=kind>1.5 && kind<2.5;
        float4x4 worldToView=params.uniforms().world_to_view();
        float3x3 rotation(worldToView[0].xyz,worldToView[1].xyz,worldToView[2].xyz);
        float3 v=normalize(transpose(rotation)*eye);
        float3 normal=dot(n,v)<0 ? -n : n;
        float facing=clamp(dot(normal,v),0.001,1.0);
        float fresnel=0.035+0.965*pow(1-facing,5.0);
        float ior=cloud ? 1.32 : 1.46;
        float dispersion=0.028;
        float3 reflected=reflect(-v,normal);
        float3 reflection=mountainPrismSky(reflected,daylight,twilight,sun);
        float3 tint=base/max(0.001,max(base.r,max(base.g,base.b)));
        float peak=max(color.r,max(color.g,color.b));
        float3 pigment=max(float3(0),color-(float3(peak)-color)*0.14);
        color=pigment;
        if (!economical) {
            float3 red=mountainPrismSky(refract(-v,normal,1/(ior-dispersion)),daylight,twilight,sun);
            float3 green=mountainPrismSky(refract(-v,normal,1/ior),daylight,twilight,sun);
            float3 blue=mountainPrismSky(refract(-v,normal,1/(ior+dispersion)),daylight,twilight,sun);
            float3 transmission=float3(red.r,green.g,blue.b);
            float3 window=transmission*mix(float3(1),tint,cloud ? 0.2 : 0.72);
            color=mix(pigment,window,cloud ? 0.20 : 0.14);
        }
        color=mix(color,reflection,0.06+fresnel*(cloud ? 0.28 : 0.42));
        float glint=pow(max(0.0,dot(reflected,sun)),90.0)*daylight;
        color+=sunlight*glint*(cloud ? 0.10 : 0.24);
        // Keep the mountain's silhouette and the route readable. Thin crowns
        // and clouds transmit more; grazing edges retain their shape.
        float density=cloud ? 0.72 : foliage ? 0.80 : terrain ? 0.94 : path ? 0.96 : 0.88;
        opacity=economical ? 1 : min(0.99,density+fresnel*0.13);
    }

    // Two bounded worlds interweave along a shared spatial field. Front/back
    // geometry changes at different times; distant changes are veiled by haze.
    // w=0: settled. Incoming: 1+t. Outgoing: -1-t. No alpha sorting required.
    if (abs(genes.w)>0.5) {
        float progress=abs(genes.w)-1;
        float front=clamp((-world.z+35)/290,0.0,1.0);
        float boundary=front*0.48+wildNoise(world.xz*0.025)*0.12;
        float reveal=smoothstep(boundary,boundary+0.40,progress);
        float coverage=genes.w>0 ? reveal : 1-reveal;
        if (coverage<wildHash(floor(world.xz*31+world.y*17))) discard_fragment();
        float mist=sin(reveal*3.14159265)*0.10;
        color=mix(color,haze,mist);
    }
    params.surface().set_emissive_color(half3(color));
    params.surface().set_opacity(half(opacity));
}
