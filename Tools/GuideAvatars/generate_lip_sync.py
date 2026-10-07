#!/usr/bin/env python3
"""Bake local, hash-bound Rhubarb visemes; never ship the recognizer to iOS.

python3 Tools/GuideAvatars/generate_lip_sync.py --rhubarb /path/to/rhubarb
English uses the known dialogue; Swedish uses Rhubarb's phonetic recognizer.
"""
import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--rhubarb', required=True, type=Path)
parser.add_argument('--only', default='')
args = parser.parse_args()
recognizer = args.rhubarb.resolve()
for folder, manifest in [('GuideIntroductions', 'manifest.json'), ('GuideMeditations', 'audio.json')]:
    pack = ROOT / 'Stilla/Resources' / folder
    clips = json.loads((pack / manifest).read_text())['clips']
    for clip in clips:
        if clip['guideID'] not in {'serene_guide', 'shadow_guide'}:
            continue
        if args.only and args.only not in clip['file']:
            continue
        audio = pack / clip['file']
        digest = hashlib.sha256(audio.read_bytes()).hexdigest()
        output = audio.with_suffix('.lipsync.json')
        if output.exists() and json.loads(output.read_text())['audioSHA256'] == digest:
            continue
        with tempfile.TemporaryDirectory(prefix='vindla-visemes-') as temporary:
            work = Path(temporary)
            wav, dialogue, result = work/'voice.wav', work/'text.txt', work/'cues.json'
            subprocess.run(['ffmpeg', '-v', 'error', '-i', str(audio), '-ar', '16000', '-ac', '1', str(wav)], check=True)
            dialogue.write_text(clip['text'])
            command = [str(recognizer), '-f', 'json', '--threads', '2', '--extendedShapes', 'GHX', '-o', str(result), str(wav)]
            command += ['-d', str(dialogue)] if clip['language'] == 'en' else ['-r', 'phonetic']
            subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            analysis = json.loads(result.read_text())
            payload = dict(version=1, audioSHA256=digest, duration=analysis['metadata']['duration'],
                           generator='Rhubarb 1.14.0', mouthCues=analysis['mouthCues'])
            output.write_text(json.dumps(payload, separators=(',', ':')) + '\n')
            print(f"{folder}/{output.name}: {len(payload['mouthCues'])} articulations", flush=True)
