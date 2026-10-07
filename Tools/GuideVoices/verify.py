#!/usr/bin/env python3
"""Decode all bundled introductions and optionally check speech locally."""
import argparse, difflib, json, os, re, subprocess
from pathlib import Path
for key in ('HF_HUB_OFFLINE','TRANSFORMERS_OFFLINE','HF_HUB_DISABLE_TELEMETRY'): os.environ[key]='1'
ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'Stilla/Resources/GuideIntroductions'
parser=argparse.ArgumentParser(); parser.add_argument('--transcribe', action='store_true'); args=parser.parse_args()
profiles=json.loads((ROOT/'Tools/GuideVoices/profiles.json').read_text())['guides']
clips=json.loads((PACK/'manifest.json').read_text())['clips']
expected={(p['id'], lang):p[lang] for p in profiles for lang in ('sv','en')}
assert len(clips)==len(expected)==8
assert {(c['guideID'],c['language']) for c in clips}==set(expected)
report=[]
if args.transcribe: import mlx_whisper
for c in clips:
 path=PACK/c['file']
 assert path.parent==PACK and c['text']==expected[c['guideID'],c['language']]
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(path)]))
 assert 2<duration<35 and abs(duration-c['duration'])<.02
 subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],check=True)
 if args.transcribe:
  result=mlx_whisper.transcribe(str(path),language=c['language'],path_or_hf_repo='mlx-community/whisper-small-mlx')
  actual=result['text'].strip()
  words=lambda text: re.findall(r'\w+',text.lower())
  similarity=difflib.SequenceMatcher(None,words(c['text']),words(actual)).ratio()
  row=dict(guide=c['guideID'],language=c['language'],expected=c['text'],recognized=actual,similarity=round(similarity,3))
  report.append(row); print(json.dumps(row,ensure_ascii=False),flush=True)
if args.transcribe:
 (ROOT/'output/guide-voices/transcription-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS: all eight expected introductions, matching text, finite durations and decodable AAC',flush=True)
