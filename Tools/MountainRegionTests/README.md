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
  reconciles elapsed time after suspension. The generic reflection flow is excluded
  for mountain sessions.
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

### Immersive guide selection experiment (2026-09-25)

- Baseline checkpoint: `8cff153`, retained on `codex/checkpoint-before-guide-carousel`.
  Source, app assets, tools and existing website/marketing work are included; generated
  `output/` builds and captures stay outside Git. Experiment branch: `codex/mountain-guide-carousel`.
- “Byt guide” now opens an in-world horizontal gallery, without presenting a sheet.
  Guides occupy fixed positions relative to the captured landscape viewpoint; dragging
  moves the existing RealityKit camera laterally, with a small forward focus movement.
  One swipe visits one neighbour, arrows and an accessibility adjustable action also work.
- Zen reuses the single existing avatar controller/model. Other guides use round portrait
  meshes (shared geometry, cached 512px textures) in the same scene; they are not new 3D avatars.
  Texture creation yields between uploads, only nearby portraits render, and gallery
  resources are reused on reopening. Reduce Motion removes camera easing and hovering;
  inactive scenes stop updates. No worlds generate while browsing the guides.
- Selecting persists the guide and restores Meditera/Sova/Prata. Closing without selecting
  keeps the previous guide. World-tap navigation and meditation controls are hidden while browsing.
- Debug simulator build passed. Visually checked centred Zen with both neighbouring portraits,
  lateral scenery movement and other guides. Verified a swipe from guide 4 to guide 5,
  selecting/reopening guide 4, and cancelling guide 5 back to guide 4 with all three dock actions.
  Accessibility tree exposes labelled arrows, selection and adjustable gallery control.
- Physical-device performance, VoiceOver speech and accessibility-size layout remain unmeasured
  for this experiment. Existing AppAttest concurrency warnings are unrelated to this change.

### Guide reflections in the landscape header (2026-09-25)

Replaced the generated world title with one of 32 original, encouraging reflections
(four for each guide), localized in all six supported languages. Selection is derived
from the saved guide, world seed and sequential place address; it stays stable across
clock updates and changes at the next world. The guide gallery keeps its existing title.
The header wraps naturally and respects Reduce Motion for its text transition.

Debug simulator build passed; localization keys checked for completeness/duplicates.
Visually checked the two-line Swedish header. Simulator navigation changed Urban Sage's
“En paus kan vara dagens klokaste steg.” to “Ett litet steg räknas också.” at the next world.
No generation service or credits are involved.

### Controls during world changes (2026-09-25)

Removed the general `isMoving` lock from the dock and daylight menu. Only another
world-advance tap waits for the current transition. Opening a dock flow cancels any
unfinished mesh preparation; an already installed incoming mesh settles immediately.
The view reconciles its address with that stable arrival, and meditation setup uses
the store's current place, preserving session/progression validation. Generation stays
paused through setup, gallery, conversation notice and the session itself.

Debug build passed. Simulator checks: dock and clock remain enabled during travel;
opened meditation immediately after a world tap, started its normal silent timer
(19:59), stopped and returned to the dock; opened and closed the guide gallery during
another world change. No start error or stale-place rejection occurred.

### Shared 3D guide registry and Shadow Guide (2026-09-25)

The gallery, dock and meditation now use a bounded pool of shared avatar
controllers for Zen and Shadow. Portrait-backed guides retain their fallback.
See `../GuideAvatars/README.md` for source generation, model contracts, measured
asset budgets and verification details. The earlier `8cff153` checkpoint remains
unchanged and no new experiment commit was created.

### Female Stillness Guide (2026-09-25)

Added the user-reference female guide as the ninth personality, using the same
3D gallery/dock/session path. Localized profile and four reflections, cached USDZ,
portrait fallback, dedicated lip-height calibration and preserved shared eyelid
coordinates. Native dock rendering and the ninth guide's selected quote verified.
Debug/Release builds, both new USDZ validators, legacy GPU animation checks and
local session generation tests passed. See `../GuideAvatars/README.md`.


