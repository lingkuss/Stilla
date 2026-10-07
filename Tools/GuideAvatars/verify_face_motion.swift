import Foundation
import Metal
import simd

// Exercise the production Metal functions with vertices from the exported model.
let shader = try String(contentsOfFile: "Stilla/Shaders/ZenAvatar.metal", encoding: .utf8)
let body = shader.components(separatedBy: "[[visible]]")[0]
    .replacingOccurrences(of: "#include <RealityKit/RealityKit.h>", with: "")
let source = body + """
kernel void checkFace(device const float4 *input [[buffer(0)]],
                      device float4 *output [[buffer(1)]], uint i [[thread_position_in_grid]]) {
    float3 p=input[i*2].xyz, encoded=input[i*2+1].xyz;
    output[i*6]=float4(sereneFaceOffset(p,encoded,0,0,0),0);
    output[i*6+1]=float4(sereneFaceOffset(p,encoded,1,0,0),0);
    output[i*6+2]=float4(sereneFaceOffset(p,encoded,0,.8,0),0);
    output[i*6+3]=float4(sereneFaceOffset(p,encoded,1,.8,.7),0);
    output[i*6+4]=float4(sereneFaceOffset(p,encoded,1,.1,0,-1),0);
    output[i*6+5]=float4(sereneFaceOffset(p,encoded,1,.13,0,.45),0);
}
"""
struct Sample: Decodable { let name: String; let position: [Float]; let encoded: [Float] }
let samples = try JSONDecoder().decode([Sample].self, from: Data(contentsOf: URL(fileURLWithPath: "Tools/GuideAvatars/SereneGuide/motion-samples.json")))
let input = samples.flatMap { s in [SIMD4<Float>(s.position[0],s.position[1],s.position[2],0), SIMD4<Float>(s.encoded[0],s.encoded[1],s.encoded[2],0)] }
let device=MTLCreateSystemDefaultDevice()!, queue=device.makeCommandQueue()!
let library=try device.makeLibrary(source: source, options: nil)
let pipeline=try device.makeComputePipelineState(function: library.makeFunction(name: "checkFace")!)
let buffer=device.makeBuffer(bytes: input,length: input.count*MemoryLayout<SIMD4<Float>>.stride,options:.storageModeShared)!
let output=device.makeBuffer(length: samples.count*6*MemoryLayout<SIMD4<Float>>.stride,options:.storageModeShared)!
let command=queue.makeCommandBuffer()!, encoder=command.makeComputeCommandEncoder()!
encoder.setComputePipelineState(pipeline);encoder.setBuffer(buffer,offset:0,index:0);encoder.setBuffer(output,offset:0,index:1)
encoder.dispatchThreads(.init(width:samples.count,height:1,depth:1),threadsPerThreadgroup:.init(width:1,height:1,depth:1))
encoder.endEncoding();command.commit();command.waitUntilCompleted()
precondition(command.status == .completed)
let result=output.contents().bindMemory(to:SIMD4<Float>.self,capacity:samples.count*6)
for (i,s) in samples.enumerated() {
    let rest=result[i*6], eyes=result[i*6+1], jaw=result[i*6+2], both=result[i*6+3]
    precondition(simd_length(rest)<0.000001,"Rest pose drift: \(s.name)")
    precondition(simd_length(both)<0.025,"Unbounded facial motion: \(s.name)")
    if s.name.hasPrefix("upperLid") { precondition(eyes.z>0.003 && simd_length(jaw)<0.00001,"Upper lids must open independently of speech") }
    if s.name.hasPrefix("lowerLid") { precondition(eyes.z < -0.0005 && simd_length(jaw)<0.00001,"Lower lids must open independently of speech") }
    if s.name == "lowerLip" { precondition(jaw.z < -0.004 && simd_length(eyes)<0.00001,"Lip must open without reacting to blinks") }
    if s.name == "forehead" { precondition(simd_length(both)<0.00001,"Expressions must not warp the forehead") }
}
let lower = samples.firstIndex { $0.name == "lowerLip" }!, upper = samples.firstIndex { $0.name == "upperLip" }!
for shape in 0..<6 {
    let lowerZ = samples[lower].position[2] + result[lower*6+shape].z
    let upperZ = samples[upper].position[2] + result[upper*6+shape].z
    precondition(upperZ-lowerZ > 0.0001, "Lip inversion in articulation \(shape)")
}
print("PASS: authored Serene vertices through production Metal — independent lids/jaw, speech opening, exact rest and bounded simultaneous expressions")
print("PASS: lip rims retain clearance in rest, wide/rounded vowels, F/V tuck and spread consonants")
