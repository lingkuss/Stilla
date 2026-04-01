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
3. Optionally set `KAI_PROXY_TOKEN`
4. Install and run:

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
- `KAIBackendToken` = same value as `KAI_PROXY_TOKEN` if you use one

Example:

- `KAIBackendURL` = `https://your-domain.com/kai/generate`
- `KAIBackendToken` = `your_random_long_string`

## Production Notes

- Keep the OpenAI key server-side only.
- Add rate limiting before launch.
- Add request logging and alerting.
- The optional shared token is only a first gate. It is not strong app authentication by itself.
- Revoke any old OpenAI key that was previously bundled in the iOS app.
