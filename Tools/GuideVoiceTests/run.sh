#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-guide-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library Stilla/Models/MeditationScript.swift Tools/GuideVoiceTests/main.swift -o "$test_dir/checks"
"$test_dir/checks"
