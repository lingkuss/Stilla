#!/usr/bin/env python3
"""Render the authored English cue library with the approved synthetic voices."""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path
for key in ('HF_HUB_OFFLINE','TRANSFORMERS_OFFLINE','HF_HUB_DISABLE_TELEMETRY'): os.environ[key]='1'
ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'Stilla/Resources/GuideMeditations'
WORK=ROOT/'output/guide-meditations'
MODEL='mlx-community/chatterbox-multilingual-v3'

def write(path,value):
    tmp=path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n'); tmp.replace(path)

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--only'); parser.add_argument('--seed',type=int); parser.add_argument('--force',action='store_true')
    args=parser.parse_args()
    if not (PACK/'pause.m4a').exists():
        subprocess.run(['ffmpeg','-v','error','-y','-f','lavfi','-i','anullsrc=r=24000:cl=mono',
                        '-t','185','-c:a','aac','-b:a','32k',str(PACK/'pause.m4a')],check=True)
    import mlx.core as mx
    import numpy as np
    import soundfile as sf
    from mlx_audio.tts.utils import load_model
    catalog=json.loads((PACK/'catalog.json').read_text())
    takes_path=ROOT/'Tools/GuideMeditations/takes.json'
    takes=json.loads(takes_path.read_text()) if takes_path.exists() else {}
    manifest_path=PACK/'audio.json'
    manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'version':1,'language':'en','engine':MODEL,'clips':[]}
    WORK.mkdir(parents=True,exist_ok=True)
    pending=[]
    for guide in catalog['guides']:
        ref=(ROOT/'Tools/ZenVoice/references/en.wav' if guide['id']=='zen_minimalist'
             else ROOT/'Tools/GuideVoices/references'/f"{guide['id']}.wav")
        sha=hashlib.sha256(ref.read_bytes()).hexdigest()
        for cue in guide['cues']:
            if args.only and args.only not in (guide['id'],cue['id']):continue
            seed=args.seed if args.seed is not None else takes.get(cue['id'],{}).get('seed',42)
            settings=dict(model=MODEL,seed=seed,exaggeration=.15,cfgWeight=.5,temperature=.7,referenceSHA256=sha,text=cue['text'])
            if args.seed is None and takes.get(cue['id'],{}).get('trimStart',0)>0:
                settings['trimStart']=takes[cue['id']]['trimStart']
            fingerprint=hashlib.sha256(json.dumps(settings,sort_keys=True).encode()).hexdigest()
            filename=cue['id']+'.m4a'
            prior=next((c for c in manifest['clips'] if c['cueID']==cue['id']),None)
            if not args.force and prior and prior.get('generationHash')==fingerprint and (PACK/filename).exists():continue
            pending.append((guide,cue,ref,sha,fingerprint,filename,settings))
    if not pending:print('All recordings are current.',flush=True);return
    model=load_model(MODEL)
    conditions={}
    for index,(guide,cue,ref,sha,fingerprint,filename,settings) in enumerate(pending):
        started=time.monotonic(); identity=guide['id']
        print(f"[{index+1}/{len(pending)}] {cue['id']}",flush=True)
        if identity not in conditions:conditions[identity]=model.prepare_conditionals(str(ref),ref_sr=24000,exaggeration=.15)
        mx.random.seed(settings['seed'])
        chunks=list(model.generate(text=cue['text'],conds=conditions[identity],lang_code='en',exaggeration=.15,
                                   cfg_weight=.5,temperature=.7,max_new_tokens=1500,verbose=False))
        rate=chunks[0].sample_rate
        audio=np.concatenate([np.asarray(c.audio).reshape(-1) for c in chunks])
        assert len(audio) and np.isfinite(audio).all() and np.max(np.abs(audio))>.001,cue['id']
        assert 1<len(audio)/rate<60,(cue['id'],'Unexpected duration')
        wav=WORK/(cue['id']+'.wav');sf.write(str(wav),audio,rate)
        tmp=PACK/(cue['id']+'.tmp.m4a')
        trim=['-ss',str(settings['trimStart'])] if settings.get('trimStart',0)>0 else []
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav)]+trim+['-af','loudnorm=I=-20:TP=-2:LRA=9',
                        '-c:a','aac','-b:a','96k',str(tmp)],check=True)
        tmp.replace(PACK/filename)
        duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration',
                                               '-of','default=noprint_wrappers=1:nokey=1',str(PACK/filename)]))
        clip=dict(cueID=cue['id'],guideID=identity,language='en',text=cue['text'],file=filename,duration=duration,
                  generationHash=fingerprint,audioSHA256=hashlib.sha256((PACK/filename).read_bytes()).hexdigest(),settings=settings)
        manifest['clips']=[c for c in manifest['clips'] if c['cueID']!=cue['id']]+[clip]
        write(manifest_path,manifest)
        if args.seed is not None:
            takes[cue['id']]={'seed':args.seed}
            write(takes_path,takes)
        print(f"  {duration:.1f}s audio in {time.monotonic()-started:.1f}s",flush=True)
        del audio,chunks;mx.clear_cache()
    print('PASS: all requested recordings generated locally.',flush=True)
if __name__=='__main__':main()
