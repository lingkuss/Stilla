# Shared seated guide assets

Shadow Guide is a bundled USDZ avatar, not the portrait disc used by the other
unmodeled guides. It shares Zen’s seated scale, anatomical head, authored expression poses and
runtime animation controller. Eyelid/jaw channels are packed for its own shader. The original Zen model,
source scene, texture and shader data remain unchanged.

## Runtime contract

`GuideAvatarAsset` in `Stilla/Views/ZenAvatarView.swift` registers the personality
ID, USDZ resource, torso node and eyelid atlas. `GuideAvatarController` handles
loading, breathing, head motion, eyes, speech, Reduce Motion and cancellation.
The old `ZenAvatarController` name is an alias for existing Zen-only screens.

`MountainJourneyScene` creates one instance per supported guide lazily, reuses it
between dock, gallery and meditation, and runs only the visible controllers.
Guides share the existing RealityKit renderer. Portraits remain available during
gallery loading and after a failed model load. The pool is bounded by the model
registry (currently three guides); adding many future models should add eviction.

New seated models should keep these conventions:

- Approximately 1.68 m high, centred on X, feet/cushion at Y=0 after USD export,
  front facing +Z. The UI's shared visual centre is Y=0.84.
- `BreathPivot` for the body and `HeadPivot` for the head; accessory meshes such
  as hands and a held prop stay independent of the breathing torso surface.
- Author meshes in Blender's Z-up local coordinates, then export a Y-up stage.
  `zenTorso` uses those local coordinates; arbitrary different proportions need
  a new deformation profile, not merely another texture.
- Preserve `AnatomicalHead`, `EyeLeftPivot`, `EyeRightPivot`, the anatomical
  vertex positions and the registered face shader’s `displayColor` contract.
  Zen uses RGB speech vectors plus an eyelid atlas; Shadow and Serene use
  R/G for lid Z/Y and B for jaw Z. New anatomy needs its own motion data.
- Register the torso node and resource in `GuideAvatarAsset`, add the USDZ to the
  Xcode resource phase, and validate both loading/fallback and animation.

## Shadow Guide authoring

`create_shadow_guide.py` imports the head hierarchy from the editable Zen scene.
`avatar_mesh.py` supplies reusable closed shell geometry, portrait UV projection,
materials and studio renders. The new robe, hood, beard, hands, crossed legs and
cushion are separate volumetric meshes. `CrystalOrb` is a 3D sphere held in the
lap, with polished blue PBR material; it uses no refraction pass, physics or
extra dynamic light. Hood and beard follow the shared head pivot.

`ShadowGuide/portrait.png` is an original Imagegen reference generated from the
existing Shadow Guide identity and Zen's seated composition on 2026-09-25. The
original app portraits were preserved. The generated reference is packed in the
editable Blend source; the exported portrait texture is 1024 × 1024.
The shared head anatomy retains the CC0 provenance documented in
`../ZenAvatar/Source/PROVENANCE.md` and `MakeHuman-CC0.md`.

This follows the existing Zen **frontal character** approach: shaped geometry
and a projected illustration, with simplified unseen backs. It is suitable for
the current fixed frontal view and subtle motion, not free 360-degree inspection
or close-up facial acting. Painted shading and facial registration remain an
artistic approximation. A future orbit camera would require additional sculpting
and full wrapped textures for both guides.

Regenerate with Blender 4.5.9 LTS (from the repository root):

```sh
/path/to/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python-exit-code 1 --python Tools/GuideAvatars/create_shadow_guide.py
/path/to/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python-exit-code 1 --python Tools/GuideAvatars/validate_guides.py
```

Outputs: `Stilla/Resources/ShadowGuide.usdz`, editable
`ShadowGuide/ShadowGuide.blend`, front/angled renders and `asset-metrics.json`.

## Verification, 2026-09-25

- 66,016 triangles, 12 meshes, USDZ 5,960,535 bytes. Zen remains 60,580 triangles.
- Automated checks passed: preserved anatomical positions and speech attributes,
  required pivots, separate hands/prop, physical sphere radius, volumetric meshes,
  geometry/file budgets, Y-up export and ARKit USDZ compliance.
- Debug and Release simulator builds passed. Release was compile-only; Debug
  remains installed with local fixtures and ordinary session durations.
- Visually checked native rendering in the guide gallery and the dock after
  selection. Simulator session timer was observed with Shadow selected; precise
  Shadow-specific speech/blink visual calibration still merits a closer pass.
