# Vindla användarbehov — 3 september 2026

**Mottagare:** produktbeslut för Vindla

**Fråga:** Vilka nya, återkommande och betalbara problem passar Vindlas löfte?

**Underlag:** aktuella förstahandsberättelser från Reddit och App Store, kontrollerade mot Vindlas kod och betalprodukter. En oberoende signal räknas per käll-URL; flera kommentarer i samma tråd räknas inte som flera källor.

## Beslut i korthet

Bygg ingen ny större funktion på dagens underlag. Det mest lovande att **validera** är en frivillig, diskret mikropaus-signal under dagen: en användare säger uttryckligen att hen skulle köpa en klocka som fortsätter på valda dagar och tider utan att behöva startas om, och en annan beskriver slumpmässiga, milda signaler som precis det hen behövde. Underlaget är dock bara två oberoende förstahandskällor, och samma källmaterial visar att fel frekvens eller saknade tysta tider snabbt blir störande. Det räcker för ett litet test, inte för implementation.

Familjeåtkomst och trygg kontinuitet vid telefonbyte har tydligare koppling till redan betalda abonnemang, men större ekonomisk respektive teknisk risk. Störningssäkra sessioner är ett trovärdigt kvalitetsproblem utan funnen betalningssignal. Haptisk andningsguidning är redan byggd i Vindla och bör behandlas som upptäckbarhet/UX, inte som en ny funktion.

## Vad som faktiskt är nytt sedan tidigare körningar

Tidigare körningar täckte sömnläge, inlärd personalisering, snabbstart, uppspelning/offline, skuldfri progression, röstförtroende, enminutsstart, Apple Watch, ägande/livstidspris, mindre prat, friktionsfritt sessionsslut, återupptagning, nästa rekommendation, sekulär trovärdighet och färdighetsprogression. Följande fem områden är nya i den återställda forskningshistoriken.

### 1. En signal som återkommer under dagen utan daglig omstart

