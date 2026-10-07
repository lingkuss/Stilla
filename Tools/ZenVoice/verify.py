#!/usr/bin/env python3
"""Check bundled clips and optionally transcribe them with cached local Whisper."""
import argparse
import difflib
import json
import os
from pathlib import Path
import re
import subprocess

os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"

from generate import HERE, KEYS, PACK, WORK, strings, load_references

parser = argparse.ArgumentParser()
parser.add_argument("--transcribe", action="store_true")
args = parser.parse_args()
manifest = json.loads((PACK / "manifest.json").read_text())
references = load_references(json.loads((HERE / "profile.json").read_text()))
assert manifest["version"] == 2
for language, reference in references.items():
    assert manifest["references"][language]["sha256"] == reference["sha256"]
clips = manifest["clips"]
assert len(clips) == len(KEYS) * 2
assert len({(c["language"], c["key"]) for c in clips}) == len(clips)
report = []
if args.transcribe:
    import mlx_whisper

def words(text):
    text = text.lower().replace("10", "ten")
    return re.findall(r"\w+", text)

for clip in clips:
    assert clip["referenceLanguage"] == clip["language"]
    assert clip["referenceSHA256"] == references[clip["language"]]["sha256"]
    assert clip["generationHash"]
    path = PACK / clip["file"]
    assert path.is_file() and path.parent == PACK
    assert clip["text"] == strings(clip["language"])[clip["key"]]
    duration = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries",
        "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(path)]))
    assert abs(duration - clip["duration"]) < 0.02 and duration > 1
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"], check=True)
    if args.transcribe:
        result = mlx_whisper.transcribe(str(path), language=clip["language"],
            path_or_hf_repo="mlx-community/whisper-large-v3-turbo")
        recognized = result["text"].strip()
        similarity = difflib.SequenceMatcher(None, words(clip["text"]), words(recognized)).ratio()
        entry = dict(language=clip["language"], key=clip["key"], expected=clip["text"],
                     recognized=recognized, wordSimilarity=round(similarity, 3))
        report.append(entry)
        print(json.dumps(entry, ensure_ascii=False), flush=True)
        (WORK / "transcription-check.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")
print(f"PASS: {len(clips)} clips, distinct language-matched references, current fixture text, measured durations and AAC decoding")
