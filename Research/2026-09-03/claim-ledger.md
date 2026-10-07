# Claim ledger — Vindla användarbehov 2026-09-03

Åtkomstdatum för samtliga externa källor: 2026-09-03. Datum utan årtal återges exakt som App Store visar dem; inget årtal har antagits. En käll-URL räknas som en oberoende signal även om flera personer kommenterar där.

| Källa | Publiceringsdatum | Direktlänk | Typ / åtkomstnotering | Korrekt kort återgivning | Betalningsklass |
|---|---|---|---|---|---|
| Reddit, r/QuantifiedSelf, “Meditation bell/timer app/website” | 2026-03-09 | https://www.reddit.com/r/QuantifiedSelf/comments/1rpc0ts/meditation_bell_timer_app_website/ | Förstahandskommentar; direkt sida | Vill ha timvis signal inom eget tidsfönster som fortsätter över dagar utan återstart och säger att hen skulle köpa den | Explicit framtida betalningsvilja |
| App Store, Lotus Bud, recension | “Jun 23”, inget årtal på sidan | https://apps.apple.com/us/app/lotus-bud-mindfulness-bell/id502329366 | Förstahandsrecension; direkt sida | Slumpmässiga milda signaler är precis vad praktiken behövde; nämner valfritt köp för egna meddelanden men säger inte att det köptes | Behovssignal; ingen bekräftad betalning |
| App Store, Lotus Bud, recension | 2024-09-28 | https://apps.apple.com/us/app/lotus-bud-mindfulness-bell/id502329366 | Förstahandsrecension; samma URL som föregående, därför inte extra oberoende källa | Vill ha tysta timmar och tydlig kontroll över frekvens | Behovssignal |
| Reddit, r/Headspace, “Looking for people who want to join Headspace” | 2025-09-01; kommentarer till 2026-04-04 | https://www.reddit.com/r/Headspace/comments/1n60wjs/looking_for_people_who_want_to_join_headspace/ | Flera förstahandskommentarer i en tråd; räknas som en källa; betalning kan inte verifieras utanför tråden | Familjeplansplatser erbjuds/fylls och deltagare frågar aktivt om pris/tillgänglighet | Stark betalproxy |
| App Store, New Horizon, recension | 2022-03-31 | https://apps.apple.com/us/app/new-horizon-sleep-meditations/id1457179117?platform=iphone&see-all=reviews | Förstahandsrecension; gammal | Överväger full prenumeration men avstår eftersom äldre barn inte kan använda den på egna enheter | Explicit villkorad framtida betalningsvilja |
| App Store, Othership, recension | 2025-10-11 | https://apps.apple.com/us/app/othership-guided-breathwork/id1590348936 | Förstahandsrecension; direkt sida | Långvarig betalande användare förlorade åtkomst vid ny telefon trots återstående tid och sade upp; senare löst av support | Stark proxy: betald friktion och churn |
| App Store, Beginning, recension | 2021-01-04 | https://apps.apple.com/us/app/beginning-sleep-meditation/id1166940722 | Förstahandsrecension; mycket gammal | Beskriver upprepade återställningar och förlorad progression efter betalning | Explicit historisk betalförlust |
| Reddit, r/InsightTimer, “Phone calls and Do Not Disturb” | 2026-07-11 | https://www.reddit.com/r/InsightTimer/comments/1utl8ya/phone_calls_and_do_not_disturb/ | Förstahandsinlägg; direkt sida | Okänt samtal pausar timern trots Stör ej och bryter meditationen | Behovssignal; ingen betalning |
| Reddit, r/googleplayconsole, MTimer-tråd | 2026-06-10 | https://www.reddit.com/r/googleplayconsole/comments/1u1tlwd/developed_a_meditation_tracking_app_for_free/ | Förstahandskommentar från användare i byggartråd; appen anges som gratis | Start-/slutklocka tystas av telefonläge; native-hantering efterfrågas och rättas | Behovssignal; ingen betalning |
| App Store, Transcendental Meditation, recension | 2025-06-30 | https://apps.apple.com/us/app/transcendental-meditation/id1535029280?platform=ipad&see-all=reviews | Förstahandsrecension; direkt sida | Använder reservtimer när slutklockan ibland uteblir och önskar automatisk Stör ej | Behovssignal; ingen funktionsspecifik betalning |
| Reddit, r/breathwork, “best meditation or breathwork app” | 2024-09-24; kommentarer till 2026-02-21 | https://www.reddit.com/r/breathwork/comments/1fo853q/the_best_meditation_or_breathwork_app_on_iphone/ | Flera förstahandskommentarer i en tråd; räknas som en källa | Vill ha prisvärd haptisk pacing utan skärm; kommentarer nämner slutna ögon och gratis/engångspris | Behov + prismodellintresse, ej köp |
| App Store, Aer, recensioner | “Feb 21” och “Mar 22”, inget årtal på sidan | https://apps.apple.com/us/app/breathing-meditation-aer/id6755346853 | Förstahandsrecensioner; appfunktioner verifierades separat men leverantörstext används inte som behovsbevis | Två användare beskriver appen som prisvärd/värd pengarna; orsaken kan inte isoleras till haptik | Explicit appnivåbetalning; funktionskausalitet okänd |

## Intern produktverifiering

| Påstående | Evidens |
|---|---|
| Alla konfigurerade köp och abonnemang är inte familjedelbara | [Products.storekit](/Users/elias/dev/vindla/Products.storekit:22), [Products.storekit](/Users/elias/dev/vindla/Products.storekit:37), [Products.storekit](/Users/elias/dev/vindla/Products.storekit:52), [Products.storekit](/Users/elias/dev/vindla/Products.storekit:135) |
| Historik och sparade meditationer lagras lokalt | [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:147), [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:219) |
| Den hittade iCloud KVS-användningen gäller små servicevärden, inte användarbiblioteket | [KaiBrainService.swift](/Users/elias/dev/vindla/Stilla/Services/KaiBrainService.swift:82), [KaiBrainService.swift](/Users/elias/dev/vindla/Stilla/Services/KaiBrainService.swift:102) |
| Haptisk andningspacing finns redan | [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:46), [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:462) |

## Motsägelser och begränsningar

- Mikropauskällorna stödjer både nyttan med milda signaler och risken att de stör utan tysta tider/frekvenskontroll.
- Aer-recensionerna stödjer betalvärde för hela appen, inte specifikt haptik.
- Othership-händelsen löstes av support; den visar smärta/churnrisk men inte ett permanent produktfel.
- Äldre 2021–2022-källor får endast stödja, aldrig ensamma avgöra, prioriteringen.
- Leverantörstexter, utvecklares självmarknadsföring, sökträffssnuttar utan direkt kontroll och aggregerade ratingtal har inte använts som fristående användarbevis.