- Physical-device frame times, energy and thermal behaviour remain unmeasured.

## Stillness Guide / SereneGuide (2026-09-25)

Added as a ninth personality, provisionally named **Stillhetens guide** in Swedish.
Existing personalities and images were preserved. Her calm, grounded description,
traits, sample and four encouraging reflections are localized in all six languages.
The portrait fallback is bundled as `kai_serene_guide`; `GuideAvatarAsset.serene`
registers the USDZ in the same pool as Zen and Shadow.

The user supplied a seated female reference on 2026-09-25. Imagegen produced the
clean modeling reference in `SereneGuide/portrait.png`; it preserves her ivory
clothing, blonde waves, knee mudras, lotus posture and mala without the temple.
`reference.png` preserves the exact original user image for visual comparison.

After visual review, the first attempt's reused male head was replaced completely.
`extract_face_landmarks.py` measured 468 points locally from the clean portrait with
MediaPipe 0.10.21. The baked coordinates and triangle connectivity are saved in
`face-landmarks.json`, with the source image hash. MediaPipe inference and its model
are authoring tools only: neither is bundled with or run by Vindla. Upstream topology
is covered by the included `SereneGuide/MediaPipe-LICENSE.txt` (Apache 2.0).

`reference_face.py` builds her own shaped facial surface, refines it, extends the
forehead beneath the hairline and closes the rear. Projection is applied after
refinement to keep the nose, lips and chin registered to their own image locations.
The face retains the shared `AnatomicalHead`/`HeadPivot` interface. Its skull is
closed; the eyelid and lip apertures have independent motion and recessed eye
globes, oral cavity and dental arch. It does not import Zen’s facial shape.
The hair has a tapered, textured rear instead of a deep, plain extrusion. The hands
are individually traced; crossed feet now share the continuous body surface rather
than floating as an overlapping cutout. The neck extends behind the jaw and hair.

`sereneFace` decodes independent eyelid and jaw displacement from her own
anatomy. She opens her eyes during speech, blinks, and closes them for longer
silence. The shared controller keeps eye contact through short word gaps and
continues to use actual playback events/audio levels. Recorded speech is an
amplitude-driven approximation, not phoneme-accurate lip sync.

This remains a portrait-textured model intended for frontal presentation and small
head movements. It is not a full photogrammetric reconstruction: unseen surfaces
are simplified and painted lighting limits relighting fidelity. Do not use it for
arbitrary orbit-camera closeups without further modeling and wrapped textures.

Regenerate with Blender 4.5.9 LTS, using the commands above and
`--python Tools/GuideAvatars/create_serene_guide.py`. Then run
`validate_guides.py` and `review_serene_guide.py`. The latter saves repeatable
front/angled face closeups, so visual review does not rely on a tiny dock preview.

Final revised metrics: **61,914 triangles, seven meshes, one 1024px texture, USDZ
5,106,559 bytes**. Both guide validators pass, including source registration,
watertight face, bounded speech data, pivots, budgets and ARKit USDZ compliance.
Legacy breathing/speech and production Metal deformation checks pass. Debug builds
and native female gallery rendering were checked. Physical-device performance and
full facial acting remain unmeasured; no production publishing is included.


### Hair refinement (2026-09-25)

`serene_hair.py` replaces the coarse uniform shell with a crown shaped by ten
reference-directed flow curves. Broad lock volume blends continuously, avoiding
raised tube edges that read as dark cables. The roots are thinner, the rear tapers
into the head, and the face/neck coverage extends beneath the temple opening.
The outer contour is sampled at 2px intervals and fitted to warm foreground colour
in the unmodified reference image, reducing the green background fringe.
Twenty-four deterministic candidate flyaways are trimmed to the outer contour,
tapered, and anchored into the foundation. All hair is joined into the existing
`Hair` mesh under `HeadPivot`; no simulation or extra renderer is introduced.
The photo still supplies fine fibres and baked shading, with the frontal-camera
limitations described above. Final front/angled closeups, native guide-gallery
rendering, Debug build and both USDZ validators were checked.


### Clearer breathing (2026-09-25)

The common torso shader amplifies anatomical breath expansion by 1.8, with the
head's matching lift increased from 6 to 10.8 mm. The breathing rhythm and delayed
cloth ripple are unchanged. The existing lower-body mask still fixes the hands,
legs and cushion; Reduce Motion still resets the pose. Production GPU tests assert
visible bilateral rib expansion, chest/shoulder rise, exact resting pose and the
existing 60 mm deformation bound. CPU/GPU checks and the Debug build pass.


