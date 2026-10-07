# Custom guide images

Run `sh Tools/GuideImageTests/run.sh` from the repository root. Checks cover
backward-compatible loading of voice drafts, saving the generated PNG unchanged,
and rejecting opaque, fully empty or corrupt image results. Also covers completed
guide persistence, multiple guides, idempotent save retries, preservation of a
corrupt catalogue, and regenerating only when the reference or appearance changes.

Run `node --test guide-images.test.js` in `backend/kai-proxy` for HTTP authorization,
reference upload, fixed Sunburst settings, input limits, concurrency, rate limiting
and provider failure handling.

The device experiment generates one transparent 1024 × 1024 PNG at medium quality,
from an appearance description, a reference image, or both. The single Create
action saves the finished guide and selects it in the mountain guide carousel.
Each guide keeps its original PNG and creation brief (including reference image)
in Application Support/GuideCreator/Guides. The catalogue is published atomically
after these files are saved. An existing image-only draft can be added without
another image request. Voice synthesis is still a separate feature; this change
adds local guide identity and artwork. API keys are only used by the backend. Simulator App Attest is unsupported;
end-to-end simulator tests can use the existing Debug-only `KAIBackendToken` hook
with a temporary, short-lived app token in a disposable simulator bundle. Never
put a provider key or long-lived token in an app bundle.
