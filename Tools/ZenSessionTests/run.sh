#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-local-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -D DEBUG -parse-as-library \
    Stilla/Models/ZenSessionRequest.swift \
    Stilla/Models/MeditationScript.swift \
    Stilla/Models/SessionMemory.swift \
    Stilla/Services/KaiBrainService.swift \
    Stilla/Services/LocalGenerationFixtures.swift \
    Stilla/Services/ZenVoiceLibrary.swift \
    Tools/ZenSessionTests/main.swift \
    -o "$test_dir/checks"
cp -R Stilla/en.lproj "$test_dir/en.lproj"
cp -R Stilla/Resources/ZenVoice "$test_dir/ZenVoice"
"$test_dir/checks"
