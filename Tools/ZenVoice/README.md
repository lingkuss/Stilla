# Zen Minimalist local voice prototype

The Mac generates audio files once; Vindla plays the bundled files offline.
No OpenAI, ElevenLabs, hosted inference, API keys or Raspberry Pi are involved.
Both Hugging Face and Transformers run in offline mode, so missing weights fail
locally instead of triggering a download or a remote inference request.

`profile.json` describes an original older male guide: low, warm, understated and
unhurried. Each language has its own synthetic reference recording:

- Swedish: `references/sv.wav`, generated locally with Piper's Swedish NST model
  from KBLab. The model card identifies the NST training data as CC0.
- English: `references/en.wav`, the original local Qwen3-TTS VoiceDesign recording.

Chatterbox Multilingual v3 uses only the reference matching the requested language.
Generation fails if either reference is missing, mislabeled, or identical to the
other recording. These guards check declared language and file identity; listening
and local ASR are still needed to confirm spoken language and pronunciation.
The references are independent voice auditions for the same persona, not a claim
that they sound like the same speaker.

## Generate

This machine already has QwenVoice model weights, cached Chatterbox v3 and its
S3Tokenizer, and a Python environment at `~/.cache/vindla-voice`.
The tested MLX Audio version is 0.5.1.
Piper reference generation uses piper-tts 1.8.0 and the locally cached model at
`~/.cache/vindla-voice-models/piper-sv/sv_SE-nst-medium.onnx` plus its JSON config.

```sh
~/.cache/vindla-voice/bin/python Tools/ZenVoice/generate.py
# For just the opening question in both languages:
~/.cache/vindla-voice/bin/python Tools/ZenVoice/generate.py --only zen.session.suggestion
# Optional: regenerate only Swedish clips:
~/.cache/vindla-voice/bin/python Tools/ZenVoice/generate.py --language sv
```

The script reads the actual Swedish/English localization strings. It saves WAV
masters in `output/zen-voice`, and AAC files plus a
text/duration manifest in `Stilla/Resources/ZenVoice`. Unchanged files are reused.
Edit `profile.json` to experiment with the voice; a changed profile invalidates
the affected clips. Reference audio hashes also invalidate affected clips and are
recorded per clip in the manifest. `takes.json` holds per-phrase sampling settings;
changing one take regenerates only that clip. Generation is separate from building
or running the app.

## Listen in Vindla

In a **Debug** build, open **Möt Zen Minimalist / Meet Zen Minimalist** and tap the
speaker beside the ten-minute suggestion. Start the example meditation to hear
the same voice throughout. The ready phrase and avatar sample are included too.
Use the app language setting and restart to compare Swedish and English.

Only exact, supported fixture text for the Zen meditation uses the voice pack.
Other personas, sleep stories, changed text, sessions too short for the recordings,
and Release builds keep the existing
Apple speech path. The app never calls a generation service for these files.

Pauses account for measured audio duration. Stop, dismissal and app backgrounding
stop the preview; the active meditation keeps its existing session lifecycle.
The avatar uses measured audio level for approximate jaw movement and stays still
in silence. This is not phoneme-aligned lip sync. Word highlighting is unavailable
for recorded speech because the pack does not include word timestamps.

## Checks

```sh
Tools/ZenSessionTests/run.sh
Tools/ZenAvatarTests/run.sh
python3 Tools/ZenVoice/test_references.py
~/.cache/vindla-voice/bin/python Tools/ZenVoice/verify.py
# Optional local speech recognition (no API):
~/.cache/vindla-voice/bin/python Tools/ZenVoice/verify.py --transcribe
```

The voice is a first listening prototype. Local speech recognition can flag
missing or mispronounced words, but does not establish naturalness or pleasant
delivery; those need listening feedback.

The v1 English-reference experiment is archived under `output/zen-voice/v1` for
comparison. Version 2 uses separate language-matched references. The Swedish
reference's transcript was checked locally before conditioning Chatterbox.
Local ASR results are saved in `output/zen-voice/transcription-check.json`.
Treat these as auditions until both pronunciation and delivery have been heard.
The v2 Swedish pack improves mean word agreement with local Whisper from roughly
0.69 to 0.88 across the 13 clips. This is a rough transcript comparison, not a
perceptual quality score or a controlled reference-only experiment (sampling
settings changed too). Pronunciation errors remain, especially the rest-focus
phrase. The selected Swedish opening question uses seed 42 and transcribes
correctly. English remains close to its intended text.

Model documentation: [Chatterbox](https://github.com/Blaizzy/mlx-audio/blob/main/docs/models/tts/chatterbox.md),
[Qwen3-TTS](https://github.com/Blaizzy/mlx-audio/blob/main/docs/models/tts/qwen3-tts.md),
[Swedish Piper model card](https://huggingface.co/rhasspy/piper-voices/blob/main/sv/sv_SE/nst/medium/MODEL_CARD).
