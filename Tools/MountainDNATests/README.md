# Field-generated meditation worlds — visual generator v4

`MountainWorldDNA` now selects among six candidates per arrival. Thirty-two genes
control morphology, cavities, branching, curvature, proportions, spatial density,
plant shape, palette and camera framing. There are no named-biome scene templates.
The candidate critic samples a cheap cross-section of the actual implicit field,
scoring occupied/empty space and silhouette readability, plus distance from the
last three selected genomes within a chapter. This is a heuristic, not an AI art
judge or a guarantee that every generated composition is beautiful.

Reconstruction is deterministic from seed, saved address and visual version. It
replays at most eight arrivals, so loading does not grow with journey length.
Novelty memory resets at eight-arrival chapter boundaries; hue follows a shared
lineage across chapters. The seven-place graph still supplies meditation/session
identities. Its place names do not select geometry. Existing progress is retained;
visual generator v4 intentionally changes the appearance of existing addresses.

## Geometry and rendering

`MountainFormField` combines a warped superellipsoid envelope, fused branches,
mineral folds and smooth cavity subtraction. Cavities can pierce a mass and open
its crown. Marching tetrahedra extracts a 3D surface with gradient normals, so
holes and overhangs are real geometry. The same field generates monumental forms
and smaller minerals; related curvature genes also shape branching fronds.

A heightfield provides a continuous, phase-varied path without a fixed guide ledge. Water is a static
stylized plane. Fifteen shared material batches use an intentional illustrative
Metal light model with mineral bands, rim light, colour harmony and depth haze.
This is not PBR, volumetric fog, reflected scene water or the generated concept
painting. No downloaded assets, generated images, backend calls or Blender
landscape models are involved. The existing Zen avatar loads only on entering meditation, floats 3.2 units above the terrain with a gentle nine-second bob, and disappears on leaving the session. Reduce Motion removes the bob. It is never visible during exploration.

During a normal nine-second transition, outgoing and incoming worlds coexist.
A spatial shader mask reveals their surfaces at different times with local mist;
the camera eases between their compositions and the sky interpolates. The old
world is removed at arrival. This is an artistic spatial dissolve, **not yet a
continuous traversable bridge or a topology-preserving geometric morph**. Reduce
Motion installs the new world without the moving camera or spatial dissolve.

## Resource limits and lifecycle

Only the current and one replacement world are retained. CPU meshing runs in a
cancellable detached task, checks cancellation between slabs/formations, and GPU
resources are submitted one material batch at a time. Geometry density decreases
with distance and economical mode. World/camera updates stop at arrival and
meditation; avatar animation and the subtle meditation hover remain separately managed. Inactivity stops scene
rendering and transition subscriptions while session time/audio remain separate.

An interrupted app restores the last committed arrival. The Debug “Nästa värld”
button still advances without registering a meditation or opening rewarded paths.
The region/session/store logic is unchanged by this visual experiment.

Physical iPhone 15 frame times, memory stability, energy and thermal behaviour
remain **unmeasured**. Host CPU timings and triangle budgets are not mobile FPS.
The two-world overlap and per-frame material updates need device profiling.

## Verification

```sh
swiftc -O Stilla/Models/MountainJourneyRecipe.swift \
  Stilla/Models/MountainRegionRecipe.swift Stilla/Models/MountainLandscapeMesh.swift \
  Stilla/Models/MountainWorldDNA.swift Tools/MountainDNATests/main.swift \
  -o /tmp/vindla-dna-tests
/tmp/vindla-dna-tests
```

Tests cover 700 reproducible distinct genomes, smooth paths and floating guide clearance, finite
vertices and unit normals, 33 mesh seeds at both quality levels below 250,000
triangles, lower economical geometry, structural cavity changes, 56 sampled
silhouettes, bounded fields, selected morphology novelty and very large addresses.

Debug launch: `--mountain-preview`. Optional `--mountain-world 17` overrides the
visual seed only. The image-generation concept is not an app asset or screenshot.

## Local time lighting

The live cycle reads device-local civil time every 30 seconds while active and
refreshes on activation/significant clock changes. It uses a stylized 06:00 dawn,
12:00 noon and 18:00 dusk: it is not geographic sunrise/sunset, a lunar ephemeris,
or a medical circadian-light treatment. No location permission or network is used.
The same hour drives sky/haze colours, moving sun/moon, night stars, landscape
shading and avatar light; controls adapt to dark surroundings. Terrain is not
regenerated when time changes, including during meditation.

The clock menu previews dawn/noon/dusk/night and returns to live time. A Debug
`--mountain-hour 0` launch argument previews midnight. Manual preview is transient.
Tests cover Stockholm local time/DST, midnight wrap, finite full-day colour/light
values, smooth path derivatives and constant avatar clearance.

Verified in Vindla Mountain QA: guide absent during exploration; silent meditation
loads the floating guide; stopping hides him again; midnight preview renders a
moonlit landscape/stars/dark controls, and switching to noon changes lighting
without generating another mesh. Debug build and DNA/path/clock tests pass.

