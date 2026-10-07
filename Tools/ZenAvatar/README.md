# Zen Minimalist: native session prototype

Open **Möt Zen Minimalist** at the top of Home, in Settings, or below the Zen
persona in the meditation creator. The separate SwiftUI screen suggests a
10-minute session. Type a wish, or use the microphone, then review the session
card and start it in Vindla's existing player.

Examples:

- `Jag vill sova` → sleep story, 20 minutes by default.
- `Ge mig en avslappnad sömnberättelse` → sleep story.
- `Jag vill meditera i tio minuter` → guided meditation, 10 minutes.
- `Jag vill ha en guidad meditation i 20 minuter` → guided meditation, 20 minutes.

Type/duration routing is deterministic, not a general language model. It handles
Swedish and English number words, numeric minutes, and common sleep/meditation
phrases. Requests outside 1–30 minutes are clamped and visibly explained on the
card. The complete input is retained for the production script generator.

## Local testing: no billable generation

**Every Debug build uses bundled example scripts**, in Simulator and on-device.
`KaiBrainService` compiles out both generation network branches in Debug:
meditation and sleep story. Requests return before any backend URL
or App Attest authorization is accessed. There is no switch or stored preference
that can silently turn generation back on. Local generation does not decrement
free credits. Script-related Pro gates allow local tests without changing any
StoreKit purchase state.

Mock meditation scripts select rest, stress or focus passages and scale the
pauses to the requested duration. The sleep fixture repeats quiet middle passages
to test longer narration; it is not a newly written, personalized story. Fixtures
are authored in Swedish and English (other app languages currently use the English
example script). The UI is localized in all six supported languages.

Debug Zen previews and the Swedish/English example meditation now use bundled
audio generated on this Mac; see [the local voice workflow](../ZenVoice/README.md).
Other narration uses Apple's local speech synthesis. Microphone input uses
Apple Speech; Debug requires on-device recognition and fails gracefully to typing
if the device/language cannot provide it. Permission requests only happen when the
microphone is tapped. Recording stops when the view closes or the app backgrounds.
The active Zen player shows the avatar, a small timer and the stop button. It hides
the breathing circle and transcript, while keeping the top navigation controls accessible. The chest expands forward and sideways, shoulders rise slightly and linen folds
settle with a short delay. Hands, knees and cushion remain fixed. The deformation
follows the selected inhale/hold/exhale timings; existing breathing cues still
fire at phase boundaries. Sleep stories use gentle breathing without exercise cues.

Eyes open while voicing, blink at varied 3–6 second intervals, and ease closed in
silence. Recorded speech uses audio metering for approximate jaw movement.
Native speech playback callbacks drive the lips, jaw and cheeks: phoneme markers when
provided by the selected Apple voice, otherwise a word-synchronized grapheme
estimate. The fallback is approximate, not production phoneme/viseme lip sync.
Adjacent articulations blend smoothly, with separate lip rounding for rounded
vowels and closure for bilabial consonants. The mouth stops moving during pauses,
cancellation and completion.

**Release builds retain real generation and existing subscription checks.**
The test screen is available there too; it does not promise free generation.

Run the isolated service/parser regression checks:

```sh
Tools/ZenSessionTests/run.sh
Tools/ZenAvatarTests/run.sh
```

These compile the actual parser, models, fixture builder and service in Debug.
Backend URL getters trap if accessed. Checks cover the requested phrases, bounds,
focus routing, both generators, cancellation, credits and JSON round-trips.
The service tests also check retired plan/destination cleanup: it is safe to run twice,
preserves history, mountain progress, audio and reward records, and still decodes saved scripts from
the former plan feature without retaining its obsolete metadata.

## Avatar construction

The first procedural clay monk has been replaced with a reference-textured model:

- CC0 MakeHuman anatomy for the head, with closed eyelids, lean aged proportions,
  connected lip/chin/cheek geometry, and real spherical eyes behind anatomical
  eyelids. Paired closed/open head snapshots supply eyelid vertex displacement.
  The portrait UVs are registered to the lid seam, so skin moves with the lids.
  The anatomical lip seam is aligned with the painted mouth. A matching speech
  pose deforms the continuous face, with no detached chin or moving patch.
- Iris placement is calibrated within the existing eye globes, so the pupils
  sit naturally within the lid openings without moving spheres through the skin.
  Native surface shading adds subtle iris fibers and softer scleral shading.
- A continuous robe with a traced silhouette, rounded chest/arm/knee volumes,
  shallow folds, resting hands, prayer beads and a rectangular linen cushion.
- One 1024 × 1024 portrait texture, taken from Vindla's existing image, retains
  the wrinkles, silver beard, fabric and colors without thousands of tiny meshes.
- 60,580 triangles, 9 mesh objects; USDZ approximately 4.6 MiB. See
  `asset-metrics.json` for the measured export size.
  A dark recessed mouth cavity and a subtle upper dental edge give parted lips
  depth; both remain concealed behind the lips at rest.

This is a **frontal character prototype**, not a fully reconstructed 360° human.
The robe and hands use shaped, textured surfaces; their unseen backs are simple.
The source image is an illustration, so its painted character remains. The long
frontal lens and small movements preserve the likeness. A photorealistic model,
large head turns, or close-up conversational facial acting would require further
sculpting, textures and a facial rig. Do not market this as exact lip sync.

