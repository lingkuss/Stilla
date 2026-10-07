#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-meditation-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -D DEBUG -parse-as-library Stilla/Models/MeditationScript.swift Stilla/Services/GuideMeditationLibrary.swift Tools/GuideMeditationTests/main.swift -o "$test_dir/checks"
mkdir -p "$test_dir/GuideMeditations"
cp Stilla/Resources/GuideMeditations/catalog.json "$test_dir/GuideMeditations/"
if [ "${1:-}" = "--recordings" ]; then
    cp Stilla/Resources/GuideMeditations/*.m4a Stilla/Resources/GuideMeditations/audio.json "$test_dir/GuideMeditations/"
fi
"$test_dir/checks" "$@"
