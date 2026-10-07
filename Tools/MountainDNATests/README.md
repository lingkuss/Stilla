# Procedural meditation worlds — visual generator v9

## Translucent scenery trial (2026-10-01)

Grass and small botanical shrubs are no longer generated or uploaded. Their
material batches (1, 3, 4, 5) stay empty in both quality modes; full trees, stones,
terrain and clouds remain. The 33-seed, two-detail suite asserts this alongside
the existing geometry, tree clearance and cloud placement checks. World DNA and
saved meditation progress do not change.

The near trees' pointed edge-leaf quads have also been removed. Their crowns now
use only the rounded lobes, avoiding thorn-like protrusions in the translucent
material. This change applies only to landscape trees; earned life trees in the
collection use their separate, unchanged generator. It removes 588 triangles per
accepted detailed landscape tree, with no additional rendering work.

The scenery now uses restrained alpha blending, pigment-preserving lighting,
Fresnel edges and approximate spectral refraction from an analytic sky. Mountain
terrain and the path retain 94–99% opacity; crowns and clouds transmit more light.
The sun and palette follow the existing local-time lighting. This is a stylized
glass treatment, not ray-traced refraction of objects behind each surface.
Transparent surfaces keep the existing material batches; there are no scene
captures, new textures, particles, shadow maps or CPU animation loops. Back faces
are culled for terrain, paths, clouds and rocks; botanical batches remain two-sided.

Low Power/thermal economy mode uses opaque materials with one analytical reflected
sky sample and skips the three refracted samples and alpha compositing. The lower
geometry budget and existing scene lifecycle remain. Debug `--mountain-economical`
forces this same quality path for review. Simulator imagery is saved under
`output/mountain-prism`. Physical phone FPS/energy remain unmeasured; fewer
triangles alone do not establish the cost of transparent full-screen scenery.

## Procedural sky clouds (v9, 2026-10-01)

The low cloud banks have been replaced by three smaller, separated clouds in the
upper sky. Their seeded lobes, scale, distance, height and lateral placement vary
per world. Each cloud checks terrain across its complete rotated extraction
footprint and is lifted above the highest sampled ground, with a 40-unit margin
below the extraction volume. Clouds remain world-space geometry as the meditation
camera travels beneath them. The distant terrain crest conceals the trail endpoint;
a cloud bank is no longer used to cover it.

The 33-seed, two-detail suite checks that cloud vertices and triangle centres stay
at least 30 units above terrain and that clouds do not obscure the distant trail.
The full generator suite and Debug build pass. Simulator inspection confirms sky
placement. Physical-device performance remains unmeasured. Earlier cloud-bank
and cloud-occlusion descriptions below record superseded visual iterations.

## Procedural flowering groves (v8, 2026-10-01)

Sparse trees now grow beside the meadow trail. Seeded height, lean, branching
phase, crown layers and flowering vary between specimens; curved tapered branches,
scalloped canopy lobes and small edge leaves are constructed as geometry. Nearby
trees have richer crowns and leaf sprays; distant/economical trees use fewer limbs
and lower tessellation. Four shared material batches carry bark, shaded jade,
sunlit sage and pale blossom. No models, textures, physics or generation during
meditation are added.

A candidate must stand above the valley floor on a gentle slope and stay clear of
neighboring trunks. Its **complete geometry AABB**, including every branch and
leaf, must clear the winding trail by 3.9 units at 1-unit longitudinal intervals.
The 0.4-unit allowance covers the path's bounded derivative between samples,
leaving at least 3.5 units of actual clearance. Rejected trees are omitted rather
than shifted away from their ground contact. Trees receive a bounded 19k/8.5k
triangle allowance within the existing total world budget; flowers use the
remaining allowance. Nearby meadow buds are rounder and have leaves, larger
flowers have cupped and gently recurved petals, and grass uses curved ribbons.

Debug/Metal build and the 33-seed, two-detail generator suite pass, including
checks that trees exist, normals are valid, branch/crown vertices and triangle
interiors stay clear of the path, and each world remains below 250k triangles.
The planted landscape is visually inspected in Simulator. Physical-device FPS,
energy and memory behavior remain unmeasured.

