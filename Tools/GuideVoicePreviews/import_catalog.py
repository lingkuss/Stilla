#!/usr/bin/env python3
"""Import existing Voice Library preview metadata. Never generates or downloads audio."""
import argparse
import collections
import datetime
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.elevenlabs.io/v1/shared-voices"
LANGUAGES = {"en", "sv", "es", "fr", "nb", "da"}
OUTPUT = Path(__file__).resolve().parents[2] / "Stilla/Resources/guide-voice-previews.json"


def language_code(value):
    code = (value or "").lower().split("-")[0]
    return "nb" if code == "no" else code


def existing_preview(value):
    if not isinstance(value, str):
        return False
    try:
        url = urllib.parse.urlsplit(value)
        if url.scheme != "https" or url.username or url.password or url.port not in (None, 443):
            return False
    except ValueError:
        return False
    if url.hostname == "storage.googleapis.com":
        return url.path.startswith("/eleven-public-prod/") and Path(url.path).suffix.lower() in {".mp3", ".wav", ".m4a"}
    hosts = {"api.elevenlabs.io", "api.us.elevenlabs.io", "api.eu.residency.elevenlabs.io",
             "api.in.residency.elevenlabs.io", "api.sg.residency.elevenlabs.io"}
    parts = url.path.strip("/").split("/")
    return (url.hostname in hosts and len(parts) == 5 and parts[:2] == ["v1", "voices"]
            and bool(parts[2]) and parts[3:] == ["previews", "audio"])


def preview_records(voice):
    if voice.get("category") != "high_quality" or not voice.get("voice_id") or not voice.get("name"):
        return []
    # Verified language-specific clips take precedence over the native preview.
    candidates = list(voice.get("verified_languages") or []) + [voice]
    seen = set()
    records = []
    detail = " · ".join(str(voice.get(field) or "").strip() for field in ("descriptive", "description"))
    detail = detail.strip(" ·")[:1000]
    for candidate in candidates:
        language = language_code(candidate.get("language"))
        preview = candidate.get("preview_url")
        if language not in LANGUAGES or language in seen or not existing_preview(preview):
            continue
        seen.add(language)
        records.append({"id": voice["voice_id"], "name": voice["name"], "language": language,
                        "previewURL": preview, "detail": detail, "accent": candidate.get("accent") or "",
                        "category": "high_quality", "gender": voice_gender(voice.get("gender"))})
    return records


def voice_gender(value):
    normalized = value.strip().lower() if isinstance(value, str) else ""
    return normalized if normalized in {"female", "male", "neutral"} else None


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Never forward the credential to another host.


def fetch_catalog(key, opener=None):
    if not key:
        raise ValueError("An existing ElevenLabs API key is required to read the voice library.")
    opener = opener or urllib.request.build_opener(NoRedirect)
    result = {}
    for page in range(1000):
        query = urllib.parse.urlencode({"page_size": 100, "page": page, "sort": "cloned_by_count",
                                       "category": "high_quality",
                                       "include_custom_rates": "true", "include_live_moderated": "true"})
        request = urllib.request.Request(API + "?" + query, method="GET",
                                         headers={"xi-api-key": key, "Accept": "application/json"})
        with opener.open(request, timeout=30) as response:
            body = response.read(20_000_001)
        if len(body) > 20_000_000:
            raise ValueError("Unexpectedly large metadata response; existing catalog retained.")
        data = json.loads(body)
        if not isinstance(data.get("voices"), list) or not isinstance(data.get("has_more"), bool):
            raise ValueError("Unexpected metadata response; existing catalog retained.")
        for voice in data["voices"]:
            for record in preview_records(voice):
                result.setdefault((record["language"], record["id"]), record)
        if not data["has_more"]:
            if not result:
                raise ValueError("No supported previews found; existing catalog retained.")
            return list(result.values())
        if not data["voices"]:
            raise ValueError("Incomplete library response; existing catalog retained.")
    raise ValueError("Library pagination limit reached; existing catalog retained.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key-file", type=Path, help="File containing an existing API key (never written to the catalog).")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    try:
        key = args.key_file.read_text().strip() if args.key_file else os.environ.get("ELEVENLABS_API_KEY", "").strip()
        voices = fetch_catalog(key)
        snapshot = {"updatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(), "voices": voices}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
        temporary.replace(args.output)
        print("Imported existing preview links:", dict(collections.Counter(v["language"] for v in voices)))
        print("No audio generated or downloaded. No voices added to your ElevenLabs account.")
    except urllib.error.HTTPError as error:
        # Do not print remote response bodies or request headers containing a credential.
        print(f"Library request returned HTTP {error.code}. Existing catalog retained.", file=sys.stderr)
        return 1
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
