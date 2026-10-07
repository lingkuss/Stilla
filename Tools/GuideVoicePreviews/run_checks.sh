#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 -m unittest discover -s Tools/GuideVoicePreviews -p 'test_*.py'
voice_checks_dir=$(mktemp -d /tmp/vindla-voice-checks.XXXXXX)
trap 'rm -rf "$voice_checks_dir"' EXIT
xcrun swiftc Stilla/Models/CustomGuideDraft.swift Stilla/Services/CustomGuideVoiceCatalog.swift \
  Tools/GuideVoicePreviews/main.swift -o "$voice_checks_dir/checks"
"$voice_checks_dir/checks" Stilla/Resources/guide-voice-previews.json
