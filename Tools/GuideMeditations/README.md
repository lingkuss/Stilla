# Four guides, twenty-four practices

The English practice catalog covers all guided mountain lengths: 5, 10, 15, 20,
25 and 30 minutes. Each of the four guides has six named practices with intentional
sequences, added stages in longer sessions, and its own vocabulary and focus.
No session repeats passages to fill time. Passages are shared between lengths
where the same foundation or return is appropriate.

- **Zen Minimalist:** economical, concrete, spacious; breath, body, returning,
  thoughts, effort, then open awareness.
- **Stillness Guide:** warm, grounded, practical; settling, embodiment, believable
  kindness, rest, a gentler inner voice, and room for mixed feelings.
- **Shadow Guide:** curious and patient; mild present-day feelings, protective
  habits and conflicting wishes. Every practice starts with grounding, preserves
  choice, and closes the inquiry. No forced catharsis or recovered-memory work.
- **Ra:** ceremonial, benevolent, luminous; light, belonging, catalyst, balance,
  and unity as contemplative images. Physical grounding and return remain clear.

Read [all scripts with pauses](SCRIPTS.md). `author.py` is the editorial source;
`Stilla/Resources/GuideMeditations/catalog.json` is the app's compiled catalog.
The optional intention field remains a personal intention, not a request to
rewrite these prerecorded practices.

## Original synthetic voices

The English reference recordings are the same ones used for the approved guide
introductions: the established Zen recording and the three Qwen VoiceDesign
references in `Tools/GuideVoices/references`. Local Chatterbox renders 124 unique
cues once. The phone plays bundled AAC; it does not load an AI model or contact a
service. The existing introductory clips and original Zen session remain intact.

```sh
python3 Tools/GuideMeditations/author.py
~/.cache/vindla-voice/bin/python Tools/GuideMeditations/generate_audio.py
# A targeted retake (then repeat transcription and timing checks):
~/.cache/vindla-voice/bin/python Tools/GuideMeditations/generate_audio.py --only ra.greeting --seed 73 --force
python3 Tools/GuideMeditations/verify_audio.py
sh Tools/GuideMeditationTests/run.sh --recordings
sh Tools/GuideMeditationTests/run_playback.sh
# Rebuild the script book with measured pause lengths:
python3 Tools/GuideMeditations/author.py
# A complete listening export; never adds a long silent audio file to the app:
python3 Tools/GuideMeditations/render_preview.py zen_minimalist --minutes 5
```

Generation is resumable. The manifest records exact text, persona, cue ID,
reference hash, settings, audio hash and measured duration. Changed text cannot
accidentally play old audio. `output/guide-meditations` contains WAV masters,
generation logs, transcription reports and standalone listening exports.
Selected retake seeds and any approved start trim are saved in `takes.json`, so
a later full run preserves them instead of reverting to the original failed take.
One Stillness cue required removing an unwanted generated pre-roll; word alignment
identified the first scripted word and the edit retained a short silent lead-in.
The edited recording was then transcribed again against the complete script.

## Runtime

Only the Debug mountain prototype selects this catalog. Its setup shows the
practice title and "Guided in English" even when the UI is Swedish. The script
stores optional narration language and pack identity; old saved scripts still
decode. Silent sessions and other generators keep their existing behavior.

Measured clip durations plus a two-second initial settling delay are subtracted
from the chosen session length. The remaining time is distributed by editorial
pause weights, reserving at least two seconds per pause. Audio metering drives the
existing 3D facial animation, and the existing session timer/history/progression
remain in control. Ra is still a flat cutout without a mouth rig.

Pauses and the initial two-second settling period play finite ranges from one
small bundled silent AAC file. Audio completion advances to the next phrase;
these recorded practices do not depend on ordinary app timers waking during a
long silent gap. Metering is disabled throughout pauses. Stop/replacement cancels
the continuation using the same shared player's playback identity.

The shared player restores the playback audio category at session start, since
an introduction preview uses ambient audio. This permits narration with the screen
locked, including when no environmental ambience is selected. An incomplete audio
pack falls back to English system speech for the whole practice. Exact timing in
that fallback is an estimate; with the complete pack it uses measured recordings.

## Checks and limits

The Swift tests cover all 24 identities and lengths, ordered growth in guidance,
no repeated passage within a practice, language/persona/text isolation, exact
measured timing, and backward-compatible saved scripts. File verification checks
all hashes, AAC decoding, complete coverage, and pauses shorter than three minutes.
The shared AVAudioPlayer was also exercised on macOS with finite silent ranges,
cancellation, replacement, no speech levels, and invalid-duration rejection.
Offline Whisper screening checks pronunciation and omissions; it is not a human
assessment of voice quality or meditation experience.

No app installation or simulator navigation is performed in this side task;
builds use `output/GuideVoicesDerivedData`. Hands-on listening, background playback,
VoiceOver and physical-device behavior still need verification in the main app.

Final local checks: all 124 spoken recordings matched the expected normalized
words in offline Whisper screening after the retake edit. All 24 practice timings
passed the Swift and audio checks. The finite-pause playback checks passed on
macOS, and the iOS Simulator Debug target built successfully. These checks do not
claim human listening approval or a physical iPhone background-playback test.
