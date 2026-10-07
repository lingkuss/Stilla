import Foundation
import simd

// Include MountainLandscapeMesh.swift when compiling this test executable.
let recipe = MountainJourneyRecipe(seed: 0x56494E444C41)
let other = MountainJourneyRecipe(seed: 42)

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

for stage in [0, 1, 2, 3, 100, 10_000, 1_000_000] {
    let start = Double(stage) * MountainJourneyRecipe.stageLength
    var previous = recipe.elevation(at: start)
    for step in 1...240 {
        let distance = start + Double(step) / 10
        let current = recipe.elevation(at: distance)
        expect(current >= previous, "The path must not descend")
        previous = current
        // The full width of the path lies on the flat, supported ridge.
        expect(abs(recipe.surface(at: distance, lateral: 0.83) - current) < 0.0001,
               "Path edge is unsupported")
    }
    expect(abs(previous - recipe.elevation(at: start) - 5.4) < 0.00001, "Stage ascent changed")
    // Rebase without shifting the relative camera-to-world placement.
    let distance = start + 13.7
    let old = recipe.point(at: distance, lateral: 5, originStage: stage)
    let new = recipe.point(at: distance, lateral: 5, originStage: stage + 1)
    expect(simd_distance(old + [0,-5.4,24], new) < 0.0001, "Origin shift causes a visible pop")
    expect(abs(new.z) < 24 && abs(new.y) < 20, "Far journey is losing local precision")
    let variation = recipe.variation(stage: stage, salt: 10)
    expect(variation >= 0 && variation <= 1, "Variation out of bounds")
    expect(variation == recipe.variation(stage: stage, salt: 10), "Seed is not deterministic")
    // Every shared terrain boundary is evaluated from the same distance.
    let endOfChunk = start - 9 + 24
    let startOfNext = Double(stage + 1) * MountainJourneyRecipe.stageLength - 9
    for lateral in stride(from: -36.0, through: 36.0, by: 1.8) {
        expect(recipe.point(at: endOfChunk, lateral: lateral, originStage: stage)
            == recipe.point(at: startOfNext, lateral: lateral, originStage: stage), "Crack between chunks")
    }
}
expect(recipe.pathX(at: 53) != other.pathX(at: 53), "Different seeds must vary the path")
for stage in -60..<1200 {
    expect(recipe.biome(stage: stage) != recipe.biome(stage: stage + 1), "Adjacent biomes repeat")
    expect(recipe.place(stage: stage) == recipe.place(stage: stage), "Place is not repeatable")
    if stage % 6 == 0 {
        let chapter = Set((stage..<(stage+6)).map { recipe.biome(stage: $0) })
        expect(chapter.count == 6, "A chapter lost an environment family")
    }
}
var meshes: [[MountainMeshBatch]] = []
for stage in 0..<6 {
    let mesh = MountainMeshBuilder.chunk(recipe: recipe, stage: stage, origin: 0)
    let duplicate = MountainMeshBuilder.chunk(recipe: recipe, stage: stage, origin: 0)
    expect(mesh.count == MountainMeshBuilder.colors.count, "Material/batch mismatch")
    let triangles = mesh.reduce(0) { $0 + $1.positions.count / 3 }
    expect(triangles < 40_000, "Chunk exceeded geometry budget")
    for (index, batch) in mesh.enumerated() {
        expect(batch.positions == duplicate[index].positions, "Revisit changes geometry")
        expect(batch.normals.count == batch.positions.count, "Missing normals")
        expect(batch.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }, "Non-finite geometry")
        expect(batch.normals.allSatisfy { abs(simd_length($0) - 1) < 0.001 }, "Invalid surface normals")
    }
    print("Stage \(stage): \(recipe.biome(stage: stage).rawValue), \(triangles) triangles")
    meshes.append(mesh)
}
for stage in 0..<5 {
    let boundary = Float(9 - (stage + 1) * 24)
    let a = Set(meshes[stage][0].positions.filter { $0.z == boundary })
    let b = Set(meshes[stage+1][0].positions.filter { $0.z == boundary })
    expect(a.count == 41 && a == b, "Actual terrain meshes have a seam")
}
let later = (6..<60).first { recipe.biome(stage: $0) == recipe.biome(stage: 0) }!
expect(recipe.place(stage: later) != recipe.place(stage: 0), "Same biome repeats the same recipe")
print("PASS: six environments, no adjacent repeats, stable geometry, finite normals, triangle budgets, seamless mesh boundaries, ascent and rebasing through stage 1,000,000")
