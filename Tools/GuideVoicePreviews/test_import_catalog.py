import io
import json
import unittest
import urllib.parse
from unittest.mock import Mock

from import_catalog import existing_preview, fetch_catalog, preview_records, voice_gender

PREVIEW = "https://storage.googleapis.com/eleven-public-prod/example/voices/one/preview.mp3"
SWEDISH = "https://storage.googleapis.com/eleven-public-prod/example/voices/one/swedish.mp3"


class PreviewContractTests(unittest.TestCase):
    def test_only_existing_preview_routes_are_allowed(self):
        self.assertTrue(existing_preview(PREVIEW))
        self.assertTrue(existing_preview("https://api.elevenlabs.io/v1/voices/one/previews/audio"))
        for url in [None, "http://example.com/a.mp3", "https://evil.example/a.mp3",
                    "https://storage.googleapis.com/other-bucket/example.mp3",
                    "https://api.elevenlabs.io/v1/text-to-speech/one",
                    "https://api.elevenlabs.io/v1/text-to-voice/design",
                    "https://secret@api.elevenlabs.io/v1/voices/one/previews/audio"]:
            self.assertFalse(existing_preview(url), url)

    def test_language_specific_preview_precedes_native_and_missing_is_excluded(self):
        voice = {"voice_id": "one", "name": "Voice", "category": "high_quality", "gender": "Female",
                 "language": "en", "preview_url": PREVIEW,
                 "verified_languages": [{"language": "sv", "preview_url": SWEDISH},
                                        {"language": "sv", "preview_url": PREVIEW},
                                        {"language": "da", "preview_url": None}]}
        result = preview_records(voice)
        self.assertEqual([v["language"] for v in result], ["sv", "en"])
        self.assertEqual(result[0]["previewURL"], SWEDISH)
        self.assertTrue(all(v["category"] == "high_quality" and v["gender"] == "female" for v in result))
        voice["language"] = "no"
        self.assertEqual(preview_records(voice)[-1]["language"], "nb")

    def test_authenticated_pagination_is_get_metadata_only(self):
        requests = []

        def open_page(request, timeout):
            requests.append(request)
            self.assertEqual(request.get_method(), "GET")
            self.assertIsNone(request.data)
            self.assertEqual(request.get_header("Xi-api-key"), "test-read-key")
            url = urllib.parse.urlsplit(request.full_url)
            self.assertEqual((url.scheme, url.netloc, url.path), ("https", "api.elevenlabs.io", "/v1/shared-voices"))
            query = urllib.parse.parse_qs(url.query)
            self.assertEqual(query["category"], ["high_quality"])
            page = int(query["page"][0])
            self.assertEqual(page, len(requests) - 1)
            return io.BytesIO(json.dumps({"voices": [{"voice_id": str(page), "name": "Voice", "language": "en",
                                                      "category": "high_quality", "gender": "male",
                                                      "preview_url": PREVIEW}], "has_more": page == 0}).encode())

        voices = fetch_catalog("test-read-key", Mock(open=open_page))
        self.assertEqual(len(requests), 2)
        self.assertEqual([v["id"] for v in voices], ["0", "1"])
        self.assertNotIn("test-read-key", json.dumps(voices))

    def test_no_key_makes_no_request(self):
        opener = Mock()
        with self.assertRaises(ValueError):
            fetch_catalog("", opener)
        opener.open.assert_not_called()

    def test_quality_is_not_inferred_from_descriptions(self):
        voice = {"voice_id": "one", "name": "Studio Quality", "language": "sv", "preview_url": SWEDISH,
                 "description": "The highest quality meditation voice"}
        for category in [None, "professional", "famous"]:
            self.assertEqual(preview_records(dict(voice, category=category)), [])

    def test_gender_uses_only_provider_metadata(self):
        self.assertEqual(voice_gender(" Female "), "female")
        self.assertEqual(voice_gender("MALE"), "male")
        self.assertEqual(voice_gender("neutral"), "neutral")
        for value in [None, "", "other", "unknown", 42]:
            self.assertIsNone(voice_gender(value))

    def test_partial_or_missing_preview_catalog_is_not_returned(self):
        for page in [{"voices": [], "has_more": True}, {"voices": [], "has_more": False}, {"voices": []}]:
            opener = Mock()
            opener.open.return_value = io.BytesIO(json.dumps(page).encode())
            with self.assertRaises(ValueError):
                fetch_catalog("test-read-key", opener)


if __name__ == "__main__":
    unittest.main()