## Winding paths and botanical variation (v4)

The path combines independently phased broad S-curves and slower secondary bends.
Amplitude and turn spacing vary by genome, with bounded derivatives and no fixed
foreground kink. Tests require both leftward and rightward travel within each
sampled visible path, as well as a smooth join through the foreground.

Each world derives five botanical genomes; their traits vary stem count, spread,
leaf width/taper/lobing/curl/droop, whorls, rosette habit, petal count, petal width,
cup depth and bloom layering. Species grow in spatial patches. Curved leaves and
petals carry sampled smooth normals; flowers have convex seed heads and related
accent/pale/centre colours. Blossoms are larger and closer to the path than the
previous five-triangle dots. The full plant canopy is checked against the path
before placement.

Flora is batched, with a separate capped geometry budget (65k normal / 22k low
power, further reduced for heavy terrain). Near specimens are attempted first,
with a reserved flower allocation. Distant leaves and petals have fewer segments.
Tests retain the 250k scene ceiling and validate 200 reproducible flora trait
combinations, nonempty flower meshes, finite normals and canopy clearance.
Device performance remains unmeasured.

Verified in Simulator: two consecutive worlds show different broad path bends,
curved flower heads and branching plants; the Next World transition returns to
interactive controls. Debug build and all generator tests pass.

Meditation framing now looks straight along the avatar’s +Z front, centred at
its scaled seated visual centre, from 7.5 world units. The camera remains fixed;
a 10-second vertical hover has amplitude 0.06 and is disabled by Reduce Motion.
Verified front-facing framing, full silhouette, and return to exploration in a
silent Simulator session; Debug build passes.

Clear daylight: the wild-world shader applies no settled fog when daylight is
fully active. The former altitude-based fog is removed; dusk/night distance haze
starts beyond 80 units. Transition mist remains transient. The full-width cream
foreground gradient is replaced with bounded control/header backgrounds. Noon
colours and text contrast were inspected in Simulator; Debug/Metal build passes.

Landscape tapping replaces the visible Next World button. A transparent semantic
button exposes the action to VoiceOver beneath the separate header/controls. It
is available only while idle, active, ready, without a setup sheet or transition;
the handler repeats that guard. The newly added header/control cards are removed,
with standalone text and a subtle text shadow instead. Debug build passes and
the card-free layout/accessible action were inspected in Simulator.

## Procedural valley surfaces (visual generator v5)

The old universal flat lake is replaced with `MountainFloorDNA`: water, dunes,
moss-like rolling ground or veined mineral ridges. Independent seeded traits
control relief, spacing, orientation, colour and water energy. About the calmest
28% of water variants have no waves; the rest have slowly animated wave normals
and crests. Water uses illustrative sky colour and sun glints, not scene-reflection
render targets, displaced fluid geometry or physics. Dry floors have real relief
and finite-difference normals (64x64 cells, 32x32 economical); water uses 8 triangles.
All surfaces share batch 6 and carry two constant genome attributes through UV0.

The GPU clock drives the water; there is no new CPU update loop. Reduce Motion
and economical quality disable the animated terms, including on both transitioning
worlds. Existing inactive-scene hiding and meditation generation suspension remain.

Debug/Metal build and DNA tests pass: 128 reproducible floor genomes cover all four
materials, 10 calm and 30 wavy water examples. Relief remains below the trail;
33 seeds in both detail modes retain the 250k geometry ceiling and valid normals.
The changed landscape was visually inspected in Simulator including night lighting.
Physical-device frame time and energy remain unmeasured.

World transitions now use a shared 3-second duration (previously 9 seconds) for
both mesh/camera blending and the sky colour transition. Generation time is
additional; Reduce Motion still skips travel. Debug build passes.

## Floating text contrast

Landscape-facing labels share `MountainWorldText`: warm white, regular-weight
lettering and a restrained soft shadow. The earlier hard contour was removed
because it made the interface feel too harsh. Broad, feathered dark gradients
behind the top and bottom text zones support contrast without panel edges or a
pale fog overlay. Increased Contrast strengthens shading and text weight. Action
text uses Dynamic Type body size; the scrollable control area expands for
accessibility sizes.

Debug build passes. The softer treatment was visually inspected in Simulator over
the generated landscape. No numeric contrast-ratio or complete Dynamic Type audit
is claimed for this visual check.

The avatar is now also present as a small camera-aligned guide above the icon dock;
see `../MountainRegionTests/README.md` for its placement and shared-renderer lifecycle.

Clock phase update: dusk now occurs at 19:00, with a 13-hour daytime and 11-hour
nighttime phase shared by Swift and Metal. Tests pass for 19:00 dusk, midnight,
and direction continuity across sunrise/sunset/midnight. The clock label has only
an icon and time; local-time following remains available in its menu.
