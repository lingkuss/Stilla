"""Guard the language-reference boundary without loading any models."""
import tempfile
import unittest
from pathlib import Path
from generate import load_references


class ReferenceTests(unittest.TestCase):
    def test_requires_distinct_explicit_references(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / "sv.wav").write_bytes(b"swedish recording")
            (base / "en.wav").write_bytes(b"english recording")
            profile = {"references": {lang: {"language": lang, "file": f"{lang}.wav"}
                                      for lang in ("sv", "en")}}
            references = load_references(profile, base)
            self.assertNotEqual(references["sv"]["sha256"], references["en"]["sha256"])
            profile["references"]["sv"]["file"] = "en.wav"
            with self.assertRaises(ValueError):
                load_references(profile, base)
            profile["references"]["sv"]["language"] = "en"
            with self.assertRaises(ValueError):
                load_references(profile, base)
            del profile["references"]["sv"]
            with self.assertRaises(ValueError):
                load_references(profile, base)


if __name__ == "__main__":
    unittest.main()
