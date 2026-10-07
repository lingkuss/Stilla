#!/usr/bin/env python3
"""Offline synthetic guide auditions. No real person's voice or hosted API."""
import argparse, hashlib, json, os, subprocess, time, wave
from pathlib import Path
for key in ('HF_HUB_OFFLINE', 'TRANSFORMERS_OFFLINE', 'HF_HUB_DISABLE_TELEMETRY'):
    os.environ[key] = '1'
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REFERENCES = HERE / 'references'
WORK = ROOT / 'output/guide-voices'
PACK = ROOT / 'Stilla/Resources/GuideIntroductions'
DESIGN = 'mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit'
CHATTERBOX = 'mlx-community/chatterbox-multilingual-v3'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', choices=['design', 'speech'], required=True)
    parser.add_argument('--only')
    parser.add_argument('--language', choices=['sv', 'en'])
    args = parser.parse_args()
    import mlx.core as mx
    import numpy as np
    import soundfile as sf
    from mlx_audio.tts.utils import load_model
    profiles = json.loads((HERE / 'profiles.json').read_text())['guides']
    WORK.mkdir(parents=True, exist_ok=True)
    REFERENCES.mkdir(parents=True, exist_ok=True)
    PACK.mkdir(parents=True, exist_ok=True)
    manifest_path = PACK / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'version': 1, 'clips': []}
    design_path = Path.home() / 'Library/Application Support/QwenVoice/models/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit'
    model = load_model(str(design_path) if args.stage == 'design' else CHATTERBOX)
    for guide in profiles:
        if args.only and guide['id'] != args.only: continue
        identity = guide['id']
        if args.stage == 'design':
            if identity == 'zen_minimalist': continue
            reference = REFERENCES / f'{identity}.wav'
            metadata = reference.with_suffix('.json')
            design_hash = hashlib.sha256(json.dumps([guide['description'],guide['en'],guide['seed'],DESIGN]).encode()).hexdigest()
            if reference.exists() and metadata.exists() and json.loads(metadata.read_text()).get('designHash') == design_hash: continue
            mx.random.seed(guide['seed'])
            print(f'Designing {identity}', flush=True)
            chunks = list(model.generate_voice_design(text=guide['en'], instruct=guide['description'],
                language='English', temperature=0.7, max_tokens=700))
            audio = np.concatenate([np.asarray(c.audio).reshape(-1) for c in chunks])
            sf.write(str(reference), audio, chunks[0].sample_rate)
            metadata.write_text(json.dumps({'designHash':design_hash,'model':DESIGN,'language':'en','synthetic':True},indent=2)+'\n')
            print(f'Saved {identity} reference ({len(audio)/chunks[0].sample_rate:.1f}s)', flush=True)
            mx.clear_cache()
            continue
        for language in ('sv', 'en'):
            if args.language and args.language != language: continue
            filename = f'{identity}-{language}.m4a'
            reference = (ROOT / f'Tools/ZenVoice/references/{language}.wav' if identity == 'zen_minimalist'
                         else REFERENCES / f'{identity}.wav')
            digest = hashlib.sha256(reference.read_bytes()).hexdigest()
            version = (5 if guide.get('refineSwedish') else 4) if language=='sv' else 1
            settings = [guide['id'],guide[language],guide['seed'],language,digest,CHATTERBOX,version]
            generation_hash = hashlib.sha256(json.dumps(settings,sort_keys=True).encode()).hexdigest()
            cached = next((c for c in manifest['clips'] if c['guideID']==identity and c['language']==language),None)
            if cached and cached.get('generationHash') == generation_hash and (PACK/filename).exists(): continue
            started = time.monotonic()
            mx.random.seed(guide['seed'])
            print(f'Generating {identity}/{language}', flush=True)
            if language == 'sv':
                # Preserve Swedish pronunciation using synthetic Swedish speech
                # tokens, then render them with the designed voice's S3Gen timbre.
                # Both source and target are synthetic; no human voice recording.
                from piper import PiperVoice, SynthesisConfig
                from mlx_audio.utils import load_audio
                from mlx_audio.tts.models.chatterbox.s3tokenizer import log_mel_spectrogram
                piper_path = Path.home() / '.cache/vindla-voice-models/piper-sv/sv_SE-nst-medium.onnx'
                source = WORK / f'{identity}-sv-pronunciation.wav'
                piper = PiperVoice.load(str(piper_path))
                with wave.open(str(source), 'wb') as out:
                    piper.synthesize_wav(guide['sv'], out, syn_config=SynthesisConfig(
                        length_scale={'zen_minimalist':1.12,'serene_guide':1.05,'shadow_guide':1.15,'ra':1.12}[identity],
                        noise_scale=.5, noise_w_scale=.6))
                conds = model.prepare_conditionals(str(reference), ref_sr=24000, exaggeration=.15)
                source_audio = load_audio(str(source), sample_rate=16000)
                source_audio = mx.concatenate([mx.zeros(4800),source_audio,mx.zeros(3200)])
                mel = mx.expand_dims(log_mel_spectrogram(source_audio), 0)
                tokens, lengths = model._s3_tokenizer(mel, mx.array([mel.shape[2]]))
                tokens = tokens[:, :int(lengths[0])]
                mx.random.seed(guide['seed'])
                audio = np.asarray(model.s3gen(speech_tokens=tokens, ref_dict=conds.gen, finalize=True)).reshape(-1)
                rate = model.sample_rate
                if guide.get('refineSwedish'):
                    # Ra's designed resonance benefits from a language-matched
                    # second pass rather than the direct converted take.
                    adapted = WORK / f'{identity}-sv-adapted-reference.wav'
                    sf.write(str(adapted),audio,rate)
                    conds = model.prepare_conditionals(str(adapted),ref_sr=rate,exaggeration=.15)
                    mx.random.seed(42)
                    chunks = list(model.generate(text=guide['sv'],conds=conds,lang_code='sv',
                        exaggeration=.15,cfg_weight=.5,temperature=.7,max_new_tokens=1000,verbose=False))
                    audio = np.concatenate([np.asarray(c.audio).reshape(-1) for c in chunks])
                    rate = chunks[0].sample_rate
            elif identity != 'zen_minimalist':
                audio, rate = sf.read(str(reference), dtype='float32')
            else:
                conds = model.prepare_conditionals(str(reference), ref_sr=24000, exaggeration=0.15)
                chunks = list(model.generate(text=guide[language], conds=conds, lang_code=language,
                    exaggeration=0.15, cfg_weight=0.5, temperature=0.7, max_new_tokens=1000, verbose=False))
                rate = chunks[0].sample_rate
                audio = np.concatenate([np.asarray(c.audio).reshape(-1) for c in chunks])
            assert len(audio) and np.isfinite(audio).all() and np.max(np.abs(audio)) > .001
            wav = WORK / filename.replace('.m4a','.wav')
            sf.write(str(wav),audio,rate)
            temporary = PACK / filename.replace('.m4a','.tmp.m4a')
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-af','loudnorm=I=-20:TP=-2:LRA=9',
                '-c:a','aac','-b:a','96k',str(temporary)], check=True)
            temporary.replace(PACK/filename)
            duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration',
                '-of','default=noprint_wrappers=1:nokey=1',str(PACK/filename)]))
            assert 2 < duration < 35
            clip=dict(guideID=identity,language=language,text=guide[language],file=filename,duration=duration,
                generationHash=generation_hash,referenceSHA256=digest,referenceLanguage=language if identity=='zen_minimalist' else 'en',
                engine=('local Piper Swedish + Chatterbox S3Gen voice conversion' if language=='sv' else
                    DESIGN if identity!='zen_minimalist' else CHATTERBOX))
            if language=='sv' and guide.get('refineSwedish'):
                clip['engine'] += ' + language-matched Chatterbox refinement'
            manifest['clips']=[c for c in manifest['clips'] if not(c['guideID']==identity and c['language']==language)]+[clip]
            tmp=manifest_path.with_suffix('.tmp')
            tmp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'); tmp.replace(manifest_path)
            print(f'{identity}/{language}: {duration:.1f}s / generated in {time.monotonic()-started:.1f}s',flush=True)
            mx.clear_cache()
if __name__ == '__main__': main()
