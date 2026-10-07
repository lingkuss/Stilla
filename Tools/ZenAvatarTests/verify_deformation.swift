import Foundation
import Metal
import simd

// Compile the actual production deformation function into a tiny compute check.
// No second implementation of the breathing math is maintained by this test.
let path = "Stilla/Shaders/ZenAvatar.metal"
let shader = try String(contentsOfFile: path, encoding: .utf8)
let body = String(shader.components(separatedBy: "[[visible]]")[0])
    .replacingOccurrences(of: "#include <RealityKit/RealityKit.h>", with: "")
let source = body + """

kernel void verifyTorso(device const float4 *points [[buffer(0)]],
                       device float4 *results [[buffer(1)]], uint index [[thread_position_in_grid]]) {
    float3 p = points[index].xyz;
    results[index * 3] = float4(zenTorsoOffset(p, 0, 0), 0);
    results[index * 3 + 1] = float4(zenTorsoOffset(p, 1, 1), 0);
    results[index * 3 + 2] = float4(zenTorsoOffset(p, 1, 0), 0);
}

kernel void verifySpeech(device const float4 *points [[buffer(0)]],
                         device float4 *results [[buffer(1)]], uint index [[thread_position_in_grid]]) {
    float3 p = points[index * 2].xyz;
    float3 encoded = points[index * 2 + 1].xyz;
    results[index * 3] = float4(zenSpeechOffset(p, encoded, 0, 0), 0);
    results[index * 3 + 1] = float4(zenSpeechOffset(p, encoded, 0.8, 0), 0);
    results[index * 3 + 2] = float4(zenSpeechOffset(p, encoded, 0.8, 0.8), 0);
}
"""
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { fatalError("Metal is unavailable") }
let library = try device.makeLibrary(source: source, options: nil)
let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "verifyTorso")!)
let points: [SIMD4<Float>] = [
    [0, -0.18, 0.97, 0], // chest
    [0.22, -0.16, 0.97, 0], // right rib cage
    [-0.22, -0.16, 0.97, 0], // left rib cage
    [0.29, -0.12, 1.10, 0], // shoulder
    [0, -0.28, 0.49, 0], // hands
    [0.5, -0.22, 0.30, 0], // knee
    [0, -0.22, 0.09, 0], // cushion
    [0.1, -0.20, 0.85, 0] // cloth fold
]
let input = device.makeBuffer(bytes: points, length: MemoryLayout<SIMD4<Float>>.stride * points.count, options: .storageModeShared)!
let output = device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride * points.count * 3, options: .storageModeShared)!
let command = queue.makeCommandBuffer()!
let encoder = command.makeComputeCommandEncoder()!
encoder.setComputePipelineState(pipeline)
encoder.setBuffer(input, offset: 0, index: 0)
encoder.setBuffer(output, offset: 0, index: 1)
encoder.dispatchThreads(MTLSize(width: points.count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: points.count, height: 1, depth: 1))
encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
precondition(command.status == .completed, "Metal execution failed: \(String(describing: command.error))")
let result = output.contents().bindMemory(to: SIMD4<Float>.self, capacity: points.count * 3)
for i in points.indices {
    precondition(simd_length(result[i * 3]) < 0.000001, "Rest pose drift")
    precondition(simd_length(result[i * 3 + 1]) < 0.06, "Breath must stay inside the renderer's deformation margin")
}
precondition(result[1].y < -0.035 && result[1].z > 0.022, "Chest must expand forward and visibly rise in the frontal view")
precondition(result[4].x > 0.015 && result[7].x < -0.015, "Rib cage expansion must be visible on both sides")
precondition(result[10].z > 0.02, "Shoulder must visibly follow the breath")
for i in 4...6 { precondition(simd_length(result[i * 3 + 1]) < 0.000001, "Hands, legs and cushion must stay still") }
precondition(abs(result[22].y - result[23].y) > 0.0001, "Cloth should respond independently of chest expansion")
print("PASS: production Metal on GPU — chest expansion, bilateral ribs, shoulder lift, fixed hands/legs/cushion, delayed folds and bounded/rest poses")

struct SpeechSample: Decodable {
    let name: String
    let position: [Float]
    let encoded: [Float]
}
let samples = try JSONDecoder().decode([SpeechSample].self, from: Data(contentsOf: URL(fileURLWithPath: "Tools/ZenAvatar/speech-samples.json")))
let vertices = samples.flatMap { sample in
    [SIMD4<Float>(sample.position[0], sample.position[1], sample.position[2], 0),
     SIMD4<Float>(sample.encoded[0], sample.encoded[1], sample.encoded[2], 0)]
}
let speechInput = device.makeBuffer(bytes: vertices, length: MemoryLayout<SIMD4<Float>>.stride * vertices.count, options: .storageModeShared)!
let speechOutput = device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride * samples.count * 3, options: .storageModeShared)!
let speechPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "verifySpeech")!)
let speechCommand = queue.makeCommandBuffer()!
let speechEncoder = speechCommand.makeComputeCommandEncoder()!
speechEncoder.setComputePipelineState(speechPipeline)
speechEncoder.setBuffer(speechInput, offset: 0, index: 0)
speechEncoder.setBuffer(speechOutput, offset: 0, index: 1)
speechEncoder.dispatchThreads(MTLSize(width: samples.count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: samples.count, height: 1, depth: 1))
speechEncoder.endEncoding(); speechCommand.commit(); speechCommand.waitUntilCompleted()
precondition(speechCommand.status == .completed)
let speechResult = speechOutput.contents().bindMemory(to: SIMD4<Float>.self, capacity: samples.count * 3)
for (i, sample) in samples.enumerated() {
    let rest = speechResult[i * 3], open = speechResult[i * 3 + 1], rounded = speechResult[i * 3 + 2]
    precondition(simd_length(rest) < 0.000001, "Speech rest pose drift")
    precondition(simd_length(open) < 0.04 && simd_length(rounded) < 0.04, "Unbounded facial motion")
    if sample.name == "eyelid" || sample.name == "forehead" {
        precondition(simd_length(rounded) < 0.000001, "Speech must not displace \(sample.name)")
    }
    if sample.name == "lowerLip" || sample.name == "chin" {
        precondition(open.z < -0.004, "\(sample.name) must follow the opening jaw")
    }
    if sample.name == "lowerLip" {
        precondition(rounded.y < open.y - 0.001, "Rounded vowels must protrude the lips")
    }
}
print("PASS: production facial Metal on GPU with generated mesh samples — jaw/lip opening, rounding, fixed eyes/brow, bounded/rest poses")
