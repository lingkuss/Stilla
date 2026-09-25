#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-destination-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc Stilla/Models/DestinationJourney.swift Tools/DestinationJourneyTests/main.swift -o "$test_dir/checks"
"$test_dir/checks"
swiftc -parse-as-library Stilla/Models/DestinationJourney.swift Stilla/Services/DestinationJourneyStore.swift Tools/DestinationJourneyTests/store_checks.swift -o "$test_dir/store-checks"
"$test_dir/store-checks"
