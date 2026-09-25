# Vindla: path to 1,000 users

Last updated: 2026-08-25

## Goal and measurement

- North star: 1,000 lifetime **First-Time Downloads** in App Store Connect.
- Baseline: 9 first-time downloads from launch on 2026-04-13 through 2026-08-24.
- Remaining: 991 new users.
- Working target date: 2026-11-16 (12 weeks).
- Required pace: 83 new users per week on average; aim for 100 per week by week 3.

The acquisition goal is an install, but the product goal is an activated user: someone who completes a meditation of at least one minute. Vindla intentionally avoids adding third-party tracking for now, so App Store Connect is the authoritative acquisition source and on-device session completion remains the activation definition.

## Current funnel

App Store Connect, trailing 90 days through 2026-08-24:

| Metric | Baseline |
| --- | ---: |
| Impressions | 105 |
| Product page views | 22 |
| First-time downloads | 5 |
| Reported daily-average conversion | 6.94% |
| Lifetime first-time downloads | 9 |
| App Store rating | Not enough ratings to display |

The primary problem is reach. Vindla has already produced paid conversions from a tiny user base, but almost nobody sees the product.

At a target 20% product-page conversion rate, 991 downloads require about 4,955 qualified product-page visits. At the current reported 6.94% conversion rate, the same result would require about 14,280 visits. We need both more qualified traffic and better social proof.

## Positioning

Primary audience: people who want to meditate but bounce off generic recordings—especially overthinkers and knowledge workers who need a short reset before a meeting, after a stressful day, or at bedtime.

Core promise:

> A meditation made for how you feel right now.

Reasons to believe:

- Mimir shapes a session around the user's mood, available time, and preferred guide.
- Eight distinct guide personalities make the experience feel less generic.
- Three personalized sessions are free each month and no account is required.
- Breathwork, sleep stories, soundscapes, reminders, Siri, and seven-day paths support repeat practice.
- Practice history stays on-device.

Avoid leading with a long feature list or the phrase “premium meditation.” Lead with the moment of use and the personalized outcome.

## Funnel changes shipped or prepared

