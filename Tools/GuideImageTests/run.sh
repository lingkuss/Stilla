#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-guide-image-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library Stilla/Models/MeditationScript.swift Stilla/Models/CustomGuideDraft.swift Stilla/Services/CustomGuideImageGenerator.swift Tools/GuideImageTests/main.swift -o "$test_dir/checks"
"$test_dir/checks"
