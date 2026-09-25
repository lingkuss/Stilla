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
[[visible]] void mountainWildSurface(realitykit::surface_parameters params) {
    float3 world=params.geometry().world_position();
    float3 n=normalize((params.uniforms().model_to_world()*float4(params.geometry().normal(),0)).xyz);
    float4 view=params.uniforms().world_to_view()*float4(world,1);
    float4 genes=params.uniforms().custom_parameter();
    float kind=abs(genes.x), hue=genes.y;
    float3 base=float3(params.material_constants().base_color_tint());
    float elapsed=fmod(genes.z+18.0,24.0);
    float angle=elapsed<=13.0 ? elapsed/13.0*3.14159265 : 3.14159265+(elapsed-13.0)/11.0*3.14159265;
    float elevation=sin(angle);
    float daylight=smoothstep(-0.15,0.30,elevation);
    float twilight=exp(-pow(elevation/0.24,2.0));
    float3 haze=mix(float3(0.055,0.075,0.14),dreamTint(hue+0.10,0.13,0.87),daylight);
    haze=mix(haze,float3(0.86,0.46,0.30),twilight*0.42);
    float grain=wildNoise(world.xz*0.8+world.y*0.15);
    float broad=wildNoise(world.xz*0.036+world.y*0.018);
    if (kind<0.5 || (kind>8.5 && kind<9.5) || (kind>11.5 && kind<12.5)) {
        // Mineral bands follow the folds; no universal green moss or snow preset.
        float layers=0.5+0.5*sin(world.y*1.05+broad*5+sin(world.x*0.13));
        base*=0.89+0.10*grain+0.07*layers;
        float tops=smoothstep(0.35,0.95,n.y)*smoothstep(-18.0,14.0,world.y);
        base=mix(base,dreamTint(hue+0.10,0.20,0.79),tops*(kind>11.5 ? 0.12 : 0.42));
    }
    float3 solar=normalize(float3(-cos(angle)*0.85,elevation,0.4));
    float3 sun=solar;
    float diffuse=max(0.0,dot(n,sun));
    float sky=clamp(n.y*0.5+0.5,0.0,1.0);
    float3 shadow=dreamTint(hue+0.06,0.40,0.47);
    float3 sunlight=mix(float3(1.13,0.98,0.83),float3(1.35,0.65,0.35),twilight);
    float moonDiffuse=max(0.0,dot(n,-sun));
    float ambient=0.13+daylight*0.87;
    float3 direct=sunlight*diffuse*daylight*0.92
        +float3(0.20,0.30,0.53)*moonDiffuse*(1-daylight)*0.38;
    float3 color=base*(shadow*(0.38+sky*0.42)*ambient+direct);
    // Soft edge illumination, restrained enough to retain sculptural depth.
    float3 eye=normalize(-view.xyz);
    float3 viewNormal=normalize((params.uniforms().world_to_view()*float4(n,0)).xyz);
    float rim=pow(1-abs(dot(viewNormal,eye)),3.0)*max(0.0,n.y*0.5+0.5);
    color+=base*float3(0.32,0.25,0.20)*rim*ambient;
    if ((kind>3.5 && kind<5.5) || (kind>9.5 && kind<10.5) || kind>12.5) {
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
    // Clear daylight preserves local pigment and contrast. Atmospheric depth
    // returns gently around dusk/night; it never washes over the foreground.
    float distanceFog=(1-exp(-max(0.0,depth-80)*0.0028))*(1-daylight);
    color=mix(color,haze,clamp(distanceFog,0.0,0.65));

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
        float mist=sin(reveal*3.14159265)*0.45;
        color=mix(color,haze,mist);
    }
    params.surface().set_emissive_color(half3(color));
}
