# Existing voice previews

The Debug guide creator plays existing ElevenLabs preview files only. It never
calls Text to Speech, Voice Design, cloning, or add-voice endpoints. A missing or
unplayable preview produces an error, with no generation fallback.

The bundled `guide-voice-previews.json` was imported on 2026-10-01 and contains
15,611 language-specific previews from ElevenLabs' `high_quality` category:
3,274 English, 1,464 Swedish, 3,876 Spanish, 2,286 French, 3,705 Norwegian and
1,006 Danish. The app requires this category and shows previews for the guide's
selected language. Gender (All / Female / Male), search, tone and favourites
filters combine locally. Unknown or neutral gender appears only under All.
Older favourites resolve against current catalogue metadata. Unverified prototype
examples are no longer included in browsing. High Quality is ElevenLabs' category,
not a meditation-suitability score.

Audio is fetched only on play, with a 2 MB per-file limit and an 8 MB in-memory cache.

To import, provide an existing key with voice-library read access through
`ELEVENLABS_API_KEY`, or a private file containing just the key:

```sh
python3 Tools/GuideVoicePreviews/import_catalog.py --key-file /path/to/private/key-file
```

Do not paste a key into source files or command-line arguments. The importer uses
only `GET /v1/shared-voices?category=high_quality`, follows authenticated pagination, rejects redirects,
and replaces the snapshot only after the complete import succeeds. It never
downloads audio, creates samples, purchases credits, or saves a key in the app.
Rebuild the app after importing. Refresh the snapshot before distributing a build;
availability of voices and preview links can change. Preview selection alone does
not establish availability or licensing for future generated meditations.

API contract: https://elevenlabs.io/docs/api-reference/voices/voice-library/get-shared

Checks (offline; no API requests):

```sh
bash Tools/GuideVoicePreviews/run_checks.sh
```
