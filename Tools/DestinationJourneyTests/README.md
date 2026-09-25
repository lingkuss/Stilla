# Destination journeys: first playable place

Open **Din stilla resa → Borobudur** at the top of Vindla's home screen.
Choose 5, 10, 15 or 20 minutes, and **Guided** or **Fully silent**. The existing
Zen USDZ avatar breathes and responds to narration within a new dawn environment.
Guidance is bundled, translated into all six app languages, and spoken using the
existing on-device Apple voice pipeline. This path makes no generation request
and needs no Pro subscription. Other paid features retain their existing gates.

## Content and rendering

`Stilla/Resources/Journeys/destinations.json` is the versioned catalog. Each place
has a stable ID, localized location, explicit prerequisite, approximate destination
elevation above sea level, session count, scene asset, availability, optional
StoreKit product ID and milestone titles/crops. Catalog validation rejects duplicate
IDs, invalid thresholds/scales, backward/cyclic prerequisites and descending known
elevations. Array order is editorial; it is validated, not silently resorted.

Borobudur is the only playable environment. The other four are explicitly marked
coming soon. Completing seven sessions records Tiger's Nest as unlocked, while its
scene remains unavailable. No unfinished destination can be started or purchased.
Only available catalog entries contribute product IDs to StoreKit's product query.

To add a playable place:

1. Add an original/licensed environment image to Assets.xcassets.
2. Add its catalog entry in elevation order with an immutable ID and prerequisite.
3. Add its location/milestone copy in all six Localizable.strings files.
4. Mark it available after asset and flow QA. The catalog sheet supports selecting
   any accessible place, and the next action selects an available successor.
5. If direct paid access is desired, configure a non-consumable product in App
   Store Connect and the local StoreKit test file, then set its catalog productID.
   Local product configuration and end-to-end purchase testing remain required
   before shipping destination purchases; no live products were created here.

**This first scene is a hybrid:** original generated 2D environment with a live
RealityKit/Blender guide, not a traversable 3D reconstruction of Borobudur. Milestones
use restrained crop changes. The progress engine does not depend on this renderer;
a later 3D scene can replace it. Artistic interpretation is included in the scene's
VoiceOver label. No claim is made that depicted stairs match the physical monument.

## Progress and session rules

- One fully timed session credits one step, regardless of mode or chosen length.
- Stopping early saves meditation time but does not credit a destination step.
- Session UUIDs are persisted and deduplicated. Revisits never exceed the summit.
- Earned access and completion are persisted independently of catalog order.
- Buying grants access, not steps. Completing a purchased place unlocks its
  successor while skipped places remain incomplete. Verified StoreKit entitlements
  stay separate from earned access.
- Bad catalog/progress data fails closed and is not overwritten with empty progress.
- Fully silent sessions suppress narration, ambient audio, bells and breathing cues.
  Journey guidance uses voice alone. Persisted audio and haptic preferences are not
  changed by either mode.
- A monotonic clock reconciles the countdown after suspension. HealthKit time is
  capped to the session's elapsed duration, even after a late return to the app.
  Journey completion only writes to Health when permission was already granted;
  it never interrupts this flow with an unsolicited permission sheet.
- Force-quitting the app abandons an unfinished session; it does not grant a step.
  Already credited progress is persisted locally. Cross-device sync is not implemented.

## Verification

```sh
sh Tools/DestinationJourneyTests/run.sh
sh Tools/ZenSessionTests/run.sh
```

The first script checks actual bundled content, cancellation, both modes,
deduplication before and after serialization, summit boundaries, insertion of new
places, purchase access, clocks and real UserDefaults persistence/error handling.
The StoreKit stand-in in the storage test only supplies a set of entitlement IDs;
it does not replace native purchase verification in the app.

Debug-only launch flags:

- `--journey-preview` opens the destination experience.
- `--journey-test-short-session` uses an eight-second clock for UI completion QA.

Do not use the short-session flag for visual previews or real practice. Neither flag
is compiled into Release. Tests run in a dedicated **Vindla Journey QA** simulator.
Physical-device voice quality, lock-screen narration continuity, battery/thermal
behavior and production StoreKit purchases still require device/release QA.

## Elevation references

Elevations order the locations; they are not literal climbing distances or meditation counts.

- Borobudur site, approximately 265 m: https://www.smujo.id/biodiv/article/download/11782/6645/1077393
- Tiger's Nest, 3,120 m: https://tigersnestbhutan.com/
- Fuji, 3,776 m: https://route3776.jp/
- Kilimanjaro, 5,895 m: https://www.tanzaniaparks.go.tz/kilimanjaro
- Everest, 8,848.86 m: https://trade.ntb.gov.np/wp-content/uploads/2022/10/25.pdf

## Image provenance

Generated with the built-in ImageGen tool, then copied unchanged into
`Stilla/Assets.xcassets/JourneyBorobudur.imageset/borobudur.png`.
Original output: `exec-615c477c-54a3-4822-bab9-ebc43d8ba43e.png`.
No third-party photograph was copied. Final generation prompt:

> Use case: stylized-concept. Create one exquisite production background asset for the native iPhone meditation app Vindla. Portrait 1024x1536. NO UI, NO text, NO people or characters. A serene, spiritually resonant, architectural interpretation of BOROBUDUR temple in Java at first dawn. Recognizable low broad stepped square volcanic-stone terraces, circular upper terraces with latticed bell-shaped stupas and large central stupa, accurately inspired by Borobudur rather than generic East Asian pagodas. Camera near ground level on a quiet stone approach, centered gently ascending stairway leading toward the temple. Temple at upper-middle of canvas (roughly 22 to 49 percent height), tropical trees frame outside edges, soft distant misty hills, gentle luminous pale apricot sky. Foreground lower half is an uncluttered warm gray stone terrace receiving diffuse light from upper left, suitable for compositing a seated grey-robed meditation guide at center around 60 percent height. Extremely beautiful, art-directed premium 3D cinematic environment, tactile weathered basalt with restrained moss, pale gold sun rays, sage green vegetation, muted warm ivory highlights, atmospheric depth, softness without blur. Peaceful and grounded, spacious rather than busy. Bottom 20 percent shadowed warm stone. Avoid fantasy architecture, floating islands, oversized Buddha statues, lantern clutter, glowing magic, intense orange, tourists, modern objects, letters, logos, watermarks. This is an original artistic interpretation for a meditation environment, not a documentary photograph.

### Checked 2026-09-25

- Debug and Release simulator builds pass. Existing App Attest concurrency and
  notification/Live Activity deprecation warnings remain outside this change.
- Native iPhone UI: first-place entry, duration/mode selection, guided completion,
  silent completion, persisted step count, early stop without a step, and next action.
- A real five-minute silent countdown resumed in the same process after about
  90 seconds in the background, showing approximately 3:28 remaining. Ending it
  early retained the existing 3/7 steps.
- At maximum accessibility text size, duration choices become a two-column grid
  and meditation modes stack; the start button remains reachable by scrolling.
- Saved audio/haptic preferences compared unchanged before and after QA.
- Synthetic progress was cleared from the preview simulator, and the original
  avatar QA simulator's pre-test preferences were restored.
- Final reviewed screenshot: `output/destination-journey/borobudur-preview.png`,
  showing 0/7 steps on an iPhone 16e.
- Captures are in `output/destination-journey/`. The final preview has normal
  session lengths; completed-session QA used the explicit Debug-only short clock.