### Female likeness correction (2026-09-25)

Replaced the reused Zen head with a portrait-measured female facial surface.
Corrected hairline/neck coverage, tapered and textured the hair rear, retraced both
hands and joined crossed feet into the continuous body surface. Her own restrained
speech deformation keeps the eyes closed; Zen/Shadow retain their existing eye
animation. Both USDZ validations and legacy CPU/GPU avatar checks pass. Reviewed
large front/angled facial renders and native RealityKit guide gallery output.
Updated source/provenance and limitations are in `../GuideAvatars/README.md`.


### Mountain session audio (2026-10-01)

Ambience and breathing controls now appear before Begin in both modes. Volumes,
chimes and intention remain under More options. Explicit off choices and independent
mode preferences are preserved. The connected test phone had legacy None ambience
for both modes and no breathing setting; its existing Rain Ambience preference was
applied to both modes and breathing enabled at 50% using the explicit DEBUG launch
argument `--mountain-enable-test-audio`. This argument backs up only the prior
mountain settings to Documents/MountainAudioBeforeTest.json and does not change
meditation counts. Normal launches never override sound choices.

SoundEngine connects chime/breath nodes once, checks AVAudioEngine.isRunning when
starting playback, fixes the procedural source to its actual 44.1 kHz synthesis
rate, and applies cue volume on the breathing node so a playing loop can change
volume. Reselecting an ambience during fade-out restores its level.

Verification: Debug Simulator and optimized Debug iPhone builds passed; region
persistence/geometry tests and all 24 recorded-guide catalog checks passed. Through
the actual mountain setup UI, silent then guided sessions rendered nonzero rain,
breathing and mixed PCM continuously. Guided recordings started while both sound
layers continued, including roughly 40 seconds with the Simulator locked. Early
stop removed breathing and faded ambience. Use `--mountain-audio-diagnostics` to
repeat per-node two-second RMS checks; all taps are absent during normal use.
Installed and launched on the connected iPhone 13; read back preferences to confirm
Rain Ambience, breathing enabled and 50% volumes in both modes. Physical-speaker
listening and long-duration background/route-change testing were not measured.


### Toolbar and statistics cleanup (2026-10-01)

The mountain header now contains collection, breathing technique, sounds, settings
and daylight/time controls on one row. The previous statistics button and its
StatisticsView (charts, badges and helpers) have been removed. Meditation history,
timers, completion eligibility and the separate 10/25/100 garden ledger are retained.
Legacy toolbar shortcuts stay available in Release while the mountain remains a
Debug prototype; its breathing library permits preset selection for this preview.

Sounds opens one settings sheet with independent guided/silent choices, ambience,
breathing, start/end tones and volumes. These are the same saved settings consumed
by startMountainSession; no migration or preference reset is performed. General
settings omits its legacy audio controls in this context. Meditate now contains mode,
duration, start and (for guided sessions) optional intention, without sound controls.

The selected technique drives both the mountain avatar and the engine-owned PCM
cycle, including silence during holds. Shared phase durations validate finite input
and bound custom/restored values to the editor's 20-second maximum per phase.
This keeps one loop at most 80 seconds; no per-frame generation or scheduling was
added. Sounds, settings and technique sheets reuse the existing world and pause
world changes.

Verification: Debug Simulator, optimized Debug iPhone and Release Simulator builds
passed. Region/preferences, avatar/breathing and complete garden suites passed,
including 0–201 milestone counts, reload/deduplication, and the 300 = 30/12/3 fixture.
Simulator UI confirmed all toolbar routes, selecting/restoring box breathing,
independent guided pink noise versus silent rain, and the compact sound-free start
sheet. Rendered PCM confirms a 4/4/4/4 box cycle with silent holds while ambience
continues. Installed on the connected iPhone 13; auto-launch was refused because
the device was locked. No user settings or completion ledger were reset.


### Local time and compact header (2026-10-01)