- **9 mars 2026 — explicit framtida betalningsvilja.** En användare efterfrågar en meditationsklocka som går varje timme inom ett valt tidsfönster, fortsätter kommande dagar och säger uttryckligen att hen skulle köpa den; smärtan är att annars behöva komma ihåg att aktivera den varje dag. [Reddit: Meditation bell/timer app/website](https://www.reddit.com/r/QuantifiedSelf/comments/1rpc0ts/meditation_bell_timer_app_website/)
- **23 juni, årtal visas inte på sidan — behovssignal, betalning inte bekräftad.** En App Store-recensent beskriver milda signaler vid slumpmässiga tidpunkter som precis vad praktiken behövde och nämner att egna meddelanden finns som ett valfritt köp för 5 USD. Recensionen säger inte att köpet genomfördes. [App Store: Lotus Bud](https://apps.apple.com/us/app/lotus-bud-mindfulness-bell/id502329366)
- **28 september 2024 — äldre stödjande behovssignal.** En annan recensent vill uttryckligen kunna sätta tysta tider och förstå frekvensen. Det visar den viktigaste motrisken: en bra mikropaus blir en störning utan användarstyrning. [App Store: Lotus Bud](https://apps.apple.com/us/app/lotus-bud-mindfulness-bell/id502329366)

**Tolkning:** smärtan är inte ännu en meditationspåminnelse, utan att återkommande små pauser kräver för mycket minne och manuell återstart. Den enda uttryckliga betalningssignalen är prospektiv, inte ett genomfört köp.

### 2. Samma betalda upplevelse för ett hushåll

- **1 september 2025–4 april 2026 — stark betalproxy.** En Headspace-tråd visar människor som erbjuder och fyller platser i familjeabonnemang och andra som aktivt frågar om pris och tillgänglighet. Det är en enda oberoende källa och betalningarna kan inte verifieras utanför tråden, men beteendet är mer konkret än en allmän prisåsikt. [Reddit: Looking for people who want to join Headspace](https://www.reddit.com/r/Headspace/comments/1n60wjs/looking_for_people_who_want_to_join_headspace/)
- **31 mars 2022 — explicit villkorad betalningsvilja, men gammal.** En förälder överväger full prenumeration men avstår eftersom äldre barn inte kan använda köpet på egna enheter; familjedelning anges som villkoret som saknas. [App Store: New Horizon](https://apps.apple.com/us/app/new-horizon-sleep-meditations/id1457179117?platform=iphone&see-all=reviews)

**Tolkning:** här finns den tydligaste betalningskopplingen i dagens material, men bara en aktuell källa. Vindlas alla konfigurerade köp, inklusive abonnemanget, har `familyShareable: false` i [Products.storekit](/Users/elias/dev/vindla/Products.storekit:135). Ett eventuellt test bör börja med vuxna par/hushåll; barnanvändning skulle ändra säkerhets- och innehållskraven.

### 3. Betald historik och bibliotek får inte försvinna vid telefonbyte

- **11 oktober 2025 — stark betalproxy.** En långvarig betalande Othership-användare beskriver att full åtkomst inte följde med till ny telefon trots återstående abonnemangstid och att det bidrog till uppsägning; support löste senare problemet. [App Store: Othership](https://apps.apple.com/us/app/othership-guided-breathwork/id1590348936)
- **4 januari 2021 — explicit betalförlust, men gammal.** En recensent beskriver upprepade utloggningar/återställningar och förlorad progression efter betalning. Det är relevant riktning men för gammalt för att ensamt styra roadmapen. [App Store: Beginning](https://apps.apple.com/us/app/beginning-sleep-meditation/id1166940722)

**Tolkning:** Vindlas StoreKit kan återställa rättigheten med samma Apple-ID, men användarens historik och sparade meditationer lagras lokalt i `UserDefaults`, se [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:147) och [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:219). Den iCloud-lagring som hittades används för räknare/identifierare, inte biblioteket, se [KaiBrainService.swift](/Users/elias/dev/vindla/Stilla/Services/KaiBrainService.swift:82). Det är därför delvis ett verkligt produktgap, men källunderlaget är tunt.

### 4. En session ska tåla samtal, stör ej och tyst läge

- **11 juli 2026 — aktuell behovssignal, ingen betalning.** En Insight Timer-användare beskriver att ett okänt samtal pausar timern trots Stör ej och att det bryter meditationen. [Reddit: Phone calls and Do Not Disturb](https://www.reddit.com/r/InsightTimer/comments/1utl8ya/phone_calls_and_do_not_disturb/)
- **10 juni 2026 — aktuell behovssignal, gratisapp.** En användare felsöker att start-/slutklockan tystas av Stör ej/ringläge och ber om native-hantering; utvecklaren rättar felet. [Reddit: MTimer](https://www.reddit.com/r/googleplayconsole/comments/1u1tlwd/developed_a_meditation_tracking_app_for_free/)
- **30 juni 2025 — behovssignal, ingen betalning.** En App Store-recensent använder en reservtimer eftersom slutklockan ibland uteblir och efterfrågar automatisk Stör ej. [App Store: Transcendental Meditation](https://apps.apple.com/us/app/transcendental-meditation/id1535029280?platform=ipad&see-all=reviews)

**Tolkning:** tre oberoende källor pekar på samma brutna utfall: användaren kan inte lita på att sessionen fortsätter och avslutas korrekt. Ingen av dem visar betalningsvilja för just lösningen. iOS låter dessutom inte en app fritt slå på Fokus åt användaren, så ett Vindla-arbete skulle främst vara korrekt ljudsession, avbrottsåterhämtning och tydlig guidning.

### 5. Andningen ska kunna följas med slutna ögon

- **24 september 2024, med kommentarer till februari 2026 — behovssignal.** En användare vill ha prisvärd haptisk andning på iPhone/Watch utan att titta på skärmen; andra i tråden betonar slutna ögon och frågar efter gratis- eller engångspris. Det visar behov och prismodellintresse, inte att någon har betalat. [Reddit: haptic breath pacer](https://www.reddit.com/r/breathwork/comments/1fo853q/the_best_meditation_or_breathwork_app_on_iphone/)
- **21 februari och 22 mars, årtal visas inte på sidan — appnivåns betalningssignal.** Två Aer-recensioner beskriver appen som prisvärd respektive värd pengarna efter att ha provat andra appar. Aer erbjuder haptik och egna mönster, men recensionerna knyter inte betalningen entydigt till just haptiken. [App Store: Aer](https://apps.apple.com/us/app/breathing-meditation-aer/id6755346853)

**Tolkning:** detta är inte ett funktionsgap. Vindla har redan `off`, `haptic`, `sound` och `both` som andningssignaler i [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:46), haptiska fasbyten i [MeditationManager.swift](/Users/elias/dev/vindla/Stilla/MeditationManager.swift:462) och egna tekniker. Frågan är om användaren hittar och litar på läget med slutna ögon.

## Prioriterad topp 5

| Prioritet | Konkret problem → önskat utfall | Målgrupp / användningsögonblick | Oberoende signaler | Betalningsbevis | Vindla-passning och nuvarande täckning | Bygginsats / risk |
|---|---|---|---:|---|---|---|
| 1 | Måste minnas att starta om påminnelsen varje dag → diskreta mikropauser inom egna tider | Skrivbordsarbetare och stressade vardagsanvändare mellan sessioner | 2; en av sidorna har även 1 äldre stödrecension | **Explicit prospektiv:** 1 skulle köpa. Övrigt behov; inget verifierat köp | Hög. Delvis täckt av rutiner/påminnelser, men inte återkommande eller slumpade mikropauser med tysta tider | **S–M / medel.** Notisschemaläggning är enkel; tillit, iOS-gränser och notiströtthet är risken |
| 2 | Ett köp fungerar bara för en person → samma lugna upplevelse i hushållet | Vuxna par/hushåll; gemensam rutin eller olika enheter | 2, varav 1 gammal | **Stark proxy:** aktiva familjeplansplatser/prisdiskussion. **Explicit prospektiv:** prenumeration villkoras av delning | Medel–hög. Inte täckt; samtliga StoreKit-produkter är ej familjedelbara | **M / hög affärsrisk.** Entitlement är hanterbart, men AI-kostnad per familjemedlem och abuse måste modelleras |
| 3 | Betalt innehåll/progression följer inte med → trygg återställning på ny telefon | Långvarig användare vid telefonbyte, ominstallation eller återköp | 2, varav 1 gammal | **Stark proxy:** uppsägning med betald tid kvar. **Explicit historisk betalförlust:** 1 | Hög. Köp kan återställas, men bibliotek/historik är lokala | **M–L / medel–hög.** Datamodell, CloudKit-migrering, konflikter och integritet |
| 4 | Samtal eller systemläge bryter session/slutklocka → förutsägbar session och avslutning | Alla som mediterar med telefonen i vardagsmiljö | 3 | Ingen funktionsspecifik betalningssignal | Mycket hög kvalitetsmässigt. Ingen komplett avbrotts-/Fokuslösning hittades | **S–M / medel.** AVAudioSession/state recovery kan testas; Fokus kan inte automatiseras fritt |
| 5 | Måste titta på skärmen för andningsfas → säker guidning med slutna ögon | Andningsövning i säng, på stol eller med telefon i fickan | 2 | Appnivåns betalningsberöm; kausalitet till haptik saknas | Mycket hög, men **redan täckt**. Detta är discovery/UX och kvalitetsverifiering | **XS / låg.** Testa onboarding, namn, demo och haptikstyrka; bygg inte om först |

`S/M/L` är relativt Vindlas nuvarande kodbas, inte en kalenderprognos. Signaltal anger källor, inte antalet kommentarer eller ratings.

## Starkaste möjlighet: validera mikropausen, inte funktionen

Det här rankas först eftersom kombinationen är ovanlig i dagens material: ett exakt återkommande problem, en uttrycklig ”skulle köpa”-signal, hög passning till Vindlas löfte och relativt liten prototyprisk. Evidensen är fortfarande **måttlig**, inte stark.

### Tre dagars concierge-test med fem personer

1. Rekrytera fem personer som redan försöker få in korta pauser under arbetsdagen.
2. Låt var och en välja ett tidsfönster, tysta tider och ljud eller haptik. Schemalägg tre diskreta signaler per dag i tre dagar med befintliga lokala notiser/Shortcuts; varje signal leder direkt till Vindlas befintliga 60-sekunders andning. Ingen ny permanent funktion behövs.
3. Visa efter dag tre en ärlig konceptskärm: ”Automatiska mikropauser — 1,99 € engångsköp” med knappen ”Jag skulle köpa”; ta ingen betalning och märk tydligt att funktionen testas.

**Framgångskriterium:** minst 4 av 5 behåller signalerna påslagna alla tre dagar, minst 3 av 5 agerar på minst hälften av signalerna, och minst 2 av 5 väljer betalintentsknappen efter faktisk användning. Om något tröskelvärde missas: bygg inte; intervjua om frekvens, timing och störning.

**En fråga till alla fem:**

*”Berätta om den senaste arbetsdagen då du insåg för sent att du behövde pausa — vad skulle en kort ljud- eller haptiksignal behöva göra för att hjälpa, och när skulle den bli störande?”*

## Osäkerheter och rekommendation

- Dagens sökning hittade få oberoende, aktuella förstahandskällor med uttrycklig betalning. Det är särskilt svagt för störningshantering och haptik.
- Två betalningsrelevanta recensioner är från 2021–2022 och används bara som stöd, inte som ensam beslutsgrund.
- App Store visar inte årtal för vissa datum på den aktuella sidan; de redovisas därför utan påhittat årtal.
- Självmarknadsföring från appbyggare och leverantörstexter har inte räknats som användarbehov. Aggregerade ratings har inte räknats som oberoende signaler.
- Sökningen stoppades när nya träffar främst upprepade samma teman, var äldre eller var leverantörspåståenden. Ingen signal motiverar en bred funktionsinvestering idag.

**Rekommendation:** kör concierge-testet för mikropauser. Parallellt kan avbrotts-/slutklockefel behandlas som en kvalitetsgranskning, och haptisk andning som ett discovery-test. Ta inget roadmapbeslut om familjedelning eller full synk innan fem egna Vindla-användare bekräftar problemet och familjeekonomi respektive CloudKit-risk har modellerats.