## Lavender mountain direction (2026-10-01)

The current implementation starts with the Lavender Mountains concept. Large
mountains now grow as overlapping rounded ridges in the **same continuous
heightfield** that supports the path. The former isolated, pierced monumental
forms are no longer placed in the landscape. The candidate heuristic samples
these actual ridge profiles at portrait-camera view bearings. It prefers an open
sky between layered shoulders, alongside deterministic genome novelty.

The path is wider, cream-colored and continuously uphill into a seeded cloud
bank. Ridge width and contours, distant shoulder positions, botanical traits and
flower distribution vary by genome. Palette roles remain coherent: lavender and
dusty rose flowers, sage leaves, warm stone trail and a blue sky. Near flowers use
rounded geometry in three extra shared material batches; distant flowering
meadows use slope-aware color fields in the terrain shader. Vegetation covers the
entire existing meditation camera route. Smaller rounded, grounded boulders
replace the foreground pierced minerals. Existing sessions, guide rendering,
local-time lighting and world transitions remain in place.

All scenery is generated locally; no image-generation service, new Blender
assets, textures or additional per-frame generation is required. Three meadow
pigments increase the maximum material slots from 15 to 18. Nearby geometry,
coarser distant terrain and the lower-detail mode retain the 250k triangle ceiling.
Version 7 changes regenerated scenery, but does not reset saved place/session IDs.

Verification: Debug Swift/Metal build succeeds. Generator tests cover 700 distinct
repeatable genomes, 33 seeds in both detail modes, unit normals, finite geometry,
trail seams/clearance, cloud occlusion, a hidden trail endpoint, meadow clearance
and coverage to the end of meditation travel, ridge-profile variation and bounded
meditation camera routes. Simulator views were inspected while refining the
mountain proportions, palette and flowers; transitions and an active meditation
were also observed. Two existing AppAttest concurrency warnings remain unrelated.

This is an **artistic real-time interpretation**, not the detailed concept render.
Clouds are still opaque stylized billow meshes, lighting is illustrative rather
than ray traced, and the forest/pearl-world concepts are not implemented here.
Physical iPhone 15 frame times, memory, energy and thermal behavior are unmeasured.
Host generation timings are not a mobile frame-rate measurement.

The sections below retain notes from earlier visual iterations; where they differ,
this v7 section describes the current terrain and material design.

---

## Earlier field-generated worlds — v4

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
12:00 noon and 19:00 dusk: it is not geographic sunrise/sunset, a lunar ephemeris,
or a medical circadian-light treatment. No location permission or network is used.
The same hour drives sky/haze colours, moving sun/moon, night stars, landscape
shading and avatar light; controls adapt to dark surroundings. Terrain is not
regenerated when time changes, including during meditation.

The world always follows local time. The clock display, sun/moon control, preset
menu and `--mountain-hour` override have been removed.
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
and direction continuity across sunrise/sunset/midnight. Local-time following is
now always enabled; there is no visible clock or manual time control.

## Softer terrain and uphill trail (visual generator v6)

The trail now climbs continuously with a seeded 9–17.5% longitudinal grade,
varying gradually along its length. Wider shoulders use a quintic blend and
lower-frequency, lower-amplitude relief. Monumental forms have rounder envelopes
and softer folds. The terrain grid follows the winding path without adding cells;
trail width is evaluated at shared vertices to eliminate segment-edge cracks.
Version 6 changes regenerated scenery, while saved journey identities remain intact.

Debug simulator build and generator tests pass: 700 repeatable genomes with uphill
paths and smooth shoulders, plus 33 mesh seeds at both quality levels with matching
trail seams and fewer than 250k triangles. This change has not yet been visually
reviewed in the running app or profiled on a physical device.

## Trail continuation toward the horizon

The trail and its supporting ridge now extend together to 2,400 world units
(previously the trail stopped at 108 and the terrain at 180). Shared longitudinal
samples prevent the trail from sinking into coarser distant terrain. Cell lengths
increase from 1/2 units near the viewer to 4, 8 and 20 in the distance. The mountain
broadens gradually, and its positive grade eases beyond 400 units into a rounded
crest that hides the finite endpoint. The camera far plane includes the continuation.
This adds no material batches, entities, animation loop or daylight fog.

