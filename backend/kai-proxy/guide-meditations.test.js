import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import {registerGuideMeditations,cueIDs,durations,validatePlan} from './guide-meditations.js';
const input={guideID:'custom-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',name:'Moss',language:'sv',voiceID:'testVoice123456789012',personality:'Varm och vänlig',appearance:'Räv'};
const raw={cues:cueIDs.map(id=>({id,text:`Cue ${id}: Rest quietly and notice the support beneath your body. You can breathe naturally.`})),sessions:durations.map(minutes=>({minutes,title:`Practice ${minutes}`,summary:'A gentle practice.'}))};
const audio=Buffer.concat([Buffer.from('ID3'),Buffer.alloc(700)]);
class KV {
    values=new Map();
    async get(k){return this.values.get(k) ?? null;}
    async set(k,v,...options){if(options.includes('NX') && this.values.has(k))return null;this.values.set(k,v);return 'OK';}
    async eval(script,n,k,token){if(script.includes('INCR')){const value=Number(this.values.get(k)||0)+1;this.values.set(k,value);return value;}if(this.values.get(k)===token)this.values.delete(k);return 1;}
}
async function fixture(t,opts={}){
    const kv=new KV(),calls=[],app=express();
    const client={chat:{completions:{create:async options=>{calls.push({type:'plan',options});if(opts.plan)await opts.plan();return {choices:[{finish_reason:'stop',message:{content:JSON.stringify(raw)}}]};}}}};
    const fetcher=async(url,options)=>{calls.push({type:'voice',url,options});if(url.includes('text-to-speech'))return opts.speech?opts.speech():new Response(audio,{headers:{'Content-Type':'audio/mpeg'}});return Response.json({voice_id:input.voiceID});};
    registerGuideMeditations(app,{kv,client,fetcher,elevenKey:opts.noKey?undefined:'secret',voices:{[input.voiceID]:'Test Voice'},authorize:(req,res,next)=>{if(!req.headers.authorization)return res.status(401).end();req.auth={installationId:req.headers.authorization};next();}});
    const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));t.after(()=>new Promise(r=>server.close(r)));
    const request=(path,body,owner='a')=>fetch(`http://127.0.0.1:${server.address().port}/kai/guide/${path}`,{method:'POST',headers:{'Content-Type':'application/json',...(owner?{Authorization:owner}:{})},body:JSON.stringify(body)});
    return {kv,calls,request};
}
test('six correctly ordered lengths with longer stages and no repeated cue',()=>{
    const plan=validatePlan(raw,input,'b'.repeat(64));
    assert.equal(plan.cues.length,29);
    assert.deepEqual(plan.sessions.map(s=>s.cueIDs.length),[8,12,16,20,24,28]);
    for(const s of plan.sessions){assert.equal(new Set(s.cueIDs).size,s.cueIDs.length);assert.equal(s.cueIDs.at(-1),'return2');assert(!s.cueIDs.includes('introduction'));}
    assert.throws(()=>validatePlan({...raw,cues:raw.cues.slice(1)},input,'b'.repeat(64)));
    assert.throws(()=>validatePlan({...raw,cues:raw.cues.map(c=>({...c,text:'Same text in every single recording.'}))},input,'b'.repeat(64)));
});
test('auth, invalid input and missing key fail before provider calls',async t=>{
    const f=await fixture(t);
    assert.equal((await f.request('meditations',input,'')).status,401);
    assert.equal((await f.request('meditations',{...input,voiceID:'unknown'})).status,400);
    assert.equal(f.calls.length,0);
    const g=await fixture(t,{noKey:true});assert.equal((await g.request('meditations',input)).status,503);assert.equal(g.calls.length,0);
});
test('plan and speech retry reuse exact cached results; clients cannot inject TTS text/model',async t=>{
    const f=await fixture(t);
    const plan=await (await f.request('meditations',input)).json();
    assert(!plan.resolvedVoiceID);
    assert.deepEqual(await (await f.request('meditations',input)).json(),plan);
    const body={packID:plan.packID,cueID:'breath1',text:'unauthorized',model:'wrong'};
    for(let i=0;i<2;i++){const response=await f.request('speech',body);assert.equal(response.status,200);assert.deepEqual(Buffer.from(await response.arrayBuffer()),audio);}
    assert.equal(f.calls.filter(c=>c.type==='plan').length,1);
    const speech=f.calls.filter(c=>c.url?.includes('text-to-speech'));assert.equal(speech.length,1);
    assert.equal(JSON.parse(speech[0].options.body).text,raw.cues.find(c=>c.id==='breath1').text);
    assert.equal(JSON.parse(speech[0].options.body).model_id,'eleven_multilingual_v2');
    assert.equal((await f.request('speech',body,'another-device')).status,410);
    assert.equal((await f.request('speech',{...body,cueID:'../escape'})).status,400);
});
test('concurrent request cannot spend credits twice',async t=>{
    let start,finish;const started=new Promise(r=>start=r);
    const f=await fixture(t,{plan:()=>{start();return new Promise(r=>finish=r);}});
    const first=f.request('meditations',input);await started;
    assert.equal((await f.request('meditations',input)).status,409);finish();assert.equal((await first).status,200);
});
test('quota and permissions remain actionable without exposing provider secrets',async t=>{
    for(const [status,code,http] of [['quota_exceeded','voice_credits',402],['missing_permissions','voice_permissions',503]]){
        const f=await fixture(t,{speech:()=>Response.json({detail:{status,message:'secret account detail'}},{status:401})});
        const plan=await (await f.request('meditations',input)).json();
        const response=await f.request('speech',{packID:plan.packID,cueID:'settle1'});
        assert.equal(response.status,http);assert.deepEqual(await response.json(),{code});
    }
});
test('rejects corrupt audio and enforces daily plan budget',async t=>{
    const f=await fixture(t,{speech:()=>new Response('not audio')});
    const plan=await (await f.request('meditations',input)).json();
    assert.deepEqual(await (await f.request('speech',{packID:plan.packID,cueID:'return2'})).json(),{code:'invalid_audio'});
    for(let i=1;i<5;i++)assert.equal((await f.request('meditations',{...input,name:`Guide ${i}`})).status,200);
    assert.equal((await f.request('meditations',{...input,name:'sixth'})).status,429);
});

test('paid library voices have a distinct actionable error',async t=>{
    const f=await fixture(t,{speech:()=>Response.json({detail:{status:'payment_required',code:'paid_plan_required'}},{status:402})});
    const plan=await (await f.request('meditations',input)).json();
    const response=await f.request('speech',{packID:plan.packID,cueID:'introduction'});
    assert.equal(response.status,402);assert.deepEqual(await response.json(),{code:'voice_plan_required'});
});
