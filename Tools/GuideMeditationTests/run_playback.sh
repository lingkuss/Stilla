#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-pause-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -D DEBUG -parse-as-library Stilla/Models/BreathingTechnique.swift Stilla/Models/ZenAvatarMotion.swift Stilla/Models/MeditationScript.swift Stilla/Services/ZenVoiceLibrary.swift Stilla/Services/ZenRecordedVoice.swift Tools/GuideMeditationTests/pause_playback.swift -o "$test_dir/checks"
"$test_dir/checks" "$PWD/Stilla/Resources/GuideMeditations/pause.m4a"
