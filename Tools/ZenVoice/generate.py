#!/usr/bin/env python3
"""Generate the Zen voice pack on this Mac. No network or paid APIs.

Run with ~/.cache/vindla-voice/bin/python Tools/ZenVoice/generate.py.
Uses separate Swedish and English recordings to condition cached Chatterbox.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

# Set before importing any model library. Missing models must fail locally.
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PACK = ROOT / "Stilla/Resources/ZenVoice"
WORK = ROOT / "output/zen-voice"
CHATTERBOX = "mlx-community/chatterbox-multilingual-v3"
KEYS = ["zen.session.suggestion", "zen.session.ready", "zen.avatar.sample",
        "zen.mock.meditation.opening", *[f"zen.mock.meditation.{n}" for n in range(1, 5)],
        "zen.mock.meditation.closing", *[f"zen.mock.focus.{f}" for f in ("rest", "stress", "focus", "sleep")]]


def strings(language):
    source = (ROOT / f"Stilla/{language}.lproj/Localizable.strings").read_text()
    return {json.loads(k): json.loads(v) for k, v in re.findall(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;', source)}


def write_manifest(manifest):
    path = PACK / "manifest.json"
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def load_references(profile, base=HERE):
    references = {}
    for language in ("sv", "en"):
        spec = profile.get("references", {}).get(language)
        if not spec or spec.get("language") != language:
            raise ValueError(f"Missing or mismatched {language} reference")
        path = base / spec["file"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        references[language] = dict(spec, sha256=digest, path=path)
    if references["sv"]["sha256"] == references["en"]["sha256"]:
        raise ValueError("Swedish and English must use distinct language-matched recordings")
    return references


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="Generate only this localization key")
    parser.add_argument("--language", choices=("sv", "en"))
    args = parser.parse_args()
    if args.only and args.only not in KEYS:
        parser.error("--only must be one of the voice pack's localization keys")
    import mlx.core as mx
    import numpy as np
    import soundfile as sf
    from mlx_audio.tts.utils import load_model

    profile = json.loads((HERE / "profile.json").read_text())
    takes = json.loads((HERE / "takes.json").read_text())
    references = load_references(profile)
    fingerprint = hashlib.sha256(json.dumps(profile, sort_keys=True).encode()).hexdigest()
    PACK.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    manifest_path = PACK / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"clips": []}
    manifest.pop("referenceFile", None)
    manifest.pop("referenceEngine", None)
    reference_metadata = {lang: {k: v for k, v in spec.items() if k != "path"}
                          for lang, spec in references.items()}
    manifest.update(version=2, persona="zen_minimalist", profile=profile["id"],
                    profileHash=fingerprint, engine="local Chatterbox Multilingual v3 / MLX",
                    references=reference_metadata)
    pending = []
    for language in ("sv", "en"):
        if args.language and args.language != language:
            continue
        localized = strings(language)
        for key in KEYS:
            if args.only and args.only != key:
                continue
            text = localized[key]
            filename = f"{language}-{key.removeprefix('zen.').replace('.', '-')}.m4a"
            cached = next((c for c in manifest["clips"] if c["language"] == language and c["key"] == key), None)
            take = takes.get(f"{language}:{key}", {})
            settings = {k: v for k, v in profile.items() if k != "references"}
            generation_hash = hashlib.sha256(json.dumps(dict(settings=settings,
                reference=reference_metadata[language], take=take, model=CHATTERBOX),
                sort_keys=True).encode()).hexdigest()
            if cached and cached["text"] == text and cached.get("generationHash") == generation_hash and (PACK / filename).exists():
                continue
            pending.append((language, key, text, filename, take, generation_hash))
    if not pending:
        print("Voice pack is up to date.")
        return
    print(f"Loading local Chatterbox for {len(pending)} clips…", flush=True)
    model = load_model(CHATTERBOX)
    conditionals = {}
    for language, key, text, filename, take, generation_hash in pending:
        if language not in conditionals:
            conditionals[language] = model.prepare_conditionals(str(references[language]["path"]),
                ref_sr=24000, exaggeration=profile["exaggeration"])
        started = time.monotonic()
        spoken = take.get("text", text)
        sentences = re.split(r"(?<=[.!?])\s+", spoken) if take.get("splitSentences") else [spoken]
        parts = []
        for sentence in sentences:
            mx.random.seed(take.get("seed", profile["seed"]))
            chunks = list(model.generate(text=sentence, conds=conditionals[language], lang_code=language,
                exaggeration=profile["exaggeration"],
                cfg_weight=take.get("cfgWeight", profile["cfgWeight"]),
                temperature=profile["temperature"], max_new_tokens=1200, verbose=False))
            rate = chunks[0].sample_rate
            if parts:
                parts.append(np.zeros(int(rate * 0.35), dtype=np.float32))
            parts.extend(np.asarray(c.audio).reshape(-1) for c in chunks)
        audio = np.concatenate(parts)
        if not len(audio) or not np.isfinite(audio).all() or np.max(np.abs(audio)) < 0.001:
            raise RuntimeError(f"Invalid audio for {language}/{key}")
        wav = WORK / filename.replace(".m4a", ".wav")
        sf.write(str(wav), audio, rate)
        temporary = PACK / filename.replace(".m4a", ".tmp.m4a")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "aac",
                        "-b:a", "96k", str(temporary)], check=True)
        temporary.replace(PACK / filename)
        duration = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries",
            "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(PACK / filename)]))
        clip = dict(key=key, language=language, text=text, file=filename, duration=duration, take=take,
                    referenceLanguage=language, referenceSHA256=references[language]["sha256"],
                    generationHash=generation_hash)
        manifest["clips"] = [c for c in manifest["clips"] if not (c["language"] == language and c["key"] == key)] + [clip]
        write_manifest(manifest)
        print(f"{language} {key}: {duration:.1f}s audio / {time.monotonic()-started:.1f}s generation", flush=True)
        del chunks, audio
        mx.clear_cache()


if __name__ == "__main__":
    main()
