# Stillness garden

Every 10 completed meditations earns a flower; every 25 earns a crystal; every
100 earns a life tree. Milestones overlap: 100 completions = 10 flowers, four
crystals and one tree. Timed sessions must
reach their end; explicitly ending an open-ended session after positive practice
time counts as completion. Stopping a timed session early or playing a sleep story
does not earn anything. Silent, guided, shared, destination and mountain sessions
all use the same completion hook in `MeditationManager`.

The `vindla.stillnessGarden.v1` UserDefaults record saves session UUID, independent
64-bit DNA and earning date. Replaying a UUID is idempotent, including after a
restart. Seeds are collision-checked; crystal and tree DNA use separate salts. Storage
version 1 is independent of geometry revision 4, so the original completion ledger
remains readable under the new cadence. Existing saved practice is never erased.
A deterministic shuffle bag, seeded from each personal completion, presents every
family before repeating one and prevents consecutive repeats across bags. Later
completions cannot change earlier specimens. The storage version is validated before loading. Corrupt/unknown-version
data is preserved rather than overwritten. Legacy history records duration totals,
not a reliable count of completed sessions, so there is no guessed backfill.

The collection is available from the flower icon in the home header and the
mountain world's header. The mountain world remains in the project's existing
Debug preview. English, Swedish, Danish, Norwegian, Spanish and French strings
include empty states, the reward rules, specimen names and short poems.
The presenting view supplies the close action: home clears its sheet flag,
the mountain clears its setup sheet, and the standalone garden preview returns
to the real home screen. Closing never changes the completion ledger.

## Rendering and resource bounds

