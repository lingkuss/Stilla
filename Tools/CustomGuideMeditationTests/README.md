# Custom guides with recorded meditation packs

`sh Tools/CustomGuideMeditationTests/run.sh` verifies all six durations using measured
clip lengths, bounded real pauses, identity/language isolation, missing recordings,
and unsafe pack paths. `node --test backend/kai-proxy/guide-meditations.test.js`
checks authentication, per-installation ownership, retry caching, concurrent generation,
input validation, provider error handling and limits without using paid APIs.

Creating a guide writes a personalized pack with 29 unique recordings: a short
introduction and 28 practice cues. Sessions at 5, 10, 15, 20, 25 and 30 minutes share
the opening and ending, and add complete stages as the duration increases. No cue
is repeated within a practice. Recorded speech plus finite silent media ranges
add up to the selected duration, including the initial two-second settling pause.

The app saves each validated MP3 and a resumable manifest before requesting the
next recording. Completed packs and the portrait are stored in Application Support;
playback, including the carousel introduction, does not call the generation API.
The whole guide is published only after all lengths have usable recordings. Existing
image-only guides are retained; create a new guide to include a voice pack.

The server accepts voice IDs from the same bundled Voice Library catalogue. It uses
OpenAI structured outputs for scripts and ElevenLabs multilingual v2 for speech,
with a fixed gentle speed. It never accepts client-supplied speech text, models or
arbitrary media URLs. The API key lives only on the server. Its required permissions
are Text to Speech and Voices (read/write, for adding a selected shared voice).

Server progress/audio caches expire after seven days; on-device completed packs do
not expire. Requests are serialized per installation, bounded to five script packs
and 160 clip attempts per day. Successful replies are cached before delivery so a
lost response can normally be retrieved without another paid generation. A provider
response lost before the server receives/stores it cannot be made exactly-once;
there is no automatic retry for provider timeouts.
