#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// Authored meshes retain Blender's local Z-up coordinates. Parameters are:
// x = breath, y = eyelids, z = cloth / lip rounding, w = speech opening.
float bell(float value, float center, float width) {
    float distance = (value - center) / width;
    return exp(-distance * distance);
}

float3 zenTorsoOffset(float3 p, float breath, float cloth) {
    // Hard zero below the abdomen: hands, crossed legs and cushion cannot bob.
    float upper = smoothstep(0.59f, 0.73f, p.z);
    float chest = bell(p.x, 0.0f, 0.28f) * bell(p.z, 0.97f, 0.23f) * upper;
    float belly = bell(p.x, 0.0f, 0.25f) * bell(p.z, 0.73f, 0.15f) * upper;
    float shoulders = bell(abs(p.x), 0.29f, 0.12f) * bell(p.z, 1.10f, 0.13f) * upper;
    float front = 1.0f - smoothstep(-0.04f, 0.05f, p.y);
    float collar = bell(p.x, 0.0f, 0.15f) * smoothstep(1.13f, 1.27f, p.z);
    float3 offset = float3(
        breath * (0.023f * p.x / 0.28f * chest + 0.004f * sign(p.x) * shoulders),
        -breath * (0.024f * chest + 0.012f * belly) * front,
        breath * (0.014f * chest + 0.013f * shoulders + 0.003f * collar));
    // Small changes in the existing linen folds lag the rib cage slightly.
    float folds = sin(p.x * 62.0f + p.z * 15.0f) * chest * front;
    offset.y += 0.003f * cloth * folds;
    return offset;
}

float3 zenSpeechOffset(float3 p, float3 encoded, float opening, float rounding) {
    float3 speech = (encoded - 0.5f) * 0.08f;
    float lips = bell(p.x, 0, 0.043f) * bell(p.z, -0.071f, 0.023f)
        * (1 - smoothstep(-0.205f, -0.18f, p.y));
    return speech * opening + float3(-p.x * 0.16f, -0.003f, 0) * lips * rounding;
}

[[visible]] void zenTorso(realitykit::geometry_parameters params) {
    float3 p = params.geometry().model_position();
    float4 control = params.uniforms().custom_parameter();
    params.geometry().set_model_position_offset(zenTorsoOffset(p, control.x, control.z));

    // Recompute the deformed surface normal so light travels over the moving
    // folds, instead of leaving the clothing's shading attached to its rest pose.
    float3 n = normalize(params.geometry().normal());
    float3 axis = abs(n.z) < 0.9f ? float3(0,0,1) : float3(0,1,0);
    float3 t = normalize(cross(n, axis));
    float3 b = cross(n, t);
    float epsilon = 0.001f;
    float3 dt = 2.0f * epsilon * t
        + zenTorsoOffset(p + epsilon*t, control.x, control.z)
        - zenTorsoOffset(p - epsilon*t, control.x, control.z);
    float3 db = 2.0f * epsilon * b
        + zenTorsoOffset(p + epsilon*b, control.x, control.z)
        - zenTorsoOffset(p - epsilon*b, control.x, control.z);
    params.geometry().set_normal(normalize(cross(dt, db)));
}

[[visible]] void zenEyelids(realitykit::geometry_parameters params) {
    // A tiny linear data texture carries anatomical closed-to-open displacement.
    // The eyelid skin and its portrait texture move together.
    float3 p = params.geometry().model_position();
    float2 uv = float2((p.x + 0.105f) / 0.21f, 1.0f - (p.z - 0.01f) / 0.12f);
    constexpr sampler lookup(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 delta = (float2(params.textures().custom().sample(lookup, uv, level(0)).rg) - 0.5f) * 0.05f;
    float4 control = params.uniforms().custom_parameter();
    float mask = p.y < -0.10f && all(uv >= 0.0f) && all(uv <= 1.0f) ? 1.0f : 0.0f;
    // Authored anatomical displacement keeps the lip seam, cheeks and chin in
    // one mesh. No detached mouth patch and no rigid lower-face translation.
    float3 offset = float3(0, delta.x, delta.y) * control.y * mask
        + zenSpeechOffset(p, params.geometry().color().rgb, control.w, control.z);
    params.geometry().set_model_position_offset(offset);
    params.geometry().set_color(float4(1));
}

[[visible]] void zenEyeSurface(realitykit::surface_parameters params) {
    // Fine radial fibers and a soft limbal transition belong to the curved eye
    // surface. Lighting still uses the globe's normals and native PBR shading.
    float3 d = normalize(params.geometry().model_position() / float3(0.031f, 0.027f, 0.025f));
    float yaw = params.uniforms().custom_parameter().x * 0.12f;
    d.xy = float2(cos(yaw)*d.x + sin(yaw)*d.y, -sin(yaw)*d.x + cos(yaw)*d.y);
    float pitch = -0.075f;
    d.yz = float2(cos(pitch)*d.y + sin(pitch)*d.z, -sin(pitch)*d.y + cos(pitch)*d.z);
    float theta = acos(clamp(-d.y, -1.0f, 1.0f));
    float phi = atan2(d.z, d.x);
    float3 color = params.material_constants().base_color_tint();
    if (theta > 0.17f && theta < 0.45f) {
        float fibers = 0.85f + 0.10f*sin(phi*61 + theta*24) + 0.06f*sin(phi*109 - theta*31);
        color *= fibers * (1 - 0.32f*smoothstep(0.34f, 0.45f, theta));
    } else if (theta >= 0.45f) {
        color *= 0.72f + 0.28f*pow(max(0.0f, -d.y), 3.0f);
    }
    params.surface().set_base_color(half3(color));
    params.surface().set_roughness(half(theta < 0.45f ? 0.28f : 0.43f));
    params.surface().set_specular(half(0.32f));
}
