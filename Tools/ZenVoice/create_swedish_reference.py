#!/usr/bin/env python3
"""Regenerate only the Swedish reference using the cached local Piper model."""
import json
from pathlib import Path
import wave
from piper import PiperVoice, SynthesisConfig

here = Path(__file__).resolve().parent
spec = json.loads((here / "profile.json").read_text())["references"]["sv"]
model = Path.home() / ".cache/vindla-voice-models/piper-sv/sv_SE-nst-medium.onnx"
voice = PiperVoice.load(str(model))
with wave.open(str(here / spec["file"]), "wb") as output:
    voice.synthesize_wav(spec["text"], output, syn_config=SynthesisConfig(
        length_scale=1.1, noise_scale=0.5, noise_w_scale=0.6))