### Facial acting verification, first pass (2026-10-01)

- Serene: real lip/eye apertures, fitted eye globes, recessed curved mouth and
  dental arch. 65,354 triangles, 11 meshes, about 5.17 MB USDZ.
- Shadow: beard edge embedded into the jaw and bound to anatomical speech data;
  cavity/dental corners recessed. Eyelid vectors now travel directly on vertices
  instead of sampling the small legacy atlas near a nearly closed lid seam.
- Eye contact persists through gaps shorter than 0.9 seconds. A relaxed return
  to closed eyes follows longer silence or stop. Closed eye globes are hidden
  below 4% aperture to prevent sclera leaking through the resting lid seam.
- Debug-only close-up review: launch with `--guide-face-review serene_guide`
  (or `shadow_guide`) and `--zen-avatar-closeup`, then use **Play voice**. This
  uses the production controller and bundled introductions, with no AI calls.
- Validation: `validate_guides.py`, `Tools/ZenAvatarTests/run.sh`, and
  `swift Tools/GuideAvatars/verify_face_motion.swift`. The latter runs production
  Metal with sampled authored facial vertices and checks independent eye/jaw
  motion, exact rest, and bounded simultaneous expressions.
- Native simulator recordings are under `output/guide-face-review/`. Inspect
  speaking, blink and stop transitions in motion, not just static previews.
- These remain stylized portrait-textured avatars. Do not claim full human
  realism or phoneme-accurate recorded narration; close-up skin/eye shading and
  articulation still reveal the simplified rig. Physical-device review pending.

### Second facial pass: timed articulation and gaze (2026-10-01)

Shadow and Serene now use audio-derived, timed mouth shapes. Rhubarb 1.14.0
analyses recordings offline: English uses the authored dialogue and Swedish uses
its phonetic recognizer. We map the nine cue labels into restrained continuous
jaw, rounding, spreading and lower-lip-tuck controls. This follows the game
animation principle of separate facial channels and coarticulation; it is not a
MetaHuman or Audio2Face implementation. These simplified visemes are not full
phonetic facial capture (H currently shares an open articulation, without a tongue).

All 62 meditation passages for these two guides plus four English/Swedish
introductions have adjacent `.lipsync.json` files. Sampling uses the audio player's
actual position, including seeking, with 20 ms anticipation and shared smooth
windows at cue boundaries. A SHA-256 match binds each track to its exact recording.
Missing, invalid or stale tracks fall back to metered motion. Stop clears the pose;
old callbacks cannot update a replacement playback. No recognizer or AI requests
run in the app. After retaking audio, regenerate the corresponding sidecar:

```sh
python3 Tools/GuideAvatars/generate_lip_sync.py --rhubarb /path/to/rhubarb
sh Tools/GuideAvatars/check_faces.sh
```

The continuous eye shader fixes the conflicting iris/material alignment, uses
smaller pupils, upper-lid occlusion and restrained reflections. Rare, small shared
gaze changes retain forward attention. Blinks close quickly and reopen more slowly;
eye contact holds across gaps under 1.8 s before returning to meditation. Separate
curved enamel crowns replace the bright dental strip. Serene's chin participates
subtly in jaw motion. Model budgets remain 65,578 / 69,012 triangles (Serene/Shadow).

Checks cover all 66 tracks, audio hashes, duration, bounded curves, seamless
unequal-length cue boundaries, real AVAudioPlayer seek/stop/completion/stale-file
fallback, production GPU deformation and USDZ compliance. Actual simulator speech
captures and frame sheets live in `output/guide-face-review/v2`. The review launch
uses the same rendering controller, audio player and animation data as the world.
Add `--guide-face-review-language en` or `sv` to inspect a specific voice without
changing the app's saved language. Screen recordings contain video only.
The visual result is more articulated but still a stylized, portrait-textured
rig, especially in close-ups. It must not be described as verified photorealistic
human acting. Physical-device performance has not been measured for this pass.

References: [MetaHuman audio-driven animation](https://dev.epicgames.com/documentation/en-us/metahuman/audio-driven-animation)
and [Rhubarb mouth shapes and local analysis](https://github.com/DanielSWolf/rhubarb-lip-sync).
