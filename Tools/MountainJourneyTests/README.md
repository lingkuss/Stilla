# Above the clouds — legacy linear landscape prototype

The Debug app now opens the region prototype documented in
`../MountainRegionTests/README.md`. This document describes the preserved v2
generator and its standalone regression tests.

Open **Ovan molnen / Above the clouds** on the app's home screen. **Walk on**
generates the next stretch of the path and moves the camera over 5.5 seconds.
**Stay here** hides the reading and navigation controls. The camera is stationary
at rest. Closing and returning restores the last completed arrival.

This is an exploration prototype. Walking does not award meditation progress,
change the destination catalog, or start audio/timers. The existing Borobudur
journey remains independent.

## Structure

- `MountainJourneyRecipe`: version-2 deterministic path, rising terrain and seeded
  environment recipes. Double global distances, Float local meshes.
- `MountainLandscapeMesh`: pure Swift terrain, props, architecture and streamed
  side peaks, batched by material and tested without a simulator.
- `MountainJourneyScene`: RealityKit non-AR scene, compatible with the app's iOS 17
  target. CPU geometry is prepared in detached tasks and submitted in material
  batches. No Blender, downloaded assets, AI service, or external textures.
- `MountainAtmosphere.metal`: illustrative directional shading and distance/height
  haze. Uses the emissive output required by RealityKit's custom unlit model.
- `MountainJourneyView`: SwiftUI exploration UI, Swedish/English copy, local
  persistence and Reduce Motion support.

The six resident chunks cover two stages behind and three ahead. One extra chunk
can exist during a transition; obsolete chunks are released on arrival. Rebasing
keeps geometry near the origin. The distant mountain backdrop follows the focal
point so rebasing cannot introduce a background jump. No frame-update subscription
is retained after arrival or while inactive. RealityKit itself may continue drawing
while visible; physical-device energy profiling is still needed.

Six environment families are shuffled in seeded chapters: pine clearing, moss
garden, golden grove, open ridge, waterfall and temple garden. Adjacent arrivals
never repeat a family, including across chapter boundaries. Every place also has
its own ridge width, cliff relief, path bends, tree density, palette and landmark
scale. Terrain parameters blend continuously between arrivals. The waterfall has
a carved side channel, with the walkable ridge kept clear. Streamed side peaks
change the nearer horizon as the user travels.

Details include plants and flowers, moss-topped rocks, leaf scatter, lily pads,
stone cairns, timber decks, benches, lanterns, paved courtyards and gateways.
Landmark clear zones keep random props out of the path and arrival compositions.
Water has static ripple highlights; this version does not simulate fluid motion
or weather. A repeated biome receives a new recipe, not a new art asset.

The generator is deterministic: reopening an arrival rebuilds the same scene.
The v2 preview preserves the arrival number from v1 on first use, but the visual
world changes to the new recipe. Meditation progress remains separate.

## Verification

From the repository root:

```sh
swiftc -O Stilla/Models/MountainJourneyRecipe.swift Stilla/Models/MountainRegionRecipe.swift Stilla/Models/MountainLandscapeMesh.swift Tools/MountainJourneyTests/main.swift -o /tmp/vindla-mountain-tests
/tmp/vindla-mountain-tests
```

Checks monotonic ascent, support beneath the path, deterministic variation,
matching generated mesh boundaries and seamless rebasing up to stage 1,000,000.
Also checks nonrepeating neighbors across 1,260 arrivals, all six families per
chapter, finite positions/unit normals, repeatable geometry and a 40,000-triangle
ceiling per chunk. The initial six chunks are about 9,200–17,100 triangles each.

Build the `Vindla` scheme in `Vindla.xcodeproj`. Debug launch arguments:

```text
--mountain-preview --mountain-stage 2
```

Add `--mountain-rest` to inspect a stationary landscape without the travel controls.
Omit `--mountain-stage` to test restoration of saved progress. State is stored
under `mountainJourney.preview.stage.v2`, separate from meditation progress.
Debug arrival logs include stage and resident-chunk count.

Validated on iOS 26.3 Simulator: initial render, repeated generated arrivals beyond
the initial place families, six-chunk retention, entering the quiet view and restoring
the saved stage after terminating and relaunching the app. Physical
iPhone frame rate, thermal behavior and battery usage remain unmeasured.
