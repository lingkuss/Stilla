# Guide introductions

Selectable order: Zen Minimalist, Stillness Guide, Shadow Guide, Ra. Retired
identities and assets remain readable for existing saved sessions, but are not
selectable for new sessions.

`profiles.json` contains the original voice directions and the Swedish/English
introduction scripts. Zen is a warm, restrained older low male voice; Stillness
is a soft, grounded female mezzo; Shadow is a patient velvety bass-baritone; Ra
has a clearer, luminous tenor-baritone and measured ceremonial delivery.
These are synthetic fictional voices, not imitations of real people.

## Local generation

```sh
~/.cache/vindla-voice/bin/python Tools/GuideVoices/generate.py --stage design
~/.cache/vindla-voice/bin/python Tools/GuideVoices/generate.py --stage speech
~/.cache/vindla-voice/bin/python Tools/GuideVoices/verify.py --transcribe
sh Tools/GuideVoiceTests/run.sh
```

The existing local Python environment and cached models are used. Qwen3-TTS
VoiceDesign weights are read from `~/Library/Application Support/QwenVoice/models/`.
The three new English auditions are designed from their descriptions. Zen keeps
its existing language-specific synthetic references. Swedish articulation is
generated with the cached Piper NST model, then S3 speech tokens are rendered
through Chatterbox S3Gen using each guide's reference timbre. This keeps Swedish
pronunciation separate from voice design. Direct cross-language TTS introduced
too many pronunciation errors and was rejected. The converted voices still need
listening review; Qwen is not being presented as a native Swedish voice designer.
Ra uses a second Chatterbox pass conditioned on the converted Swedish recording;
this improved the articulation of his introduction. Swedish pronunciation remains
an audition limitation, especially compound names, despite the improvements.

Designed voice references are retained in `Tools/GuideVoices/references`; WAV
masters and pronunciation sources are in `output/guide-voices`. The app receives only
AAC files and a text/duration manifest in `Stilla/Resources/GuideIntroductions`.
The model libraries are forced offline before loading. There are no hosted API
requests, API keys, meditation credits or on-device generation. Audio is normalized
to a common -20 LUFS target. The existing Zen meditation pack is preserved.

Technical model references:
- [Qwen3-TTS VoiceDesign](https://github.com/Blaizzy/mlx-audio/blob/main/docs/models/tts/qwen3-tts.md)
- [Chatterbox Multilingual](https://github.com/Blaizzy/mlx-audio/blob/main/docs/models/tts/chatterbox.md)

## Playback

In the Debug mountain carousel the focused guide introduces themselves after a
650 ms dwell. Swiping stops speech; only the new focused guide speaks. Leaving
the carousel, selecting a guide, backgrounding, interruption or disconnecting
headphones stops playback. The audition respects the silent switch and mixes
with other music. VoiceOver disables automatic playback; the same listen/stop
control is available manually. The transcript appears beneath the guide's name.
Other app languages fall back to the English audition and its English transcript.

Existing shared audio metering drives the focused 3D guide's mouth. Ra remains
a cutout without a facial rig. These clips are introductions only, not replacements
for the existing full meditation narration. Reduce Motion still disables avatar
motion. Missing audio leaves the guide selectable.

## Verification

- The catalog test checks the exact order, retired identity restoration and fallback.
- The audio check decodes all eight files and checks manifest text and durations.
- Local Whisper transcripts are written to `output/guide-voices/transcription-check.json`.
  ASR agreement is a pronunciation screening aid, not a listening quality score.
  A second check with cached Whisper large-v3-turbo is in
  `output/guide-voices/transcription-large.json`; this uses a separate temporary
  Python dependency environment, without changing the existing voice environment.
- Build output is isolated in `output/GuideVoicesDerivedData` so the main thread's
  simulator/build output is not replaced. No installation into its running app.
- Device listening, carousel interaction and interruption/VoiceOver behavior still
  require hands-on verification. No physical-device performance measurement.