Debug simulator build passes. Two generated worlds and the transition between them
were visually inspected. Tests pass for 700 genomes including positive distant
grade and terrain occlusion of the endpoint from the arrival camera; 33 mesh seeds
at both quality levels retain matching trail seams, supporting terrain, finite
geometry and the existing 250k triangle ceiling. Physical-device performance
remains unmeasured.

## Cloud destination, rock clearance and stronger distant colour

A seeded bank of smoothly joined cloud billows now meets the ascending trail
before the distant crest. It uses the existing implicit mesher and previously
unused material slot 11, with opaque depth-tested geometry and soft daylight/night
shading. These are stylized static clouds, not volumetric ray marching or a
screen-wide fog layer. Lower detail reduces their meshing resolution.

## Slow travel during meditation

Meditation now eases from the arrival view into a camera route along the actual
path. A forward look-ahead follows bends without camera roll. Duration scales a
bounded journey of roughly 139–300 world units across 5-minute to 2-hour sessions;
the first seconds accelerate gently. The existing mesh is reused throughout,
without world generation or extra geometry. Guides are attached to the same
RealityKit camera, front-facing at the existing meditation scale/distance with
subtle hover. Portrait fallback can still accompany the moving landscape.

Visual travel time advances only during active rendering and clamps frame stalls.
It is independent of session time, audio, completion and saved progression. Reduce
Motion skips the entrance and keeps the camera still; background rendering stays
suspended. Leaving a session returns to the exploration composition.

Debug build and generator tests pass. Camera tests sample 32 seeds at five durations
(including the short Debug session), checking clearance, bounded distance, speed
and smooth heading. A silent session was recorded in Simulator; frames confirm
changing scenery and a centred guide. Video: `output/meditation-path-flight.mp4`.
Background/resume and Reduce Motion are code-reviewed; a complete device lifecycle
and energy/performance run remains outstanding.

Each bank now also inherits bounded variation in width, height, depth, yaw and
placement from the world seed. Billows vary in asymmetry, spacing and roundness.
The centre bank stays over the ascending trail while the side banks vary more
freely. The same three banks and mesh resolutions keep the resource budget bounded;
the 33-seed, two-quality cloud-occlusion and geometry checks still pass.

Each generated rock formation is moved sideways as a whole until its complete
bounding volume clears the meandering trail over its full depth. Sampling margins
account for bends between samples. Large formations leave eight world units of
clearance; small minerals leave three. Shapes and overhangs are preserved.

The settled distant colour blend now starts beyond 180 units and is capped at
12% at night, versus the previous 65%; daylight still has no global distance fog.
Transient world-change mist is reduced from 45% to 10%. Landscape materials use
explicit opaque blending and surface opacity 1; the guide cutout stays transparent.

Debug/Metal builds and generator tests pass. Across 33 seeds in both quality modes,
rock vertices, edge midpoints and triangle centres clear the path, and a ray from
the arrival camera to the ascending trail intersects the cloud bank. All existing
geometry/normal checks and the 250k triangle ceiling pass. Daytime worlds and dusk
colour were inspected in Simulator while refining the clouds. Physical-device
performance remains unmeasured.

Mountain softening: rounder envelopes, less pinching and lower-frequency folds
give monumental forms gentler silhouettes. Wider smooth joins soften branches
and cavity rims; the path ridge has broader shoulders and quieter relief. Mineral
banding is less pronounced. No extra fog or mesh subdivision was added. Generator
tests still pass for novelty, rock clearance, cloud occlusion and triangle budgets;
the Debug build and daytime Simulator view were checked.

## Earned flowers and crystals

Decorative meadow flowers and botanical/tree blossoms have been removed from the
base landscape. They are now supplied exclusively by the persisted stillness
garden, with a shared total terrain/reward triangle budget and stable specimen
DNA. Base landscape tests now require empty blossom batches. See
`../StillnessGardenTests/README.md` for completion rules, viewer behaviour, resource
bounds and the separate collection/mesh checks.
