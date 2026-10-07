# Stilla Kai Proxy

Small deployable backend for Stilla's Kai generation flow. The iOS app sends:

```json
{
  "mood": "Intention: Anxiety Calm. Mood/Details: anxious about tomorrow",
  "durationMinutes": 10
}
```

The proxy returns a `MeditationScript` JSON payload that matches the app's decoder:

```json
{
  "title": "Evening Softening",
  "durationMinutes": 10,
  "steps": [
    { "text": "Welcome...", "pauseDuration": 6 }
  ]
}
```

## Quick Start

1. Copy `.env.example` to `.env`
2. Set `OPENAI_API_KEY`
3. Set App Attest env vars (`APPLE_TEAM_ID`, `IOS_BUNDLE_ID`, `APP_AUTH_TOKEN_SECRET`)
4. Set `REDIS_URL`
5. Install and run:

```bash
npm install
npm run dev
```

Health check:

```bash
curl http://localhost:8787/health
```

Generate a meditation:

```bash
curl -X POST http://localhost:8787/kai/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PROXY_TOKEN" \
  -d '{"mood":"Need help calming down before sleep","durationMinutes":10}'
```

Generate a sleep story + next headers in one call:

```bash
curl -X POST http://localhost:8787/kai/sleep/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PROXY_TOKEN" \
  -d '{
    "themeTitle":"Lanterns in the Harbor",
    "themeSubtitle":"Soft waves and distant lights",
    "durationMinutes":20,
    "locale":"en",
    "excludeTitles":["Lanterns in the Harbor"]
  }'
```

## Deploy Options

This folder works well on:

- Railway
- Render
- Fly.io
- any Node host that supports `npm install` and `npm start`

Use:

- Build command: `npm install`
- Start command: `npm start`

## Hooking It Up To iOS

Set these keys in `Stilla/Info.plist` or via build settings:

- `KAIBackendURL` = your deployed `/kai/generate` endpoint
- `KAISleepStoryBackendURL` = your deployed `/kai/sleep/generate` endpoint (optional; defaults by path)
- `KAIAttestBaseURL` = your deployed `/attest` base endpoint (optional; defaults by path)

Example:

- `KAIBackendURL` = `https://your-domain.com/kai/generate`
- `KAISleepStoryBackendURL` = `https://your-domain.com/kai/sleep/generate`
- `KAIAttestBaseURL` = `https://your-domain.com/attest`

## App Attest Endpoints

- `POST /attest/challenge`
- `POST /attest/register`
- `POST /attest/assert`

Authenticated app tokens are minted after register/assert and must be sent as:

`Authorization: Bearer <short_lived_app_token>`

Protected endpoints:

- `POST /kai/generate`
- `POST /kai/sleep/generate`
- `POST /kai/share`
- `POST /kai/guide/image`

## Custom guide artwork

`POST /kai/guide/image` accepts `description` (up to 2,000 characters) and an optional
`referenceImage` (base64 JPEG or PNG, at most 1.5 MB decoded). At least one is required.
It uses `gpt-image-2.5-sunburst`, medium quality, 1024 × 1024, transparent PNG, and
returns the PNG bytes directly. Provider credentials remain on the server.

Requests use the existing App Attest token. Redis limits each installation to one
concurrent generation and 15 attempts per hour. Failed/slow provider calls are not
automatically retried. Input images and descriptions are not logged or persisted by
this endpoint; generated artwork is saved by the app with its local creation draft.

Run the HTTP/input/concurrency checks with `node --test guide-images.test.js`.
The first device experiment uses the isolated deployment configured by
`KAI_GUIDE_IMAGE_BACKEND_URL` in Debug.xcconfig. Deploy this endpoint to the normal
backend before enabling it in a release build; no production alias was promoted.

## Production Notes

- Keep the OpenAI key server-side only.
- Add rate limiting before launch.
- Add request logging and alerting.
- App Attest requires Redis-backed state for challenge replay protection and sign counter tracking.
- Do not ship long-lived bearer secrets inside the app bundle.
- Revoke any old OpenAI key that was previously bundled in the iOS app.

## Custom guide voices and six meditation lengths

Set `ELEVENLABS_API_KEY` only in the server environment. It needs Text to Speech
and Voices read/write access to use and add selected shared library voices. Never
put this key in an iOS build setting. `guide-voice-index.json` contains only public
voice IDs and names from the bundled app catalogue.

App-attested `POST /kai/guide/meditations` accepts `guideID`, `name`, `language`,
`voiceID`, `personality` and `appearance`. It returns a validated, resumable pack
of six practices (5–30 minutes), with fixed cue IDs and a private installation-owned
cache. `POST /kai/guide/speech` takes only `packID` and `cueID`, returning one MP3.
Completed recordings are reused across lengths and saved on-device. See
`Tools/CustomGuideMeditationTests/README.md` for lifecycle and verification details.

Deploy both new modules and `guide-voice-index.json` together with `server.js`.

The app starts image generation alongside script/audio creation. Audio downloads use
a rolling parallel queue with `speechConcurrency` from the plan response; the default
is two simultaneous TTS requests for the Free plan. Set `ELEVENLABS_SPEECH_CONCURRENCY`
to the account's actual allowance when using a different plan (maximum 29). Speech
locks are per clip, so different clips can run together while duplicate requests for
the same clip remain protected. Completed clips are checkpointed serially as they
arrive, preserving resume support. Deploy the backend change before distributing the
parallel client; older deployments still serialize all speech requests.

ElevenLabs free-account test: use a `premade` standard voice (Sarah was verified live on 2026-10-02). Shared Voice Library voices require a paid plan via the API even when `free_users_allowed` is true in library metadata. The iOS picker distinguishes these groups and defaults to standard voices. No plan upgrade or auto top-up is enabled by this integration. Standard-voice auditions currently use English previews; generated sessions use the selected language.