One deterministic indexed mesh generator serves both viewers. Flowers have six
morphologies: layered rosettes, open cosmos, recurved lilies, hanging bells,
bilateral orchids and branching umbels. DNA varies stem growth, basal/alternating
leaves, leaf shape, lobes, branching, petal count, ruffles, layering, cup depth,
asymmetry, tilt, veins and coordinated throat/edge palettes. Crystals now use six
broad growth habits: prismatic, acicular, intergrowth, tabular, druse and isometric.
The original six DNA buckets stay in the same order, preserving existing seeds.
Inside each habit, independent genes vary abundance, aspect ratio, unequal face
areas, growth axes, terminations at one/both ends, head overgrowth, attached
secondary crystals, flat versus radial blades, and cubic/octahedral truncation.
Convex half-space clipping keeps the faces genuinely planar with outward normals.
Some specimens have opaque host rock or sparse golden needle inclusions. One
additional opaque material draws these before the translucent crystal volume.
Life trees
have umbrella, weeping, windswept and spire growth, with tapered branches, roots,
phyllotaxis and personal leaf palettes.
Geometry revision 4 joins the stem and 5–7 roots into a single closed skin.
Shared collar vertices form the root flare, with no buried root tubes or caps
inside the translucent trunk. Root length, angle, thickness, sideways bends and
vertical undulation vary independently with DNA. Roots taper from the flared
base into longer tips. Shared normals smooth the junctions; both detail levels
sample the same paths with fixed row/side limits. The canopy and saved DNA stay
unchanged.
Petals use smooth sampled normals and soft baked two-sided portrait lighting;
crystals use flat facet normals and a translucent optical material. A shared
512×256 studio map supplies one reflected and three refracted wavelength samples,
with Fresnel edges and approximate colour absorption through thicker regions.
Eight mineral-inspired palettes add axial colour zones, neutral smoky absorption,
subtle cloudy veils and highlight striations. DNA varies refractive index,
dispersion and density. Revision 3 deliberately updates the rendered crystals;
saved completion IDs, DNA, reward counts and dates are unchanged.
This approximates glass; it does not ray-trace the scene or project
physical caustics. Two-layer transparency bounds the rendering work. Intersecting
clusters are an artistic approximation, not a full volumetric optical simulation.
Optics has its own portrait cache revision, independent of geometry and storage.
Optics revision 3 is a botanical translucency trial: flowers and life trees now
share the same studio reflection/dispersion map. Their original vertex pigments
remain the dominant colour, with a small saturation compensation for the pale
background. Flowers are slightly more translucent than trees; dark stems and
bark retain more opacity. Geometry and DNA do not change. The botanical branch
skips mineral zoning/veiling, uses the same four bounded texture samples and one
two-sided material, and adds no particles, render targets or per-frame CPU work.
Static portraits and the existing idle-rotation/Low Power limits still apply.
These are stylized mineral specimens, not a scientific crystallography simulator.
References: [NHMU on fluorite forms, phantoms and inclusions](https://nhmu.utah.edu/articles/what-is-fluorite)
and [GIA on growth zoning in quartz](https://www.gia.edu/gems-gemology/fall-2017-gemnews-multi-color-zoned-quartz-brazil).

Earned flowers, crystals and life trees are currently shown only in the collection.
The mountain scene receives an empty specimen list and skips reward mesh generation
and GPU uploads entirely, including after new rewards are earned. Its ordinary
landscape trees remain. Collection data, earning rules and the mock profile persist.

The retained world generator can batch earned geometry into at most three extra
draws if re-enabled later. At most 128 flowers, 12 crystals and four
trees are considered (48, six and two in economical mode); rare landmarks and
newest specimens receive priority. The
combined terrain + reward budget is capped at 248,000 triangles. Garden geometry
is limited to 70,000 triangles, or 28,000 in economical mode. All specimens remain
available in the collection. New rewards prefer visible ground beside the path;
older ones continue along the route. Reward updates do not rebuild the landscape.

The lazy collection uses 360×420 snapshots, a serial background renderer and a
60-item/24 MB image cache. Offscreen cells release their images. Only the detail
screen creates an interactive SCNView. Flowers, crystals and life trees turn once every 90 seconds
at 30 fps (15 in Low Power/thermal economy mode), exposing the changing optical
reflections. Dragging or pinching pauses the turn; it resumes after two seconds.
Manual orbit and automatic yaw use separate nodes, preserving the current angle.
Motion stops when the detail/preview is offscreen or the app is inactive, and
respects Reduce Motion. Reduced-motion views render only on changes.
The scene and actions are released when dismantled. One specimen is loaded at a
time, with cancelled tasks on replacement. Low Power/thermal state caps direct
interaction at 30 fps (otherwise 60). Reset also resets the automatic angle.
The mountain renderer is hidden and paused while the collection is presented.
Memory warnings clear the portrait cache. No network or generated raster assets
are used. See Apple's [on-demand rendering documentation](https://developer.apple.com/documentation/scenekit/scnview/renderscontinuously).

## Automated checks

From the repository root:

```sh
swiftc -D DEBUG -O -parse-as-library \
  Stilla/Models/MountainJourneyRecipe.swift \
  Stilla/Models/MountainRegionRecipe.swift \
  Stilla/Models/MountainLandscapeMesh.swift \
  Stilla/Models/MountainWorldDNA.swift \
  Stilla/Models/StillnessGarden.swift \
  Stilla/Models/GardenGeometry.swift \
  Stilla/Models/GardenFlowers.swift \
  Stilla/Models/GardenCrystals.swift \
  Stilla/Models/GardenTrees.swift \
  Stilla/Services/StillnessGardenStore.swift \
  Tools/StillnessGardenTests/main.swift -o /tmp/vindla-garden-tests
/tmp/vindla-garden-tests
```

Checks cover every count 0–201, overlapping 10/25/100 milestones and progress,
cancellation and sleep exclusion, open-ended completion, restart/replay
deduplication, stable earlier DNA, nonrepeating discovery cycles, v1 ledger
compatibility, 576 repeatable distinct shapes/palettes covering all 16 families,
finite indexed geometry/unit normals, 1,000-completion collection bounds,
mineral material/UV alignment, within-habit silhouette diversity, grounded bases,
48 convex growth volumes with outward faces satisfying every clipping plane,
64 connected stem/root systems at both detail levels with closed oriented edges,
positive enclosed volume, no detached inner shells, and bounded extended roots,
zero/small/large mesh budgets, flower-free scenery, portrait framing across 64
worlds, and corrupt/future data preservation. Portraits remain below 18,000
triangles and world specimens below 2,500 in the tested corpus. The existing
MountainDNATests also verify the flower-free base landscape.

## Simulator review

- `--garden-preview --garden-count 100`: isolated collection fixture.
- `--garden-preview --garden-count 0`: empty state.
- `--garden-preview --garden-count 100 --garden-atlas`: export one specimen from
  every family through the actual portrait renderer to `Documents/GardenReview`.
  Also exports each family as an RGBA PNG at three viewing angles. The optical
  review checks visible and translucent pixels in the 48 images, different
  rotated views, and the SceneKit runtime log for shader/pipeline errors.
  `crystal-variation.png` compares four different seeds within each growth habit
  (24 actual rendered specimens). The individual RGBA variants allow automated
  visible/translucent-pixel checks. The 192-seed crystal corpus stays below 3,600
  portrait triangles; this is a sampled bound, not a physical-device FPS claim.
- `--garden-mock-count 300`: explicitly replace the local garden with a persistent
  300-completion test ledger (30 flowers, 12 crystals, three trees). Debug only.
  The original ledger is backed up once under `vindla.stillnessGarden.v1.beforeMock`
  and exported to `Documents/GardenProfileBeforeMock.json` before replacement.
  A timestamped receipt in `Documents/GardenTestProfileReceipt.json` reports the
  applied counts. This does not alter HealthKit, meditation history or account data.
- `--garden-restore-profile`: restore the exact backed-up garden ledger, then
  remove the mock marker. Subsequent mocks back up the newly current real ledger.
- `--mountain-preview --garden-world-count 300 --mountain-hour 12`: isolated
  collection fixture accessible from the mountain. Rewards remain absent from
  the landscape. This does not award practice or change the real garden.
- `--mountain-preview --mountain-test-short-session`: existing eight-second Debug
  meditation harness, exercising real completion and persistence in the QA app.

The simulator review covers the 100-meditation collection (10/4/1), the larger
1,000-meditation collection, the new progress and rules, family contact sheets,
3D orbit/reset and the rare tree in the world. Debug and Release builds are part
of verification. Existing AppAttest/concurrency and Live Activity warnings are
outside this feature. The original completion hook was also exercised with a full
eight-second silent meditation, an aborted session and a relaunch before this
cadence revision; the revised cadence is checked exhaustively by the ledger tests.

Host geometry measurements are CPU timings, not phone frame times. Physical
phone FPS, energy, memory pressure and thermal behaviour have not been measured.
