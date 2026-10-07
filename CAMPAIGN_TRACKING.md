# Vindla App Store campaign attribution

Prepared: 2026-08-24; production attribution activated: 2026-08-25

## What is and is not measured today

The website sends each App Store handoff through a URL such as `/download?source=breathing_complete`. The production router converts those source labels into Apple campaign attribution.

Apple requires both a provider token (`pt`) and campaign token (`ct`) in the final App Store URL. A valid link has this shape:

```text
https://apps.apple.com/app/apple-store/id6761864704?pt=PROVIDER_TOKEN&ct=CAMPAIGN_TOKEN&mt=8
```

Apple campaign attribution is now installed for the five broad acquisition buckets below. App Store Connect will expose a campaign only after it reaches Apple's reporting threshold.

## Campaign router live

The website has a tested `/download` campaign router in `website/api/download.js`, deployed at `https://vindla-three.vercel.app/download`. It maps existing `source` values into the five broad campaigns below and falls back to the ordinary App Store URL if no valid provider token is configured. This prevents a missing token from breaking downloads.

Production has `APPLE_PROVIDER_TOKEN` configured in Vercel and was redeployed on 2026-08-25. All five destinations were verified to return an HTTP 302 to an Apple URL containing the expected `pt`, `ct`, and `mt=8` values. The provider token remains outside the repository.

## Attribution setup record

Completed in App Store Connect and Vercel on 2026-08-25:

1. Open Vindla → Analytics → Acquisition → Campaigns.
2. Select `+` and create the campaign `website`.
3. Copy the generated campaign link.
4. Copy the numeric `pt` value from the generated URL and provide it for the `APPLE_PROVIDER_TOKEN` production environment variable. The provider token appears in public campaign URLs and is not a password.

Once the first link exists, reuse its `pt` value and change only `ct` for subsequent campaigns.

Existing website sources are grouped automatically. External launch and outreach links can use a broad campaign explicitly, for example `/download?campaign=founder_launch&source=product_hunt`.

## Initial campaign set

Do not create a unique campaign for every button yet. Apple withholds campaign metrics until a campaign reaches at least five first-time downloads, so excessive segmentation would hide the signal. Start with five broad campaigns:

| Campaign token | Use for | Current website sources grouped into it |
| --- | --- | --- |
| `website` | Homepage, press kit, written Mimir preview, personalized meditation, overthinking practice, sleep stories, and timer pages | `nav`, `hero`, `final_cta`, `mimir_preview_*`, `personalized_*`, `overthinking_*`, `sleep_*`, `timer_*`, `press_*` |
| `breathing_tool` | The free one-minute exercise and three-minute reset | `breathing_*`, `work_reset_*` |
| `app_directories` | Indie App Catalog, Indie Watch, AppRater, Taplist, AppSwap, App Lottery, Web Apps Directory, public.tools | External directory links and attributed browser-preview listings |
| `creator_outreach` | Wellness, meditation, productivity, and founder-wellness pitches | External creator/newsletter links |
| `founder_launch` | Product Hunt, Show HN, Indie Hackers, LinkedIn, and founder-network sharing | Coordinated launch links |

All names are within Apple's 30-character campaign-token limit.

FindUpApp is the current attribution exception: its registration accepted an `app_directories` campaign URL, but the published listing normalized the App Store button to the plain US store URL. Measure `findupapp.com` through App Analytics web-referrer reporting rather than Apple's campaign-token report.

The native sleep-story completion share points to `/try-mimir?need=sleep&guide=guardian&campaign=website&ref=share`. The preview restores that state and its result CTA uses `/download?campaign=website&source=mimir_preview_result`, which resolves to Apple's `ct=website` token without adding another low-volume campaign bucket.

The crawlable overthinking practice defaults to `/download?campaign=website&source=overthinking_*` for direct installs and links to a preselected racing-thought Mimir preview. When an approved broad campaign such as `creator_outreach` arrives in the page URL, the page preserves it across both direct App Store links and the preview handoff; unsupported campaign values fall back to `website`.

## When to split a campaign

Split only after a broad campaign proves it can exceed the reporting threshold:

- At 10 or more first-time downloads from `app_directories`, create separate tokens for the two strongest directories.
- At 10 or more from `creator_outreach`, split by audience: `creator_meditation`, `creator_productivity`, and `creator_sleep`.
- Give Product Hunt its own token only when a launch date is scheduled and a coordinated traffic spike is expected.

## Measurement cadence

Apple says campaign data appears after at least 24 hours and five first-time downloads from the campaign. Check at 24 hours, 72 hours, and seven days; do not interpret a blank campaign row as zero before the privacy threshold is met.

Record for each campaign:

| Campaign | Start date | Product page views | First-time downloads | Conversion | Pro starts | Decision |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `website` |  |  |  |  |  |  |
| `breathing_tool` |  |  |  |  |  |  |
| `app_directories` |  |  |  |  |  |  |
| `creator_outreach` |  |  |  |  |  |  |
| `founder_launch` |  |  |  |  |  |  |

Decision rules:

- Fewer than five downloads after 100 product-page views: pause the campaign and change the App Store promise or screenshot sequence.
- At least 15% product-page conversion: keep the listing stable and increase qualified traffic.
- At least 10 downloads from a channel: split the next batch so the best prospect type becomes visible.
- Paid conversion without retention evidence: keep the acquisition test small until activation feedback is collected.

Reference: https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links