## Source and regeneration

- `ZenMinimalist.blend`: editable scene with packed portrait and studio camera.
- `create_zen_avatar.py`: builds geometry, UVs, materials, USDZ and studio preview.
- `Source/ZenHeadAnatomy.blend`: editable MakeHuman-derived closed head source.
- `Source/ZenHeadOpenAnatomy.blend`: matching open-eyelid anatomy.
- `Source/ZenHeadSpeechAnatomy.blend`: matching anatomical speech pose.
- `Source/MakeHuman-CC0.md`: upstream asset license.
- `Source/PROVENANCE.md`: source, version and reconstruction notes.
- `ZenMinimalist-preview.png`: Blender render, not a simulator screenshot.
- `ZenMinimalist-speaking.png`: anatomical speech-pose render.
- `../../Stilla/Resources/ZenMinimalist.usdz`: exported model for the app.
- `../../Stilla/Resources/ZenEyelids.png`: 256 × 128 numerical displacement atlas,
  approximately 17 KB on disk. This is linear motion data, not an eye image.

With free Blender 4.5.9 LTS, from the repository root:

```sh
/path/to/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python Tools/ZenAvatar/create_zen_avatar.py
/path/to/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python-exit-code 1 --python Tools/ZenAvatar/validate_avatar.py
```

The checked-in anatomy snapshots mean this step needs no addon or network.
Building the app's Metal shader requires Xcode's free Metal Toolchain component
(`xcodebuild -downloadComponent MetalToolchain` if Xcode reports it missing).

For repeatable visual inspection in Debug, `--zen-avatar-eyes-open` holds the
anatomical lids open; omit it to restore speech-driven eyes and blinking. This
flag is compiled out of Release.
`--zen-avatar-closeup` enlarges the face for inspection;
`--zen-avatar-speech-cycle` repeats open/rounded/rest poses without audio. Both
are Debug-only and must be omitted for normal speech-playback verification.

## Runtime and verification

RealityKit `ARView` uses non-AR mode on the existing iOS 17 deployment target.
No camera access or avatar service is needed. The USD stage is Y-up; its animated
children retain Blender's local Z-up axes. Native Metal geometry modifiers deform
the torso and its surface normals, and lift anatomical eyelids over the eyeballs.
No cloth physics solver, mesh rebuilding per frame or online service is used.
The eyelid atlas avoids a RealityKit USD import discrepancy where the second UV
set is available in CPU mesh data but not in the custom geometry shader.
A small head movement and speech-driven facial deformation also run locally.
Speech deltas use USD's standard `displayColor` attribute, which RealityKit maps
to the vertex color input; a custom attribute name is not imported there. The
shader resets vertex color to white after reading motion data. `validate_avatar.py`
checks this export contract as well as connected face topology and eye fit.
Reduce Motion disables animated movement and blinking, preserving static open/closed eye states. Inactivity
cancels animation callbacks; dismissal releases model/loading/subscriptions. A
load failure falls back to the original portrait.

The avatar can be switched off for meditation in Settings. The new conversation
screen always displays it so it can be evaluated independently of that preference.

USDZ has passed `UsdUtils.ComplianceChecker(arkit=True)` with no failed checks,
errors or warnings. Simulator checks cover native rendering, script preparation,
20-minute playback and stopping. The active avatar update additionally checks
open eyes during speech, blinking, closed eyes during silence, the small timer,
absence of the transcript/circle, and stopping into reflection. Speech/phase
regression tests cover all breathing presets, hold boundaries, long-running clocks,
word gaps, phoneme priority and stop/restart. A Metal compute regression test
runs the production torso deformation on the GPU and verifies chest expansion,
bilateral rib movement, shoulder lift, fixed hands/legs/cushion, cloth response
and bounded/rest poses. Sleep-story routing and content type are covered
by the service regression checks; full sleep-story UI playback was not completed
in this pass because the shared Simulator was in use. Captures are in
`output/zen-avatar/`. Simulator videos have no sound. Debug and Release builds
are checked separately; Release is not launched during local verification.

Physical-device thermal behavior, sustained frame rate and real microphone
transcription still need a device check. Polygon/texture budgets and Simulator
success are not a substitute for that measurement.

The facial regression also runs the production Metal speech function on sampled
vertices from the generated head (`speech-samples.json`), verifying jaw/lip
opening, vowel rounding, a fixed upper face and exact rest pose. Motion-model
checks cover smooth word boundaries and sustained vowels without letter flutter.

2026-09-20 facial pass: Debug and Release simulator builds passed; native
close-up captures cover the corrected gaze, open/rounded/rest poses, normal
Apple speech playback and return to rest. The short, silent simulator recording
is `output/zen-avatar/zen-natural-face-demo.mp4`. The QA simulator was restored to
the normal framing and speech behavior after capture.

Breathing follow-up: frontal chest rise and rib/shoulder movement are more
visible, with hands and legs still fixed. Debug permits breathing audio without
a StoreKit purchase; Release keeps the existing technique-library entitlement.
The user's Off/Haptic/Sound/Both setting and signal volume still apply. The QA
simulator was explicitly set to Sound. `--zen-avatar-breath-diagnostics` logs
attached motion shaders, phase durations, Reduce Motion, PCM peaks and the audio
player's rendered frame count; it does not enable sound or change preferences.
