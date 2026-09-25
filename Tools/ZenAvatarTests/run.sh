#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-avatar-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc Stilla/Models/BreathingTechnique.swift Stilla/Models/ZenAvatarMotion.swift Tools/ZenAvatarTests/main.swift -o "$test_dir/checks"
"$test_dir/checks"

swift Tools/ZenAvatarTests/verify_deformation.swift
