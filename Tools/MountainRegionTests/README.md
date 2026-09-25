# Dimmornas dal — Debug meditation region

**Visual renderer superseded:** see `../MountainDNATests/README.md` for the new
DNA landscapes. The tile/window geometry descriptions below refer to the first
region renderer; session/progression/storage behaviour and tests still apply.

Open **Ovan molnen** in a Debug build. Tap Guided meditation or Silent meditation
to start immediately. The adjacent duration menu offers 5–30 guided or 5–120
silent minutes in five-minute steps (10 by default). More options retains optional
intention and locally synthesized rain/brown noise. Each mode's duration, intention
and ambience persist separately in `mountain.prototype.meditation.preferences.v1`.
Talk to your guide currently opens a placeholder; no microphone or chat is started.
Guided content comes exclusively from `LocalGenerationFixtures`; no generation
request, microphone, purchase, or AI-credit operation is on this path.

A completed meditation unlocks both outgoing paths permanently. An early stop
records the elapsed meditation through the existing manager without unlocking a
path. Previous discoveries are preserved in storage; revisit/branch controls have been
removed from this UI. Tap the landscape to explore the next DNA world.
Reduce Motion removes travel animation and avatar motion.

## Architecture

- `MountainRegionRecipe`: seven stable places, eight edges, versioned seeded
  terrain, flat guide areas and shared path/prop exclusion rules. Coordinates are
  local to each region, including distant region numbers.
- `MountainJourneyProgress` / `MountainJourneyStore`: completed sessions, current
  arrival, discovered places and opened edges. Stored independently under
  `mountainJourney.region.preview.v1`. No migration or deletion of old saves.
  Unreadable or unsupported-version data is preserved and navigation disabled.
- `MountainSessionContext`: in-memory session UUID, place address, mode, duration
  and monotonic start time. `MeditationManager` owns audio, timer, history and
  completion. Relaunch never resumes/credits an interrupted session. App activation
  reconciles elapsed time after suspension. Generic reflection and Borobudur
  completion flows are excluded for mountain sessions.
- `ZenAvatarController`: shared model loader, breathing, shader deformation and
  speech-driven face animation used by both the portrait and world. The world has
  one ARView. A failed model load displays the existing portrait above the world.
- Scene: 25 resident 32-metre tiles, with at most 50 during long revisits. Reuses
  overlapping tiles; new CPU batches are generated off the main actor, GPU meshes
  submitted one material batch at a time. Near/middle/silhouette LODs share exact
  2-metre border samples. World generation and camera callbacks stop at meditation;
  inactive scenes are hidden and pending generation/callbacks cancelled.
- Low Power / serious or critical thermal state reduces terrain detail at the next
  idle rebuild and avatar submissions to 15 Hz. Normal avatar/camera submissions
  are capped at 30 Hz. RealityKit's actual render cadence and energy use require
  device profiling; this is not a claim that the display itself is capped to 30 Hz.

## Automated model, geometry and persistence tests

```sh
swiftc -O Stilla/Models/MountainJourneyRecipe.swift \
  Stilla/Models/MountainRegionRecipe.swift \
  Stilla/Services/MountainJourneyStore.swift \
  Stilla/Models/MountainLandscapeMesh.swift \
  Tools/MountainRegionTests/main.swift -o /tmp/vindla-region-tests
/tmp/vindla-region-tests
```

Checks all four branch combinations, five stops per route, both rejoins, alternative
branch revisits, new regions, early stop, wrong-location completion, duplicate
completion, restored state, corruption preservation, old-save isolation, monotonic
time, guide clearances over five seeds/three regions, repeatable meshes, finite
normals and matching mixed-LOD boundaries. Sample tested tile budgets: 17,998 /
4,008 / 953 triangles at near / middle / silhouette detail.

The previous linear generator remains available to its standalone tests. Add
`Stilla/Models/MountainRegionRecipe.swift` to that test's compilation because the
mesh file now also contains the region builder.

## Simulator and physical acceptance

Debug launch arguments:

```
--mountain-preview
--mountain-test-short-session
```

The second argument explicitly shortens only mountain sessions to eight seconds;
never use it for timing, battery or long-session measurements. The entry point,
mock session starter and short-session override are excluded from Release.

