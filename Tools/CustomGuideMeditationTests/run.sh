#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d /tmp/vindla-custom-guide-checks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
node --input-type=module - "$test_dir/plan.json" <<'JS'
import {writeFileSync} from 'node:fs';
import {validatePlan,cueIDs,durations} from './backend/kai-proxy/guide-meditations.js';
const raw={cues:cueIDs.map(id=>({id,text:`Cue ${id}: Notice the support beneath your body and let the breath move naturally.`})),sessions:durations.map(minutes=>({minutes,title:`Practice ${minutes}`,summary:'A gentle practice.'}))};
writeFileSync(process.argv[2],JSON.stringify(validatePlan(raw,{guideID:'custom-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',language:'sv',voiceID:'testVoice123456789012'},'b'.repeat(64))));
JS
swiftc -parse-as-library Stilla/Models/MeditationScript.swift Stilla/Models/CustomGuideDraft.swift Stilla/Services/CustomGuideMeditations.swift Tools/CustomGuideMeditationTests/main.swift -o "$test_dir/checks"
"$test_dir/checks" "$test_dir/plan.json"
