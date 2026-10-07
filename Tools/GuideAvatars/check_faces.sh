#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-face-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library Stilla/Models/BreathingTechnique.swift Stilla/Models/ZenAvatarMotion.swift Stilla/Models/MeditationScript.swift Stilla/Services/ZenVoiceLibrary.swift Stilla/Services/ZenRecordedVoice.swift Tools/GuideAvatars/verify_lip_sync.swift -o "$test_dir/checks"
"$test_dir/checks"
swift Tools/GuideAvatars/verify_face_motion.swift