Physical iPhone 15 acceptance remains **unmeasured**: no available physical iPhone
15 was connected. Profile walking and a 30-minute session (two consecutive
20 + 10 minute sessions, or a dedicated profiling harness) with Instruments:
frame-time distribution, allocations/memory plateau over repeated transitions,
Energy Log and thermal state. Simulator timings cannot establish these properties.
Also perform a listening/VoiceOver pass on a real device before shipping.

No production publishing is part of this prototype.

### Verification recorded 2026-09-25

- Pure Swift region/geometry/store tests: PASS; legacy landscape tests: PASS.
- Debug simulator build/run: PASS. Release compile: PASS. Existing unrelated
  AppAttest concurrency and meditation notification/Live Activity warnings remain.
- iPhone 15 simulator, iOS 26.3: guide seated in the world, physical branch travel,
  silent completion/unlock, guided local recorded voice, early-stop/no-unlock,
  saved arrival after relaunch and largest Dynamic Type rendering checked.
- An ordinary ten-minute guided session was locked, then force-terminated and
  relaunched. Persisted current place, completed places and credited session count
  were unchanged. The monotonic clock/resume arithmetic is covered in unit tests;
  a complete locked-to-unlocked end-of-session UI pass remains for device QA.
- Accessibility labels, headings and timer value appear in the native accessibility
  tree. Full spoken VoiceOver navigation and physical-device lip-sync listening
  validation remain pending.
- Physical frame times, memory/energy/thermal measurements and the 30-minute run:
  **NOT MEASURED**. A fixed tile count is an implementation bound, not proof of an
  allocation plateau on a physical device.

## Quick-choice verification

Simulator verified: three choices without revisit links; guided 30-minute direct
start; silent 120-minute direct start; both durations survive app termination and
relaunch independently; stop/return works; the conversation option shows only an
informational placeholder. Automated region tests cover mode ranges, preference
round-trip/defaults/range correction and two-hour elapsed timing. No full two-hour
physical-device session has been measured.

## Minimal icon dock (current UI)

The home choices are now Meditate / Sleep / Talk icon buttons with text labels.
Meditate opens a compact sheet containing guided/silent mode, saved duration and
Start; intention and ambience are under More options. The selected mode is also
saved under `mountain.prototype.meditation.lastMode.v1`. The same existing per-mode
preferences remain intact. Sleep opens the existing `SleepStoriesExperienceView`;
if that flow starts an ordinary session, the mountain cover dismisses so the
existing app player owns playback. No new story generation flow was added.
Talk remains an informational placeholder.

The single shared 3D avatar is shown above the icons. Its measured SwiftUI slot is
projected into the existing RealityKit camera, with subtle vertical hovering. In
meditation it reparents to the world anchor for the larger centred front view.
Reduce Motion stops hovering; inactive/sleep-sheet rendering is hidden. A portrait
is used in the same slot if model loading fails. The timer/action area is placed
lower during sessions so it clears the avatar.

Simulator verified: visible docked guide and three icons, saved 30-minute chooser,
meditation start with larger front-view guide, stop/return to dock, and opening the
existing sleep-story selection screen. Debug build and all six localisation files
validate. No sleep story was generated or purchased during verification.

## Guide picker and later dusk

The guide slot is raised and a 44-point Change guide action opens a horizontal
paged picker containing the eight existing Kai personalities. Selection is saved
separately under `mountain.prototype.guide.v1` and passed into local guided-script
metadata. Zen retains the shared animated 3D model; other personalities use their
existing portrait artwork in the dock/session. This does not create new 3D models
or new persona-specific voice recordings. Guide changes are disabled in sessions.

The clock label now contains only its icon and HH:mm. A continuous 13-hour day
(06–19) and 11-hour night phase map is shared by Swift lighting and the Metal
shader; the dusk preset is 19:00 and midnight remains 00:00. Automated DNA tests
cover the new dusk, midnight and continuous light across phase boundaries.
Debug build and six localisation files validate. The higher guide, clean clock
and paged gallery were visually inspected in Simulator.

## Direct return after meditation

The mountain view no longer renders a completion/thank-you interstitial. Once the
manager reaches complete, a scoped view observer resets only that finished mountain
session and reveals the guide with Meditate / Sleep / Talk at the same location.
The existing finish path persists history and eligible progression before the view
reset; an early stop still does not unlock paths. Other app completion screens are
unchanged.

Debug build passes. A timer-shortened Simulator session reached its natural end
and returned directly to the same world's guide and enabled three-action dock.
The app was relaunched with the ordinary timer afterward. The early-stop path uses
the same completion observer; no separate completion button remains in the view.
