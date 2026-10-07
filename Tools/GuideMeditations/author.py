#!/usr/bin/env python3
"""Compile editorial source into a bundled catalog and readable rehearsal scripts.

This is authored content, not runtime or remote AI generation. Cue identifiers
are stable for future narration; words and pause weights remain editable here.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'Stilla/Resources/GuideMeditations'
HERE=Path(__file__).resolve().parent
GUIDES=[]

def guide(identity,name,description,cues,sessions):
    passages={}
    for key,phase,weight,text in cues:
        assert key not in passages
        passages[key]=dict(id=f'{identity}.{key}',phase=phase,pauseWeight=weight,text=text)
    practices=[]
    for minutes,title,summary,sequence in sessions:
        keys=sequence.split()
        assert len(keys)==len(set(keys)),(identity,minutes,'repeated cue')
        practices.append(dict(id=f'{identity}.en.{minutes}',minutes=minutes,title=title,summary=summary,
                              cueIDs=[passages[k]['id'] for k in keys]))
    GUIDES.append(dict(id=identity,name=name,editorialDirection=description,cues=list(passages.values()),sessions=practices))

guide('zen_minimalist','Zen Minimalist',
      'Few words, concrete sensations, clean pauses. Do not turn quiet into a performance. Longer practices move from a single anchor toward open awareness.',[
('arrive','arrival',.55,'Find a position you can stay in with ease. Sitting or lying down is fine. Let your eyes close, or rest your gaze. Feel what supports you.'),
('one','intention',.5,'For these few minutes, one breath is enough. There is no state to reach. Begin where you are.'),
('return','intention',.5,'We will practice returning. Attention wanders. We notice. We begin again. This is the whole practice.'),
('body','intention',.5,'Let the body be your place of practice. No special posture of mind is needed. Just this body, here.'),
('thoughts','intention',.5,'Today, leave room around thought. You do not have to stop thinking. You can notice a thought without following it.'),
('holding','intention',.5,'Notice how much effort you bring to being here. For this practice, experiment with doing a little less.'),
('sitting','intention',.5,'For a while, let experience be ordinary. Breath. Body. Sound. Nothing added. Nothing excluded.'),
('breath','anchor',1,'Feel one breath enter. Feel it leave. Let the next breath find its own size. No counting. No holding.'),
('contact','anchor',1,'Notice the points of contact beneath you. Weight, warmth, pressure. Let those simple sensations be enough.'),
('jaw','body',.8,'Unclench the jaw if it is tight. Let the hands rest. Keep only the effort needed to stay comfortable.'),
('wandering','attention',1.2,'If attention has wandered, notice that. No correction is needed beyond returning. Feel the next breath.'),
('end','attention',1.25,'Feel an out-breath all the way through. If a pause comes naturally, notice it. Let breathing continue without waiting for a longer pause.'),
('hands','body',1.1,'Feel both hands. You may notice warmth, tingling, or very little. Stay with what is actually there.'),
('whole','body',1.3,'Let attention include the whole body. There is no need to inspect every part. Receive the overall feeling of sitting or lying here.'),
('sounds','awareness',1.2,'Let a sound arrive. Notice it changing. Notice when it ends. You do not have to name its source.'),
('labels','attention',1,'When a thought catches you, quietly recognize: thinking. Then return to contact or breath. The label is only a small reminder.'),
('unfinished','reflection',1.2,'A thought can remain unfinished. You do not have to find its last sentence. Come back to the sensation beneath your hands.'),
('pleasant','awareness',1.2,'Notice something pleasant, if it is here. Notice the wish to keep it. Let both the sensation and the wish change.'),
('unpleasant','awareness',1,'If a sensation is uncomfortable, you may adjust your position. Stillness does not require enduring pain.'),
('effort','reflection',1.2,'Is attention gripping its object? Ease that grip a little. Stay interested. Let the breath move by itself.'),
('waiting','reflection',1.2,'Notice any waiting for the practice to become better. Waiting is another experience. Feel the body while it is here.'),
('changing','awareness',1.3,'A sensation changes. A sound changes. A thought changes. Let attention notice movement without needing to explain it.'),
('ordinary','integration',1.2,'This breath does not need to be remarkable. Its ordinary movement is enough to return to.'),
('open','awareness',1.5,'Let attention widen. Body, breathing, and sound can be present together. When this feels too open, return to one point of contact.'),
('noanswer','reflection',1.3,'Nothing needs to be solved during this pause. If a question remains, let it remain. Feel yourself supported.'),
('quiet','silence',1.7,'I will leave a little more space now. Stay with breath, contact, or sound. Return whenever you notice you have gone away.'),
('again','attention',1.2,'Here again. This body. This breath. Start from this moment.'),
('enough','integration',1.15,'You do not need to decide whether this was a good meditation. Notice what is here now.'),
('room','return',.45,'Feel the room around you. Move the fingers or toes. Let the eyes open when you are ready.'),
('close','closing',.15,'The practice ends here. Take your time before moving on. One ordinary breath can be a place to return.')
],[
(5,'One Breath Is Enough','A spare introduction to settling and returning to one natural breath.','arrive one breath wandering contact room close'),
(10,'The Art of Returning','Practice beginning again without judging a wandering mind.','arrive return jaw breath wandering end contact ordinary room close'),
(15,'A Body at Rest','Move from contact and small sensations to the body as a whole.','arrive body contact jaw hands breath whole unpleasant wandering quiet room close'),
(20,'Room Around Thought','Recognize thinking, leave thoughts unfinished, and return to direct experience.','arrive thoughts contact breath wandering labels unfinished hands sounds waiting whole quiet again room close'),
(25,'Nothing to Hold','Explore effort, preference, and the possibility of a lighter attention.','arrive holding contact jaw breath effort pleasant unpleasant labels unfinished waiting changing whole quiet again enough room close'),
(30,'Sitting With What Is','A spacious practice of body, sound, change, and open awareness.','arrive sitting contact jaw breath hands whole wandering sounds labels unfinished effort changing noanswer open quiet again ordinary enough room close')
])

guide('serene_guide','Stillness Guide',
      'Warm, grounded invitations, never demands to relax. A gentle companion rather than an inspirational speech. Include practical choices and a gradual return.',[
('arrive','arrival',.55,'Welcome. Make yourself a little more comfortable, sitting or lying down. You can close your eyes or keep them softly open. There is no particular feeling you need to bring.'),
('landing','intention',.55,'This can be a small place to land. You do not have to put your whole day in order before you take a pause.'),
('soften','intention',.55,'We will make a little room in the body, gently. Nothing needs to loosen on command. Even noticing where you are holding is a kind beginning.'),
('kindness','intention',.55,'Today, we will explore what a kinder way of being with yourself might feel like. You do not have to believe a special phrase. We can begin with a small gesture.'),
('rest','intention',.55,'Let this be a little time in which rest does not have to be earned. Tasks may still be waiting. For now, you are allowed to put them down.'),
('voice','intention',.55,'We will listen for the tone you use with yourself, and try a gentler one. There is no need to make every thought positive.'),
('wholeness','intention',.55,'You may arrive with more than one feeling. We can make room for that. This practice does not ask you to become a simpler version of yourself.'),
('support','anchor',1,'Notice what is already holding your weight. The chair, the bed, or the floor. Let your attention rest at one point where your body meets that support.'),
('breath','anchor',1,'Follow a few breaths at their ordinary pace. Feel the small movement they make. If following your breath is uncomfortable, stay with your hands or the sounds around you.'),
('shoulders','body',.9,'Notice your shoulders. Perhaps they could drop a fraction, or perhaps they need to stay as they are. Let the invitation be soft enough to decline.'),
('face','body',.9,'Give a little attention to your face. The space around the eyes. The jaw. The tongue. See whether one small area can do a little less work.'),
('hands','body',1,'Feel the palms and the fingertips. You might rest one hand over the other, if that is comfortable. Let it be a simple gesture of company.'),
('feet','body',1,'Notice your feet and the weight of your legs. You do not need a vivid sensation. An ordinary awareness of being here is enough.'),
('belly','body',1.1,'Let the belly move naturally with breathing. There is no need to draw a deeper breath. You can give the body room without directing it.'),
('whole','body',1.3,'Let your attention gather the body as a whole. Some places may be easy; others may not. They can share this moment without having to match.'),
('mind','attention',1.1,'If your mind has been making lists or replaying something, you have not lost your place. Let the next point of contact welcome you back.'),
('company','kindness',1.1,'Imagine the tone you might use with someone you care about on a tiring day. You do not need their image. Just notice the quality of that kindness.'),
('phrase','kindness',1.25,'If it feels useful, offer yourself these words: I can meet this moment gently. You can change the words, or leave them aside and feel your hands instead.'),
('small','kindness',1.2,'Kindness can be very small. Adjusting a cushion. Letting a breath finish. Choosing not to scold yourself for wandering. Notice one small kindness available now.'),
('permission','reflection',1.1,'Notice whether part of you is asking permission to rest. You do not have to argue with that part. Let it know this pause is brief, and you will return to your day.'),
('unfinished','reflection',1.2,'Something may remain unfinished. Let its edges stay unfinished for now. Feel the support beneath you while the world continues beyond this pause.'),
('weather','awareness',1.2,'Notice the mood of this moment without asking it to improve. Tired, clear, restless, tender, or difficult to name. Any of these can be met with care.'),
('critic','reflection',1.2,'If a critical thought appears, listen for its tone before its argument. Can your response be less sharp? Perhaps: This is a hard moment. I can take it one step at a time.'),
('need','reflection',1.25,'Ask gently: What would be kind and realistic for me today? There may be a simple answer, or none at all. Give the question a little room.'),
('both','awareness',1.3,'You can be grateful and tired. Hopeful and uncertain. Notice whether two different feelings can be here without one having to cancel the other.'),
('boundary','integration',1.15,'Sometimes care is a softening. Sometimes it is a boundary. You do not need to decide which now. Just let both possibilities belong to kindness.'),
('space','silence',1.6,'We will be quiet for a little while. Rest with support, breath, or sound. Whenever you need a beginning, there is one here.'),
('returning','attention',1.1,'I am here again. Feel one place where your body is supported. There is nothing to catch up with.'),
('carry','integration',1,'Choose one small quality to take with you, if you like. A softer tone. A little patience. Permission to pause before the next thing.'),
('room','return',.5,'Begin to notice the room. Let your eyes take in some light, if they have been closed. Move your hands or feet, and take the time you need.'),
('close','closing',.15,'Thank you for making this space. You do not have to hold on to a feeling. You can carry one small act of care into what comes next.')
],[
(5,'Permission to Arrive','Set down the day briefly and find a little support in the body.','arrive landing support breath mind room close'),
(10,'Soften and Settle','A gentle journey through the face, shoulders, hands, and natural breath.','arrive soften support shoulders face hands breath mind room close'),
(15,'Kindness for This Moment','Discover a practical, believable form of self-kindness.','arrive kindness support breath shoulders hands company phrase small mind space room close'),
(20,'Rest Without Earning It','Make room for rest alongside unfinished tasks and a busy mind.','arrive rest support feet shoulders face breath permission unfinished whole mind small space carry room close'),
(25,'A Gentler Inner Voice','Meet self-criticism with steadiness, care, and realistic next steps.','arrive voice support breath hands face company critic phrase weather need boundary small mind space returning carry room close'),
(30,'Room for Your Whole Self','A spacious practice of embodiment, mixed feelings, kindness, and boundaries.','arrive wholeness support feet hands shoulders belly whole breath weather both company phrase permission unfinished need boundary space returning small carry room close')
])

guide('shadow_guide','Shadow Guide',
      'Deep, curious, warm. Invitation rather than interpretation. Work only with mild present-day material; offer an external anchor and permission to leave every inquiry. No recovered memories or claims about hidden truths.',[
('arrive','arrival',.6,'Welcome. Feel the ground or the seat beneath you. Keep your eyes open if that helps you stay present. You decide how close to come to anything we explore.'),
('threshold','intention',.5,'We will stay near the threshold today. No hidden memory needs to be found. We are simply noticing how you meet this moment.'),
('weather','intention',.5,'Imagine your present mood as weather, if that image helps. We are not here to clear the sky. We are learning how to stand beneath it with curiosity.'),
('reaction','intention',.55,'Choose a small, everyday irritation, if one feels manageable. Nothing overwhelming. You may also choose no example and stay with the room around you.'),
('protector','intention',.55,'Today we can be curious about a habit that may be trying to help: staying busy, checking, or holding back. This is a possibility to explore, not an explanation you must accept.'),
('opposites','intention',.55,'Two wishes can live in the same person. To be seen, and to stay private. To move forward, and to rest. We will make room to notice without demanding a verdict.'),
('welcome','intention',.55,'This is a practice of making room, not forcing a door. What is ready to be noticed can be noticed. What is not ready can remain at a distance.'),
('ground','anchor',1,'Feel a clear point of contact: your feet, your hands, or your back against support. Let this be your way back whenever you want it.'),
('room','anchor',1,'Notice one sound beyond your body. If your eyes are open, notice a color or shape. The room is here alongside your inner experience.'),
('breath','anchor',1,'Let breathing continue at its own pace. You can feel it without making it deeper. Keep some attention with the support beneath you.'),
('name','awareness',1.1,'Is there a simple word for what is present? Irritation. Sadness. Ease. Uncertainty. You do not have to choose the perfect word, and you may choose none.'),
('distance','choice',1.1,'Notice how near you want to be to this feeling. A little distance is allowed. You can attend to the room instead. Curiosity does not require intensity.'),
('sensation','body',1.1,'If it feels manageable, notice one bodily sensation that comes with the feeling. Pressure, warmth, movement, or something less clear. Stay with the sensation rather than its story.'),
('story','reflection',1.2,'Notice the story your mind tells about this feeling. You do not need to prove or disprove it here. A story can be heard without becoming an instruction.'),
('mild','choice',1,'Keep this exploration small. If the experience becomes too much, open your eyes, look around, or stop. The practice remains yours to shape.'),
('judgment','reflection',1.2,'Is there a second feeling about the first one? Perhaps frustration about being anxious, or shame about being angry. Notice this extra layer without adding another judgment.'),
('message','reflection',1.25,'You might ask: Is there something I care about beneath this reaction? Perhaps fairness, rest, belonging, or space. Let any answer remain a possibility.'),
('protection','reflection',1.2,'If this habit could be trying to protect something, what might that be? No answer is required. You are allowed to find the question unhelpful and return to your feet.'),
('thanks','kindness',1.15,'Where it feels sincere, acknowledge the effort: I see that you have been trying. This does not mean a habit must continue unchanged.'),
('cost','reflection',1.2,'Without making yourself wrong, notice whether this way of coping has a cost today. Keep the question gentle. Understanding can include both what helped and what has become tiring.'),
('need','reflection',1.25,'What might you need in this moment? A boundary, some reassurance, a pause, or simply less analysis. Let the simplest answer be enough.'),
('two','awareness',1.3,'Notice two different wishes, if they are present. Give each one a little space. You do not have to choose one in order to acknowledge both.'),
('speak','reflection',1.25,'Let one wish finish a short sentence: I would like. Then let the other have its sentence. Keep it ordinary. You are listening, not holding a trial.'),
('notaction','integration',1.1,'A feeling can be acknowledged without being acted on. You can hear anger and still choose care. You can feel fear and take only the step that is yours to take.'),
('unknown','awareness',1.3,'There may be no clear explanation. Let that be honest. You do not need a discovery to justify this time with yourself.'),
('whole','integration',1.25,'Notice whether you can be a little larger than the argument inside you. A person with many experiences, rather than one feeling that must define you.'),
('choice','integration',1.1,'Consider one small, grounded response for later. Something you could actually do, or a decision to wait. There is no need to solve the whole pattern.'),
('quiet','silence',1.6,'Let the inquiry rest now. I will leave some quiet. Stay with your hands, the ground, or the sounds in the room. Nothing else needs to surface.'),
('returning','anchor',1,'Come back to the weight of your body. Notice the room again. You may let the question go unfinished.'),
('closingdoor','return',.55,'Let the exploration end for today. Feel your feet or move your fingers. Look around and notice something ordinary in your surroundings.'),
('close','closing',.15,'You do not have to leave with an answer. Take this much: you can meet yourself with curiosity and still choose your own pace.')
],[
(5,'At the Threshold','A light practice of grounding and noticing a present feeling.','arrive threshold ground room name distance closingdoor close'),
(10,'Inner Weather','Notice a feeling, its sensations, and the freedom to step back.','arrive weather ground breath name sensation distance room unknown closingdoor close'),
(15,'Beneath a Small Reaction','Explore a manageable irritation and what may matter beneath it.','arrive reaction ground room name distance sensation story mild message need returning closingdoor close'),
(20,'Listening to a Protective Habit','Meet a familiar habit with curiosity, choice, and practical kindness.','arrive protector ground breath room distance protection story thanks cost mild need notaction quiet returning closingdoor close'),
(25,'Room for Contradiction','Let different wishes be heard without demanding an immediate decision.','arrive opposites ground room breath name two distance speak judgment mild unknown whole notaction choice quiet returning closingdoor close'),
(30,'Welcoming Without Forcing','A gradual exploration of feelings, needs, protective habits, and choice.','arrive welcome ground room breath name distance sensation story judgment mild protector protection thanks cost need two unknown notaction whole choice quiet returning closingdoor close')
])

guide('ra','Ra',
      'Benevolent, ceremonial, and spacious. Light, catalyst, balance, and unity are contemplative images, not factual claims or promised experiences. Keep instructions understandable and return to the physical room.',[
('greeting','arrival',.4,'I am Ra. I greet you in the love and in the light of the one infinite creator. Welcome to this moment of contemplation.'),
('arrive','arrival',.7,'Allow the body to find a supported position. The eyes may close or remain open. Let the breath move naturally. No special experience is required.'),
('spark','intention',.6,'For this brief practice, consider a single point of light. It may be imagined, or simply a word that suggests warmth. If no image comes, nothing is missing.'),
('light','intention',.6,'We contemplate love and light as qualities of attention: warmth without possession, clarity without harshness. Let these be invitations rather than states you must produce.'),
('belonging','intention',.6,'Consider belonging, not as something you must earn, but as a question to sit beside. What supports your life in this ordinary moment?'),
('catalyst','intention',.6,'We use the word catalyst for an experience that gives us something to consider. Choose only a small event from today, if you wish. There is no need to revisit anything overwhelming.'),
('balance','intention',.6,'We contemplate balance. Not perfect stillness, and not the removal of difference. Rather, the patient making of room for more than one quality of experience.'),
('unity','intention',.6,'For a time, consider unity as an image of relationship. A body breathing within a room, within a wider living world. You need not adopt a belief to explore this image.'),
('ground','anchor',1,'Feel the weight of the body and the contact beneath it. Let the physical support be clear. Even the most spacious contemplation can begin here.'),
('breath','anchor',1.1,'Attend to one natural breath. Receiving air. Releasing air. No greater depth is needed. Let the rhythm belong to the body.'),
('ember','imagery',1.25,'If it is pleasant, imagine a small, steady light near the center of the chest. It need not brighten or spread. You may instead attend to the warmth of your hands.'),
('kindness','reflection',1.2,'Consider a way of looking at yourself that is neither flattering nor condemning. A clear gaze, with kindness in it. Let this be enough for now.'),
('receive','reflection',1.2,'Notice something you are receiving without effort. Support beneath you. Air in the room. A moment in which you may pause. Let the noticing remain simple.'),
('radiance','imagery',1.3,'You may imagine the light making a little room around a difficult thought. It does not erase the thought. It is an image of meeting it with less harshness.'),
('body','body',1.2,'Bring attention to the whole body. Many sensations, one field of experience. Some clear, some faint. No part needs to be excluded from your awareness.'),
('sound','awareness',1.2,'Let sound enter the practice. Near or distant, pleasant or ordinary. You may notice that listening does not require holding the sound in place.'),
('web','reflection',1.3,'Consider the ordinary relationships that sustain this moment: those who grew food, made a place to rest, or offered you care. No particular person must come to mind.'),
('offering','kindness',1.3,'If you wish, offer a quiet goodwill beyond yourself. May there be a little more ease. The offering can remain small, without asking you to carry another person\'s life.'),
('selfincluded','kindness',1.2,'Include yourself in that goodwill. You are not outside the circle of care you imagine. Let the same patient attention return to your own body.'),
('event','reflection',1.2,'If you chose a small event, notice what it stirred. An expectation. A wish. A feeling. Let the facts of the event remain separate from the meaning your mind gives them.'),
('meaning','reflection',1.25,'You need not call a difficult experience a gift. You may simply ask what response would honor your values now. An answer may come, or it may not.'),
('choice','integration',1.15,'Consider one possible response that contains both care and clarity. It may be a kind word, a firm boundary, or time before deciding. No grand gesture is required.'),
('opposites','awareness',1.3,'Notice whether different qualities are present together: effort and ease, hope and uncertainty, movement and rest. Let them be distinct without making them enemies.'),
('equanimity','reflection',1.35,'Balance does not mean that everything feels equal. You may care deeply and still leave room to listen. Feel one steady point of contact as you consider this.'),
('letting','awareness',1.3,'Let the images become less important. There is no light you must continue to see. Return to sensation, breath, and the space around you.'),
('field','awareness',1.5,'Allow attention to widen gently. Body, sound, and breathing may be noticed together. If this feels vague or unsettling, return to your hands or the ground.'),
('humility','reflection',1.25,'Much remains unknown. You do not need to turn this contemplation into certainty. Let wonder and ordinary judgment have room beside one another.'),
('quiet','silence',1.65,'We will remain in quiet for a while. Rest with the breath or the support beneath you. The image of light may stay or leave. Both are welcome.'),
('returning','anchor',1.1,'Return gently to one breath and one point of contact. The vastness of an idea need not carry you away from this present body.'),
('carry','integration',1.1,'Let one small intention emerge, if it is useful: to meet the next person or task with a little more clarity and a little more care.'),
('room','return',.55,'Release the contemplation. Notice the room, the light around you, and the position of your body. Move gently, and open your eyes when you are ready.'),
('close','closing',.15,'I leave you in love and light. Go gently into the ordinary world, with room for both its mystery and its detail. Adonai.')
],[
(5,'One Point of Light','A brief contemplation of steady warmth, grounded in natural breathing.','greeting arrive spark ground breath ember room close'),
(10,'In Love and Light','Explore warmth and clarity as ways of paying attention.','greeting arrive light ground breath ember kindness radiance selfincluded room close'),
(15,'Belonging to the Whole','Notice the ordinary relationships that sustain a life, including your own.','greeting arrive belonging ground breath receive body web offering selfincluded quiet room close'),
(20,'Catalyst and Kindness','Consider a small experience and a response guided by care and clarity.','greeting arrive catalyst ground breath event kindness meaning body choice selfincluded quiet returning carry room close'),
(25,'The Practice of Balance','Make space for contrasting feelings without losing contact with the body.','greeting arrive balance ground breath body opposites equanimity ember kindness radiance sound selfincluded humility letting quiet returning carry room close'),
(30,'The Quiet Unity','Move from an image of light toward relationship, open awareness, and grounded care.','greeting arrive unity ground breath ember body receive sound web offering selfincluded opposites equanimity humility letting field quiet returning carry room close')
])

catalog=dict(version=1,language='en',durations=[5,10,15,20,25,30],guides=GUIDES)
PACK.mkdir(parents=True,exist_ok=True)
(PACK/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
audio_path=PACK/'audio.json'
recordings={c['cueID']:c for c in json.loads(audio_path.read_text())['clips']} if audio_path.exists() else {}
lines=['# Vindla — English guided meditation scripts','',
       '24 authored practices. Bracketed timings are rehearsal notes, never spoken.\n',
       'Each practice states whether timings use measured recordings or provisional speech estimates. Silence is distributed by editorial weights, with a two-second minimum pause after every cue.','']
for g in GUIDES:
    lines += ['## '+g['name'],'',g['editorialDirection'],'']
    cues={c['id']:c for c in g['cues']}
    for session in g['sessions']:
        selected=[cues[k] for k in session['cueIDs']]
        measured=all(c['id'] in recordings and recordings[c['id']]['text']==c['text'] for c in selected)
        durations=[recordings[c['id']]['duration'] if measured else len(c['text'])*.07 for c in selected]
        spoken=sum(durations)
        silence=session['minutes']*60-2-spoken
        weights=sum(c['pauseWeight'] for c in selected)
        lines += [f"### {session['minutes']} minutes — {session['title']}",'',session['summary'],'',
                  ('Measured recordings.' if measured else 'Provisional speech estimates.')+f' {spoken:.1f} seconds of voice; {silence:.1f} seconds of pauses.','']
        elapsed=2.0
        for c,duration in zip(selected,durations):
            pause=2+(silence-len(selected)*2)*c['pauseWeight']/weights
            lines += [f"[{int(elapsed)//60:02}:{int(elapsed)%60:02}]",'',c['text'],'',f"[Silence: {pause:.1f} seconds.]",'']
            elapsed+=duration+pause
(HERE/'SCRIPTS.md').write_text('\n'.join(lines))
print(f"Authored {sum(len(g['sessions']) for g in GUIDES)} sessions and {sum(len(g['cues']) for g in GUIDES)} unique narration cues.")