- Live website now leads with the core outcome and has direct App Store CTAs.
- Mobile visitors get a persistent install CTA.
- A free one-minute 4–2–6 breathing tool gives visitors a useful first experience before asking for an install.
- The breathing tool now offers a native share/copy action after completion and uses a dedicated social-preview card, creating a no-login referral path before the App Store handoff.
- A public written Mimir preview now lets visitors combine three real-life moments with three guide styles before installing. All nine combinations are explicitly labeled as prewritten samples, shareable URLs restore the selected state, and the page preserves only the five approved Apple campaign buckets through the App Store handoff.
- Four search-focused, internally linked landing pages now answer the highest-intent use cases: personalized meditation, a three-minute work reset, personalized sleep stories, and an iPhone meditation timer.
- A fifth use-case page now serves the core overthinker audience with a complete two-minute browser practice at [`/meditation-for-overthinking`](https://vindla-three.vercel.app/meditation-for-overthinking). It preselects both Warm Guardian and Zen racing-thought previews, states the general-wellness boundary clearly, and keeps all install handoffs in Apple's measured `website` campaign through `overthinking_*` sources. Production deployment `dpl_6r65nAPFdBsKBy9jVbXfLS89Gj6M` was verified Ready on 2026-08-25; the live HTML matches the tested artifact, the sitemap includes the route, the install CTA resolves to `ct=website`, and the post-release error scan was clean.
- Website canonical, sitemap, visible FAQ, App Store smart banner, and metadata are aligned to the live domain.
- A spec-shaped public [`llms.txt`](https://vindla-three.vercel.app/llms.txt) now gives AI agents factual product, trust, use-case, and localization links. The homepage and localized pages advertise it with `rel="describedby"`, improving the agent-readiness signal used by NeuronFeed's listing score. Production deployment `dpl_9zdRfreGyZ5gai3nTYh8DCzBrJWn` was verified Ready on 2026-08-25 with no production error logs after release.
- Shared-session page now reaches the production API and includes both open-in-app and install paths.
- Production app share base now uses the live domain instead of the unregistered `vindla.app` domain.
- New-user onboarding is reduced from six screens to three, with a guide preselected.
- Native rating request is gated until three meaningful completed sessions and no more than once every 180 days/version.
- The strongest English palm, forest, and night screenshot set is intentionally shared by all six App Store localizations; 15 localized alternatives remain available for a future controlled test.
- Version 1.0.2 build 4 contains the app-side growth and localization changes and is **Waiting for Review**, with automatic release selected.
- Production deployment `dpl_8KZ53E57NJ3NczstX4CGDPAo3T2k` shipped the Mimir preview on 2026-08-25. The deployed HTML matches the tested local artifact byte-for-byte, the production alias is Ready, the creator-outreach handoff resolves to Apple's `ct=creator_outreach`, and the post-release error scan returned no logs.
- The tested website download router is live with Apple campaign attribution enabled and groups every handoff into one of five measurable acquisition buckets.
- The public press kit now provides the exact three current English App Store screenshots as direct full-resolution downloads, removing an email round trip for directories, newsletters, and creators.
- The live site is verified in Google Search Console. The sitemap submitted on 2026-08-25 has 15 successfully discovered URLs, including the Mimir preview and server-rendered Danish, French, Norwegian Bokmål, Spanish, and Swedish acquisition pages. The live sitemap now publishes a sixteenth URL for the new overthinking practice; discovery is not counted until Search Console confirms it.
- Each localized search page uses the same English palm, forest, and night App Store images, localized search copy, reciprocal hreflang tags, and attributed install CTAs.
- Apple’s editorial featuring nomination for 1.0.2 was submitted with five public demo links, all available regions, and all six localizations.
- Vindla was submitted to Indie App Catalog, ProjectRadar, AppRater, AI Tools Inc, NeuronFeed, ToolyHealth, Better Habits Hub, ListAI, AIReviewMarket, The Next AI, and Debut; the free one-minute reset was submitted to AppDirectory.org; and the free written Mimir preview was submitted to Web Apps Directory and public.tools. All fourteen are awaiting editorial review or curation. ProjectRadar also received founder context and permission to publish a public spotlight; its paid feedback upsell was declined. AppRater received the current English palm screenshot by public URL and an attributed `app_directories` handoff. AI Tools Inc received the public landing page through its free editorial lane; the 30–90 day queue was accepted and the $129 fast-track was declined. NeuronFeed accepted a factual AI-native product submission into its free human-review queue and promised an email decision within 48 hours. ToolyHealth received a non-medical submission in its Mindfulness & Meditation category and confirmed receipt for editorial review. Better Habits Hub received a free Meditation & Mindfulness submission whose outbound URL resolves to Apple's `app_directories` campaign token. ListAI received a free Chatbots & Assistants submission with the same measured handoff and a stated 24–48 hour review window. AIReviewMarket received a free freemium-app submission in its catch-all category, with factual non-medical copy, the measured handoff, and a stated 48-hour review window. The Next AI received a free Chatbots & GPTs submission with the attributed Apple handoff and a stated 24–48 hour review window; its $199 Featured option was declined. Debut received a free Health & Fitness / iOS submission with Apple's official icon, all three English App Store screenshots, and a `zuos.us` source on the measured handoff; admin review is pending. Web Apps Directory received a free Health & Fitness submission for the functional no-login Mimir browser preview, using `campaign=app_directories&source=webapps_directory`; on-page receipt confirmed entry into its standard human-review queue, stated as under four weeks. public.tools received the same fully free browser preview in Utilities through its accountless form, using `campaign=app_directories&source=public_tools`; Tally confirmed receipt.
- [FindUpApp published Vindla](https://findupapp.com/app/ios/6761864704) immediately from the US App Store feed on 2026-08-25, with the primary category Health & Fitness → Mental Health → Meditation, a related AI coach category, the current App Store screenshots, and related-app placement. Its public App Store button normalizes the submitted campaign URL to the plain store URL, so traffic from this listing must be measured by App Analytics web referrer rather than Apple's `ct=app_directories` token.
- The next native release now has a missing referral path covered: after completing a sleep story, users can share a localized free Mimir sleep preview instead of only saving or dismissing the completion screen. The link opens the no-account `sleep` + `guardian` preview and its install CTA resolves to Apple's approved `ct=website` campaign. All six localizations lint successfully and the full Vindla iOS simulator build passes.

## Verified 1.0.2 submission — 2026-08-25

A final App Store Connect audit and submission confirmed:

- Version 1.0.2 is **Waiting for Review** and will release automatically after approval.
- Build 4 is attached as the release candidate.
- Promotional Text, What's New, and keywords are localized in all six languages.
- Danish and Norwegian description corrections are saved.
- All five non-English storefront localizations intentionally inherit the English screenshot set.
- The new social-media age-rating questions were completed; the calculated rating is 9+.
- App Review contact information is complete.

The current verified acquisition baseline remains 9 lifetime first-time downloads through 2026-08-24.

## Twelve-week acquisition plan

### Weeks 1–2: ship and establish social proof

Target: 75 new users and the first 10 honest ratings.

1. Release 1.0.2.
2. Recruit 25–40 testers from existing personal and professional networks.
3. Ask testers for product feedback after their third session; let the native review prompt handle App Store ratings.
4. Publish a founder-led launch on Product Hunt, Indie Hackers, LinkedIn, and one relevant subreddit at a time. Follow each community's self-promotion rules.
5. Use the five broad App Store campaign links in `CAMPAIGN_TRACKING.md`; split a channel only after it clears Apple's five-download reporting threshold.

Go/no-go threshold: each launch surface should generate at least 10 qualified product-page visits or 3 downloads. Rewrite the hook once; stop investing if the second attempt also misses.

### Weeks 3–6: creator partnerships

Target: 400 new users.

1. Build a list of 100 small creators in meditation, sleep, ADHD/overthinking, productivity, and founder wellness. Prefer 5k–100k followers with consistent comments over large generic accounts.
2. Send 25 personalized messages per week. Offer a genuine product demo and free Pro access; do not require a positive review.
3. Give each creator a distinct campaign link and one concrete demo prompt, such as “I have three minutes before a difficult meeting.”
4. Reuse successful creator clips—with permission—on the Vindla site and social accounts.

Target funnel: 20 replies, 10 published demos, 40 downloads per published demo. If reply rate is below 10%, replace the outreach opener. If demo-to-install performance is below 10 downloads, change the demonstrated use case.

### Weeks 3–10: repeatable short-form content

Target: 250 new users.

Publish four useful pieces per week, not four ads:

- “One prompt, eight meditation personalities” comparisons.
- Short before-a-meeting, after-conflict, and bedtime use cases.
- A 30–60 second breathing exercise with the Vindla timer visible.
- Founder build notes and honest lessons from nine initial users.
- Shared Mimir passages that are evocative without making medical claims.

Every post gets one CTA: “Tell Mimir how you feel; get a meditation for this moment.” Send users through a channel-specific download path.

After eight posts, keep only formats that produce profile visits or App Store clicks. Do not optimize for views alone.

### Weeks 5–12: ASO and evergreen discovery

Target: 200 new users.

1. Keep localized App Store metadata and search landing pages while using the strongest English screenshot set consistently across all territories.
2. After traffic is high enough to produce a result, run a Product Page Optimization test on the first three screenshots: current English sequence versus one localized or alternate-copy treatment.
3. Build landing pages around real use cases: personalized meditation, three-minute work reset, sleep story generator, and meditation timer for iPhone.
4. Pitch curated iOS, wellness, and indie-app newsletters with a short demo GIF and the nine-user founder story.
5. Monitor the submitted App Store featuring nomination and respond promptly if Apple requests additional material.

## Weekly scoreboard

Update every Monday using a rolling seven-day comparison.

| Week of | Impressions | Page views | Downloads | Conversion | Ratings | Shares opened | Best channel |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 2026-08-24 |  |  |  |  |  |  |  |

Decision rules:

- Reach problem: fewer than 500 qualified impressions/week → increase distribution and creator outreach.
- Store problem: at least 100 page views but less than 15% conversion → test first screenshot, subtitle, and proof.
- Activation problem: repeated feedback says users do not reach a first session → simplify home CTA before adding features.
- Retention problem: users enjoy one session but do not return → improve the seven-day path and reminder timing.
- Referral problem: users share but recipients do not install → improve the shared-session preview and install handoff.

## Launch copy

### Product Hunt

Tagline:

> Meditation generated for how you feel right now

Short description:

> Vindla is an iPhone meditation app for people who find generic recordings hard to return to. Tell Mimir how you feel, choose your time and guide, and get a session shaped around this moment. It also includes breathwork, sleep stories, soundscapes, Siri shortcuts, and seven-day practice paths. No account required; free to start.

### Community post opener

> I built a meditation app because I kept wanting a session for a very specific moment—three minutes before a difficult meeting, a restless night, or a mind that would not slow down—and prerecorded libraries rarely matched it. Vindla turns a short mood prompt into a guided session and lets you choose the personality delivering it. I launched too quietly and only nine people found it, so I have rebuilt the first-run and sharing experience and would value blunt feedback on whether the core idea is genuinely useful.

### Creator outreach

> Hi [name] — I like how you talk about [specific topic]. I built Vindla, an iPhone app that turns a short description of how someone feels into a guided meditation in one of eight styles. Your audience's [specific use case] made me think a real-time demo could be useful: type “I have three minutes before a difficult meeting” and compare two guides. I can send Pro access if you want to try it. No obligation to post and no request for a positive review—honest feedback is more useful.

### App Store “What's New” for 1.0.2

> A calmer first session and sharing that finally works the way it should.
>
> • A shorter three-step welcome gets you into practice faster
> • Shared Mimir journeys now open on a reliable, redesigned web page
> • Vindla may ask for a rating only after you've completed several sessions
> • Share or rate Vindla anytime from Settings
> • Small reliability and presentation improvements throughout

## Immediate next actions

1. Monitor App Store Connect until 1.0.2 is approved and automatically released.
2. Recruit the first 25 testers and schedule the public launch posts for the approval window.
3. Share the one-minute breathing tool as a standalone useful resource; its App Store handoff is attributed to `breathing_tool`.
4. Use the written Mimir preview as the default creator handoff; it preserves the attributed `creator_outreach` campaign through the App Store CTA.
5. Monitor Search Console to see which of the 15 previously discovered URLs and five localized markets earns impressions first, and confirm discovery of the new overthinking practice as the sixteenth sitemap URL.
6. Monitor the fourteen submitted directory listings and publish their URLs when accepted; NeuronFeed, ListAI, AIReviewMarket, and The Next AI expect to respond by 2026-08-27.
7. Continue account-free app-directory submissions after 1.0.2 is live; keep signup-gated channels on hold until founder consent.
8. Send the first five deeply personalized creator pitches, using the attributed `creator_outreach` destination.

Execution materials:

- `APP_STORE_LOCALIZATIONS.md`: audited, limit-validated metadata for all six App Store languages, including the malformed English keyword fix and localized 1.0.2 release notes.
- `CAMPAIGN_TRACKING.md`: Apple-compliant campaign-link setup, initial aggregation strategy, reporting thresholds, and measurement table.
- `OUTREACH_QUEUE.md`: ranked first 25 submissions and creator pitches, with tailored angles and operating rules.
- `PRESS_KIT.md`: copy-ready product facts, founder story, demo prompts, coverage angles, and claims guidance.
- `APP_STORE_FEATURING_NOMINATION.md`: field-limit-aware Apple editorial nomination copy, supplemental URLs, and submission checklist.
- `MarketingAssets/AppStoreScreens/`: 15 dimension-validated localized alternatives retained for future testing; the submitted listing intentionally uses the English screenshot set in every locale.
