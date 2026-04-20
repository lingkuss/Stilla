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

## Production Notes

- Keep the OpenAI key server-side only.
- Add rate limiting before launch.
- Add request logging and alerting.
- App Attest requires Redis-backed state for challenge replay protection and sign counter tracking.
- Do not ship long-lived bearer secrets inside the app bundle.
- Revoke any old OpenAI key that was previously bundled in the iOS app.
