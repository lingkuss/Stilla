# Claim ledger - Vindla kopssignaler 2026-09-05

| ID | Pastaende | Typ | Belagg | Sakerhet | Begransning / formulering |
|---|---|---|---|---|---|
| C01 | Webbplatsen lovar tre fria Mimir-sessioner per manad | Direkt produktfakta | `website/index.html:113`, `website/personalized-meditation.html:96` | Mycket hog | Galler kontrollerad arbetskopia 2026-09-05 |
| C02 | Koden har en kreditraknare med max tre och registreringsmetod som inte anropas | Direkt kodfakta | `KaiBrainService.swift:7-75`; global `rg` | Mycket hog | Statisk granskning bevisar inte eventuell serverstyrd okand kod, men inga anrop finns i repo |
| C03 | Kontrollerade AI-/premiumingangar paywallar icke-prenumeranter | Direkt kodfakta | `KaiExperienceView.swift:367-381`, `ContentView.swift:1429-1525`, `SleepStoriesExperienceView.swift:230`, `SavedMeditationsLibraryView.swift:227-228` | Mycket hog | Inga runtime-flaggor observerades |
| C04 | Det finns ett verkligt glapp mellan gratislofte och nuvarande produktflode | Syntes | C01-C03 | Mycket hog | Korrigera antingen flode eller loftet |
| C05 | Backend loggar IP med mood/goal/theme | Direkt kodfakta | `backend/kai-proxy/server.js:401,472,551` | Mycket hog | Faktisk loggretention/hostpolicy ej verifierad |
| C06 | Policyn kallar AI-overforingen anonym och pastar iCloud-synk av historik | Direkt dokumentfakta | `website/privacy.html:67,80` | Mycket hog | Publik deployment kan skilja sig; arbetskopian granskad |
| C07 | Historik/sparat innehall ligger huvudsakligen i UserDefaults; iCloud KVS anvands for krediter | Direkt kodfakta | `MeditationManager.swift:147-224`, `KaiBrainService.swift:79-105` | Hog | Apple Health mindful minutes ar separat; full runtime-verifiering ej gjord |
| C08 | IP och intima mood-/goal-falt ska inte beskrivas som anonym data utan mycket starkare bevis | Primar juridisk/riskinferens | GDPR Art. 4; EDPB anonymisation/pseudonymisation | Hog | Inte juridisk radgivning; kontext, retention och identifierbarhet maste bedomas |
| C09 | OpenAI API-data tranar inte modeller som standard men abuse logs kan innehalla prompts/svar i upp till 30 dagar | Leverantor primarkalla | OpenAI default usage policies | Hog | Exakt endpoint/avtal/ZDR for Vindla ej verifierad |
| C10 | Vindlas interna bas ar nio livstidsnedladdningar till 2026-08-24 | Intern analysfakta | `GROWTH_PLAN.md:8,17-28,89` | Hog | Bygger pa intern App Store Connect-sammanstallning, inte ny direkt export |
| C11 | AI-meditation ar en svag ensam differentiering eftersom flera nara konkurrenter saljer liknande paket | Marknadsinferens | StillMind, Shunyah, InnerLoop officiella App Store-sidor | Hog | Funktioner/priser kan andras; inte marknadsandel |
| C12 | Betalare i journaling-appar varderar personlig aterkoppling och langsiktiga insikter | Oberoende anvandarsignal | Entries, Justly, Lightly, StillMind App Store-recensioner | Medel | Sjalvselektion; "worth it" isolerar inte alltid en funktion |
| C13 | Mood monitoring ensam har inte robust klinisk symtomeffekt | Vetenskaplig syntes | 2026 meta-analysis, 8 trials, n=1230 | Medel-hog | Kliniska populationer; sager inte att sjalvreflektion saknar produktvarde |
| C14 | Personlig aterkoppling ar mer lovande an matning ensam | Vetenskaplig inferens | Hong Kong RCT n=124; feedback battre an kontroll, ESM-only lik kontroll | Medel | Endast kvinnor, ett land, begransad generaliserbarhet |
| C15 | 45 procent av svenska vuxna rapporterade somnbesvar och 44 procent oro/angslan | Svensk primarkalla | Folkhalsomyndigheten 2024 | Hog | Sjalvrapport, 39 procents svarsfrekvens, oftast latta besvar |
| C16 | Det finns explicit betalning for aterkommande somnberattelser/somnljud | Oberoende anvandarsignal | BetterSleep/Endel Reddit; Waking Up App Store | Medel | Anekdoter visar existens, inte prevalens eller Vindla-konvertering |
| C17 | Strukturerade appbaserade somnprogram kan ge liten nytta jamfort med vantelista | Vetenskaplig evidens | Headspace RCT n=132; Calm RCT n=263 | Medel | Kort uppfoljning, vantelista, industrikopplingar, inga starka behandlingspastanden |
| C18 | Vindla Kväll ar hog produktpassning eftersom resor, somn, reflektion, rutiner och sparad uppspelning redan finns | Produktinferens | Kodbasgranskning | Hog | UX- och driftsarbete aterstar; ingen validerad efterfragan i Vindla-basen |
| C19 | Tre-dagarsprov bor inte behallas av vana; 5-9 dagar ar vanligast i Health & Fitness-urvalet | Kommersiellt benchmark | RevenueCat SOSA 2026, H&F 54% at 5-9 days | Medel | Observationsdata, urvalsbias, ej kausalt |
| C20 | 68 procent av H&F-intakter i RevenueCat-urvalet kommer fran arsplaner | Kommersiellt benchmark | RevenueCat SOSA 2026 | Medel-hog | Riktmarke, inte prisrekommendation eller prognos |
| C21 | AI-appar monetiserar initialt battre men har svagare retention/hogre refund | Kommersiellt benchmark | RevenueCat: +41% Y1 value/payer, 12m annual retention 21.1% vs 30.7%, refund 4.2% vs 3.5% | Medel | AI-klassning och urval; inte orsakssamband |
| C22 | En arsplan pa 29.99-34.99 USD ar en testhypotes, inte ett facit | Strategisk inferens | Nuvarande 47.88 annualiserat; H&F median 39.94; konkurrenter 39.99-69.99 | Lag-medel | Kraver verkliga provstarter och intervjuer |
| C23 | Rutinankare kan hjalpa daglig meditation | Vetenskaplig evidens | Anchoring RCT n=101, OR 1.14 | Medel | Litet, homogen sampel, Calm-jav, personligt ankare ej klart battre |
| C24 | Manga JITAI-prompts kan bli storande och RCT-resultaten ar osakra | Systematisk oversikt | 17 studier, n=652, 4 RCT | Medel | Heterogena interventioner; inte specifikt meditation |
| C25 | HRV/Watch bor inte prioriteras trots tva betalningssignaler | Strategisk inferens | Tva Reddit-betalningsanekdoter; kodgap; tolknings-/plattformrisk | Medel | Kan omvarderas vid tydlig egen efterfragan |
| C26 | Egen text/rost har explicit betalningssignal men hogre genomforanderisk | Oberoende anvandarsignal + inferens | Inner Wave, Innertune App Store | Medel | Tunt sample, angransande kategori, externt rostberoende |
| C27 | Reflektionsautospar/export ar fortroendebehov innan mer analys | Oberoende anvandarsignal + kodgap | Entries, Lightly, digital journaling Reddit; `ReflectionPromptView.swift`, share payload | Medel-hog | Table stakes/retention mer an ensam koporsak |
| C28 | App Store Connect kan vara intakt-/kanalkalla men intern grov eventdata behovs for koporsak | Plattformfakta + inferens | Apple App Store Connect Analytics docs; intern kodsokning | Hog | Exakt App Store Connect-konfiguration ej inspekterad |
| C29 | Radata om kanslor/reflektion ska inte anvandas i produktanalys | Produkt-/integritetsprincip | Dataminimering, HealthKit-regler, C05-C09 | Hog | Implementationsdetaljer kravs och juristgranskning rekommenderas |
| C30 | Huvudrekommendationen ar laga sanning -> forsta varde -> validera sju kvallar -> bygg personlig larloop | Beslutssyntes | C01-C29 | Medel-hog | Beror pa concierge-stoppregler; inte en garanti om produkt-market fit |

## Evidenshierarki

1. Direkt kod- och produktfakta.
2. Officiella myndighets-, plattforms- och vetenskapliga primarkallor.
3. Oberoende forstahandsutsagor med explicit kop/betalning.
4. Officiella konkurrentlistningar for funktion/pris.
5. Kommersiella aggregat som riktmarken.
6. Strategisk inferens, alltid markerad som hypotes eller beslut.

## Stoppnotering

Sokningen stoppades nar nya traffar huvudsakligen upprepade redan kartlagda teman (timer/presets, Apple Watch, offline, röst, familjedelning, somnljud) och de aterstaende besluten kunde avgoras battre med Vindla-intervjuer an med fler anekdoter. Nytt i denna rapport betyder ny syntes mot den nuvarande kodbasen och nya kopsignaler i angransande journaling/somn - inte att alla kallsidor publicerats efter tidigare rapporter.
