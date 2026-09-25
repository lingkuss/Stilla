# Vindla App Store metadata for 1.0.2

Prepared and validated: 2026-08-24; submitted: 2026-08-25

This is the source-of-truth metadata package for version 1.0.2. The localized metadata was saved in App Store Connect and build 4 was submitted on 2026-08-25. The version is **Waiting for Review** with automatic release selected.

## Audit result

The prepared 1.0.2 listing already has six complete localizations: English (U.K.), Danish, French, Norwegian, Spanish (Spain), and Swedish. The current public 1.0.1 page can still fall back to English in Denmark and Norway; the localized version metadata will not become public until 1.0.2 is released.

| Finding | Impact | Action |
| --- | --- | --- |
| The English keyword field contains 12 hidden `U+200B` zero-width spaces | They consume 12 positions in App Store Connect's field counter and make the raw string 120 UTF-8 bytes despite Apple's documented 100-byte limit | Replace the whole field with the clean 90-byte value below |
| Promotional Text is empty in all six languages | The listing lacks a changeable, outcome-led message above the description | Add the localized text below |
| What's New is empty in all six languages | 1.0.2 has no user-facing release story yet | Add the localized notes below |
| Danish contains `reflekser` and `premiuminhold` | Both are copy errors | Use `refleksioner` and `premiumindhold` |
| Norwegian contains `dype praksisen` | The phrase is unnatural | Use `fordype praksisen` |

Apple's current limits are 30 characters for the subtitle, 170 for Promotional Text, and 100 bytes for keywords. The values below stay within all three limits and use keywords longer than two characters.

## Field validation

| Localization | Subtitle characters | Keyword bytes | Promotional Text characters |
| --- | ---: | ---: | ---: |
| English (U.K.) | 26 / 30 | 90 / 100 | 162 / 170 |
| Danish | 23 / 30 | 92 / 100 | 152 / 170 |
| French | 27 / 30 | 91 / 100 | 165 / 170 |
| Norwegian | 23 / 30 | 85 / 100 | 155 / 170 |
| Spanish (Spain) | 27 / 30 | 92 / 100 | 168 / 170 |
| Swedish | 23 / 30 | 90 / 100 | 157 / 170 |

## English (U.K.)

Subtitle — keep:

```text
Personalized AI Meditation
```

Keywords — replace the entire existing field:

```text
mindfulness,breathing,breathwork,focus,stress,anxiety,calm,relax,sleep,timer,wellness,siri
```

Promotional Text:

```text
Tell Mimir how you feel and get a meditation shaped around this moment. Choose from eight guide styles, then add breathwork, sleep stories, soundscapes, and Siri.
```

What's New:

```text
A calmer first session and sharing that finally works the way it should.

• A shorter three-step welcome gets you into practice faster
• Shared Mimir journeys now open on a reliable, redesigned web page
• Vindla may ask for a rating only after you've completed several sessions
• Share or rate Vindla anytime from Settings
• Small reliability and presentation improvements throughout
```

## Danish

Subtitle — keep:

```text
Personlig AI-meditation
```

Keywords:

```text
mindfulness,åndedræt,vejrtrækning,fokus,stress,angst,velvære,afslapning,søvn,timer,siri
```

Promotional Text:

```text
Fortæl Mimir, hvordan du har det, og få en meditation skabt til øjeblikket. Vælg mellem otte guidestile, åndedræt, søvnhistorier, lydlandskaber og Siri.
```

What's New:

```text
En roligere første session og deling, der nu fungerer, som den skal.

• En kortere velkomst i tre trin får dig hurtigere i gang
• Delte Mimir-rejser åbner nu på en stabil, ny webside
• Vindla kan først bede om en vurdering, når du har gennemført flere sessioner
• Del eller bedøm Vindla når som helst under Indstillinger
• Små forbedringer af stabilitet og præsentation
```

Description corrections:

- Replace `Start hurtige timer-baserede meditationer` with `Start hurtige, timerbaserede meditationer`.
- Replace `Vælg baggrundslyde og balance for stilhed` with `Vælg baggrundslyde og balancen mellem lyd og stilhed`.
- Replace `Spor streaks og samlet meditationstid` with `Følg serier og samlet meditationstid`.
- Replace `seneste reflekser` with `seneste refleksioner`.
- Replace `premiuminhold` with `premiumindhold`.

## French

Subtitle — keep:

```text
Méditation AI personnalisée
```

Keywords:

```text
pleine conscience,respiration,souffle,stress,anxiété,calme,détente,sommeil,minuteur,siri
```

Promotional Text:

```text
Dites à Mimir comment vous vous sentez et recevez une méditation pour l’instant présent. Huit styles de guide, respiration, histoires pour dormir, ambiances et Siri.
```

What's New:

```text
Une première séance plus sereine et un partage qui fonctionne enfin comme prévu.

• Un accueil raccourci à trois étapes pour commencer plus vite
• Les voyages Mimir partagés s’ouvrent désormais sur une page web fiable et repensée
• Vindla ne peut demander une note qu’après plusieurs séances terminées
• Partagez ou notez Vindla à tout moment depuis les Réglages
• De petites améliorations de fiabilité et de présentation
```