Removed the clock/sun-moon menu and transient `--mountain-hour` override. Lighting
now always uses device-local time, refreshing every 30 seconds while active and
on foreground/significant clock changes. The scenery's day/night cycle is retained.
The four collection/technique/audio/settings icons form a compact group at the
upper right, with the reflection immediately beneath; Close remains at the left.
During meditation the icon row stays hidden, as before.

Debug Simulator build and existing DNA/local-time/DST/full-day lighting tests
passed. Native screenshot/accessibility inspection confirmed the icon group,
reflection below it and absence of clock controls at the current evening time.

### Restored sound image library (2026-10-01)

Mountain Sounds now opens the original two-column image library for ambience,
start and end tones. Each settings row also shows the current selection's image.
The shared picker accepts a selection binding so choices stay in the mountain's
independent guided/silent preferences. Legacy callers retain their purchase rules.

Mountain previews use one lazily created audio engine, the selected mix volumes,
and a five-second timer that also runs while scrolling. Choosing another card
stops the previous preview. Leaving the picker or backgrounding stops playback
and releases the preview engine without stopping the meditation engine.

Verified with Debug Simulator and optimized Debug iPhone builds, screenshots of
the restored ambience/tone grids, and taps through all three libraries. Rendered
PCM was nonzero for pink noise, Gentle Chime and Temple Bell; ambience and breathing
remained silent during tone-only previews. Output stopped after the preview period.
Saved preferences round-tripped guided pink noise/Gentle Chime/Temple Bell while
silent meditation retained rain/None/None. All six localization files pass plutil.
Installed the updated build on the connected iPhone without resetting preferences.

### Destination experience removed (2026-10-01)

The separate destination entry, views, catalog, background image, guidance content,
progress models, StoreKit catalog lookup and timer branches have been removed.
Startup clears only the retired destination progress and selection keys alongside
the retired weekly-plan keys. Mountain progress, audio choices, meditation history,
saved scripts and the collection ledger are preserved.

Debug and Release Simulator builds and the optimized Debug iPhone build passed.
The service/migration, mountain region and collection suites passed. The built
Simulator and iPhone bundles contain neither the retired catalog nor its image.
Native UI inspection confirmed the simplified home screen. Using the explicit
eight-second Simulator test clock, guided and silent mountain sessions completed
and each credited exactly one matching session in both mountain and collection
storage. Rendered PCM confirmed breathing and ambience playback and the guided
session's saved ending chime. Normal iPhone launches retain real durations.

### World as the default home — 2026-10-01

- The world is now the root idle view in Debug and Release; normal launches need no
  `--mountain-preview` flag. The retired `homeViewMode` preference cannot override it.
- Timer action joins the top-right world toolbar. The simple timer has a mountain
  action to return; there is no world close button. Guide selection retains its
  own back action. Navigation selection is in memory only.
- Switching to the timer dismantles the RealityKit scene, cancels pending world
  preparation, and stops guide previews. Only the bounded mesh cache remains.
- Active mountain sessions keep their scene; ordinary timer, saved/shared and sleep
  sessions route to the existing timer controls. Switching views is offered at idle.
- Bundled guides and narration are available in Release. Test duration overrides,
  reward fixtures, landscape preview travel, and free preview selection remain Debug-only.

Verified on Vindla Audio Library QA, iOS 26.3:
- Debug and Release builds and normal launches succeeded. World → timer → world
  worked, with no close button on the world and the existing quote under the icons.
- Release cold launch with the legacy `homeViewMode=timer` override still opened the world.
- Release guided session started with the real 10-minute countdown, and stopping it
  returned to the world. Simple timer start/stop retained its existing controls.
- Release guide selection and its back action returned to the world.
- `Tools/GuideMeditationTests/run.sh --recordings` passed all 24 practices and recordings.
- Optimized Debug device build succeeded; installed and launched on the connected
  iPhone 13 at 20:15 Stockholm time, without any preview or mock launch arguments.
- Localization plist validation and `git diff --check` passed. Existing unrelated
  concurrency/deprecation warnings remain.
