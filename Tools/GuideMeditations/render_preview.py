#!/usr/bin/env python3
"""Export an entire practice with its real pauses for listening outside the app."""
import argparse,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; PACK=ROOT/'Stilla/Resources/GuideMeditations'; WORK=ROOT/'output/guide-meditations/previews'
parser=argparse.ArgumentParser();parser.add_argument('guide');parser.add_argument('--minutes',type=int,default=5);args=parser.parse_args()
catalog=json.loads((PACK/'catalog.json').read_text());clips={c['cueID']:c for c in json.loads((PACK/'audio.json').read_text())['clips']}
guide=next(g for g in catalog['guides'] if g['id']==args.guide)
practice=next(s for s in guide['sessions'] if s['minutes']==args.minutes)
cues={c['id']:c for c in guide['cues']};selected=[cues[k] for k in practice['cueIDs']]
assert all(c['id'] in clips and clips[c['id']]['text']==c['text'] for c in selected),'Generate all required cues first'
speech=sum(clips[c['id']]['duration'] for c in selected)
silence=args.minutes*60-2-speech;weights=sum(c['pauseWeight'] for c in selected)
cmd=['ffmpeg','-v','error','-y','-f','lavfi','-t','2','-i','anullsrc=r=24000:cl=mono']
filters=[];labels=['[0:a]']
for i,c in enumerate(selected,1):
 cmd+=['-i',str(PACK/clips[c['id']]['file'])]
 pause=2+(silence-len(selected)*2)*c['pauseWeight']/weights
 # Match each segment's measured container duration before adding its pause.
 target=clips[c['id']]['duration']+pause
 filters.append(f'[{i}:a]aresample=24000,apad,atrim=duration={target:.9f},asetpts=PTS-STARTPTS[a{i}]')
 labels.append(f'[a{i}]')
filters.append(''.join(labels)+f'concat=n={len(labels)}:v=0:a=1[out]')
WORK.mkdir(parents=True,exist_ok=True);out=WORK/f'{args.guide}-{args.minutes}min.m4a'
cmd+=['-filter_complex',';'.join(filters),'-map','[out]','-c:a','aac','-b:a','96k',str(out)]
subprocess.run(cmd,check=True)
duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(out)]))
assert abs(duration-args.minutes*60)<.15,duration
print(out)
