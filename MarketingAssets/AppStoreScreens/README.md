# Localized App Store screenshots

Generated from the same three photographic scene concepts used by the live English listing: tropical palms and beach, sunlit forest, and moonlit night. The founder-owned originals in `AppStoreAssets/` were not modified.

The three photographic backgrounds under `Backgrounds/` are shared across every locale. The marketing headline, supporting line, and in-app phone UI are localized for Danish (`da`), French (`fr`), Norwegian Bokmål (`nb`), Spanish (`es`), and Swedish (`sv`). Clean locale-specific phone captures live under `LocalizedUICaptures/`.

Run from the repository root:

```sh
python3 MarketingAssets/generate_localized_app_store_screens.py
```

Each locale folder contains three 1242 × 2688 RGB PNGs in the English listing's order—palm, forest, night—and a review contact sheet. The localized runtime captures are 1320 × 2868 PNGs. Superseded abstract drafts are retained under `LegacyAbstractDrafts/`. Nothing in this folder has been uploaded to App Store Connect.