## Norwegian

Subtitle — keep:

```text
Personlig AI-meditasjon
```

Keywords:

```text
mindfulness,pust,pusteøvelse,fokus,stress,angst,velvære,avslapning,søvn,timer,siri
```

Promotional Text:

```text
Fortell Mimir hvordan du har det, og få en meditasjon laget for øyeblikket. Velg mellom åtte guidestiler, pusteøvelser, søvnhistorier, lydlandskap og Siri.
```

What's New:

```text
En roligere første økt og deling som nå fungerer slik den skal.

• En kortere velkomst i tre trinn får deg raskere i gang
• Delte Mimir-reiser åpnes nå på en stabil, ny nettside
• Vindla kan først be om en vurdering etter at du har fullført flere økter
• Del eller vurder Vindla når som helst fra Innstillinger
• Små forbedringer i stabilitet og presentasjon
```

Description corrections:

- Replace `Reflekter etter øktene for å dype praksisen din` with `Reflekter etter øktene for å fordype praksisen din`.
- Replace `Spor streaks og total meditasjonstid` with `Følg serier og total meditasjonstid`.

## Spanish (Spain)

Subtitle — keep:

```text
Meditación AI personalizada
```

Keywords:

```text
mindfulness,respiración,enfoque,estrés,ansiedad,calma,relajación,sueño,temporizador,siri
```

Promotional Text:

```text
Cuéntale a Mimir cómo te sientes y recibe una meditación creada para este momento. Elige entre ocho estilos de guía, respiración, cuentos para dormir, ambientes y Siri.
```

What's New:

```text
Una primera sesión más tranquila y una forma de compartir que por fin funciona como debe.

• Una bienvenida más breve, en tres pasos, para empezar antes
• Los viajes de Mimir compartidos ahora se abren en una página web fiable y renovada
• Vindla solo puede pedir una valoración después de completar varias sesiones
• Comparte o valora Vindla en cualquier momento desde Ajustes
• Pequeñas mejoras de fiabilidad y presentación
```

## Swedish

Subtitle — keep:

```text
Personlig AI-meditation
```

Keywords:

```text
mindfulness,andning,andningsövning,fokus,stress,ångest,lugn,avslappning,sömn,timer,siri
```

Promotional Text:

```text
Berätta för Mimir hur du mår och få en meditation skapad för stunden. Välj mellan åtta guidestilar, andningsövningar, sömnberättelser, ljudlandskap och Siri.
```

What's New:

```text
En lugnare första session och delning som nu fungerar som den ska.

• En kortare välkomstguide i tre steg tar dig snabbare till övningen
• Delade Mimir-resor öppnas nu på en stabil, ny webbsida
• Vindla kan be om ett betyg först efter att du har slutfört flera sessioner
• Dela eller betygsätt Vindla när som helst under Inställningar
• Små förbättringar av stabilitet och presentation
```

## Screenshot policy

All six App Store localizations intentionally use the English screenshot set. This keeps the strongest palm/beach, sunlit forest, and moonlit night compositions consistent across territories while the searchable metadata, promotional text, release notes, and app UI remain localized.

Do not add more screenshots merely to fill the ten available slots. Preserve the English listing's current sequence. Five localized alternatives were rendered and visually reviewed on 2026-08-25 under `MarketingAssets/AppStoreScreens/`, but they were not uploaded and are retained only for a future controlled test. The founder-owned originals in `AppStoreAssets/` were not modified.

| Position | English message | Danish | Norwegian | Swedish | French | Spanish |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | Meditation, shaped around you | Meditation, skabt til dig | Meditasjon, formet for deg | Meditation, formad efter dig | Une méditation faite pour vous | Meditación hecha a tu medida |
| 2 | Soundscapes for deeper calm | Lydlandskaber til dybere ro | Lydlandskap for dypere ro | Ljudlandskap för djupare lugn | Des ambiances pour un calme profond | Sonidos para una calma más profunda |
| 3 | Drift into personalized sleep stories | Fald i søvn til personlige historier | Sov inn med personlige søvnhistorier | Somna till personliga sömnberättelser | Endormez-vous avec une histoire personnalisée | Duerme con historias personalizadas |

The unused alternatives keep the palm, forest, and night photographic backgrounds consistent while localizing the marketing copy and phone UI. All 15 alternative PNGs are 1242 × 2688 RGB images and have a combined review sheet at `MarketingAssets/AppStoreScreens/localized-contact-sheet.png`.

After 1.0.2 is live, use Product Page Optimization to test this outcome-led sequence against the current feature-led sequence. Do not change the subtitle and screenshots in the same test; otherwise the result will not identify which change caused the lift.

## Submission record

1. The clean English keyword field and all localized keyword sets were saved.
2. Promotional Text and What's New were saved in all six localizations.
3. The Danish and Norwegian description corrections were saved.
4. Danish, French, Norwegian Bokmål, Spanish, and Swedish inherit the English media set.
5. Build 4 was selected; the new age-rating questions and App Review contact fields were completed.
6. Every localization was reviewed and version 1.0.2 was submitted. Current state: **Waiting for Review**.

References:

- Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information
- Apple field limits: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Apple version metadata: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Apple screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
