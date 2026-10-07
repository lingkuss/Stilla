#!/usr/bin/env python3
"""Check authored coverage, files and timing; optional offline English ASR."""
import argparse,difflib,hashlib,json,math,os,re,subprocess,time
from pathlib import Path
for key in ('HF_HUB_OFFLINE','TRANSFORMERS_OFFLINE','HF_HUB_DISABLE_TELEMETRY'):os.environ[key]='1'
ROOT=Path(__file__).resolve().parents[2]; PACK=ROOT/'Stilla/Resources/GuideMeditations'; WORK=ROOT/'output/guide-meditations'
parser=argparse.ArgumentParser();parser.add_argument('--transcribe',action='store_true');parser.add_argument('--watch',action='store_true');args=parser.parse_args()
catalog=json.loads((PACK/'catalog.json').read_text())
expected={c['id']:(g['id'],c['text']) for g in catalog['guides'] for c in g['cues']}
assert len(catalog['guides'])==4
for g in catalog['guides']:
 assert [s['minutes'] for s in g['sessions']]==[5,10,15,20,25,30]
 assert len(set(s['title'] for s in g['sessions']))==6
 for s in g['sessions']:
  assert len(s['cueIDs'])==len(set(s['cueIDs']))
  assert all(k in expected and expected[k][0]==g['id'] for k in s['cueIDs'])
WORK.mkdir(parents=True,exist_ok=True)
report_path=WORK/'transcriptions.json'
report=json.loads(report_path.read_text()) if report_path.exists() else []
if args.transcribe:
 from faster_whisper import WhisperModel
 model_path=Path.home()/'.cache/huggingface/hub/models--mobiuslabsgmbh--faster-whisper-large-v3-turbo/snapshots/0a363e9161cbc7ed1431c9597a8ceaf0c4f78fcf'
 model=WhisperModel(str(model_path),device='cpu',compute_type='int8',cpu_threads=4,local_files_only=True)
def words(text):
 text=text.lower().replace('’',"'")
 for a,b in {"don't":'do not',"doesn't":'does not',"isn't":'is not',"you're":'you are',"we're":'we are',"you've":'you have',"we've":'we have',"it's":'it is',"there's":'there is',"can't":'cannot'}.items():text=text.replace(a,b)
 return re.findall(r'\w+',text)
checked={};last_progress=time.monotonic()
while True:
 manifest=json.loads((PACK/'audio.json').read_text()) if (PACK/'audio.json').exists() else {'clips':[]}
 assert len({c['cueID'] for c in manifest['clips']})==len(manifest['clips'])
 for clip in manifest['clips']:
  key=clip['cueID'];path=PACK/clip['file']
  assert (clip['guideID'],clip['text'])==expected[key] and clip['language']=='en'
  assert path.parent==PACK and path.suffix=='.m4a'
  if checked.get(key)==clip['audioSHA256']:continue
  assert hashlib.sha256(path.read_bytes()).hexdigest()==clip['audioSHA256']
  duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(path)]))
  assert math.isfinite(duration) and 1<duration<60 and abs(duration-clip['duration'])<.02
  subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],check=True)
  if args.transcribe:
   prior=next((r for r in report if r['cueID']==key and r['audioSHA256']==clip['audioSHA256']),None)
   if prior is None:
    segments,_=model.transcribe(str(path),language='en',beam_size=5)
    actual=' '.join(s.text.strip() for s in segments)
    agreement=difflib.SequenceMatcher(None,words(clip['text']),words(actual)).ratio()
    row=dict(cueID=key,audioSHA256=clip['audioSHA256'],expected=clip['text'],recognized=actual,wordAgreement=round(agreement,3),needsReview=agreement<.99)
    report=[r for r in report if r['cueID']!=key]+[row]
    report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(row,ensure_ascii=False),flush=True)
  checked[key]=clip['audioSHA256'];last_progress=time.monotonic()
 if set(checked)==set(expected):break
 if not args.watch:raise AssertionError(f'Missing {len(set(expected)-set(checked))} recordings')
 if time.monotonic()-last_progress>180:raise TimeoutError('No new audio for three minutes; inspect generation log')
 time.sleep(2)
clips={c['cueID']:c for c in manifest['clips']}
pause_file=PACK/'pause.m4a'
pause_duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(pause_file)]))
assert pause_duration>=180
silence_check=subprocess.run(['ffmpeg','-hide_banner','-i',str(pause_file),'-af','volumedetect','-f','null','-'],check=True,capture_output=True,text=True)
peak=re.search(r'max_volume: ([\d.-]+) dB',silence_check.stderr)
assert peak and float(peak.group(1))<=-80,'Pause media must contain silence'
for g in catalog['guides']:
 cues={c['id']:c for c in g['cues']}
 for s in g['sessions']:
  speaking=sum(clips[k]['duration'] for k in s['cueIDs'])
  silence=s['minutes']*60-2-speaking
  assert silence>len(s['cueIDs'])*2,(s['id'],'No room for pauses')
  total_weight=sum(cues[k]['pauseWeight'] for k in s['cueIDs'])
  pauses=[2+(silence-len(s['cueIDs'])*2)*cues[k]['pauseWeight']/total_weight for k in s['cueIDs']]
  assert abs(2+speaking+sum(pauses)-s['minutes']*60)<.001
  assert max(pauses)<180,(s['id'],'Overlong silence')
  print(f"{s['id']}: {speaking:.1f}s speech / {silence:.1f}s silence / longest pause {max(pauses):.1f}s",flush=True)
print(f'PASS: {len(expected)} recordings, all 24 sessions, exact measured timing, no pause over three minutes.',flush=True)
if args.transcribe:
 flagged=[r['cueID'] for r in report if r['needsReview']]
 print('ASR review flags: '+json.dumps(flagged),flush=True)
 if flagged:raise SystemExit(2)
