Environment configuration for app backend endpoints.

Committed files:
- Base.xcconfig
- Debug.xcconfig
- Release.xcconfig
- Staging.xcconfig

How it works:
- Xcode target `Vindla` uses `Debug.xcconfig` for Debug builds and `Release.xcconfig` for Release builds.
- `Info.plist` reads:
  - `KAIBackendURL` from `$(KAI_BACKEND_URL)`
  - `KAIShareBackendURL` from `$(KAI_SHARE_BACKEND_URL)`
  - `KAIShareWebBaseURL` from `$(KAI_SHARE_WEB_BASE_URL)`
  - `KAIAttestBaseURL` from `$(KAI_ATTEST_BASE_URL)`

Local overrides (ignored by git):
- `Config/Debug.local.xcconfig`
- `Config/Release.local.xcconfig`
- `Config/Staging.local.xcconfig`

CI overrides (ignored by git):
- `Config/Debug.ci.xcconfig`
- `Config/Release.ci.xcconfig`
- `Config/Staging.ci.xcconfig`

Example override file:
```
// Use https:/$()/... in xcconfig (plain https:// is parsed as a comment)
KAI_BACKEND_URL = https:/$()/your-env.vercel.app/kai/generate
KAI_SHARE_BACKEND_URL = https:/$()/your-env.vercel.app/kai/share
KAI_SHARE_WEB_BASE_URL = https:/$()/your-web-domain
KAI_ATTEST_BASE_URL = https:/$()/your-env.vercel.app/attest
```
