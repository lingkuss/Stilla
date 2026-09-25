# Vindla: var finns nasta obearbetade kopsignal?

Datum: 5 september 2026  
Beslutsperiod: 0-90 dagar  
Primar marknad: Sverige/Norden, iOS  
Fraga: Hur kan Vindla ge ett verkligt, aterkommande anvandarvarde dar det finns kopsignaler som produkten inte redan har tagit vara pa?

## Beslut i korthet

Vindla behover inte mer generiskt AI-innehall. Appen har redan en ovanligt bred produktbas: personliga Mimir-sessioner, timer, andning, somnberattelser, reflektioner, sju-dagarsresor, rutiner, Siri/App Intents, widgets, Live Activity och Apple Health. Det viktigaste gapet ar i stallet att anvandaren inte far uppleva, se och upprepa ett konkret resultat fore betalbeslutet.

Den starkaste nya produktriktningen ar en sluten vardeloop:

> Ett valt problem i ett bestamt ogonblick -> en kort relevant session -> en frivillig fore/efter-signal -> en begriplig personlig insikt -> nasta session kopplad till en verklig rutin.

Gor den forst konkret som **Vindla Kväll**, ett sju-kvallars nedvarvningsprogram for tankesnurr och arbetsstress. Det ateranvander stora delar av den befintliga motorn men paketerar dem kring ett problem som ar vanligt i Sverige och dar det finns faktisk betalning for aterkommande somnhjalp. Efter tre kvallar ska appen kunna saga nagot forsiktigt men anvandbart, till exempel: "Kort guidning efter kl. 22 verkar oftast hjalpa dig att varva ned." Detta ar personlig aterkoppling, inte diagnos eller behandling.

Innan det byggs finns tva P0-problem som maste rattas:

1. **Lat anvandaren prova karnvardet.** Webbplatsen lovar tre fria Mimir-sessioner per manad och koden innehaller en oanvand kreditraknare med max tre, men alla kontrollerade AI-ingangar skickar en icke-prenumerant direkt till paywall. Detta ar bade ett vardegap och ett fortroendegap.
2. **Gor integritetsloftet sant.** Backend loggar IP-adress tillsammans med fri mood/goal/theme-text. Integritetspolicyn beskriver overforingen som anonym och pastar att historik synkas via iCloud, medan huvuddelen av historiken ligger i lokala UserDefaults. Det maste antingen byggas som utlovat eller beskrivas korrekt. Ra reflektioner och mood-text ska inte finnas i produktanalys eller loggar.

Rekommenderad ordning:

- Vecka 1-2: laga "varde fore paywall" och integritets-/abonnemangstillit.
- Vecka 2-4: genomfor 5-8 intervjuer med personer som redan betalar for somn, meditation eller journaling och testa ett sju-kvallars concierge-upplagg.
- Vecka 4-8: bygg minsta Vindla Kväll-loop om valideringen klarar stoppreglerna.
- Vecka 8-12: lagg till "Min effekt" - endast nar tre eller fler jamforbara fore/efter-svar finns - och testa sju dagars provperiod plus arsplan efter forsta lyckade sessionen.

## Vad granskningen omfattade

### Produkt och kod

Kontrollerade ytor omfattar hemflode, onboarding, Mimir, resor, somn, sparade sessioner, reflektioner, rutiner, StoreKit, Apple Health, App Intents, lokallagring, backendloggning, publik webbplats och integritetspolicy.

Viktigaste kodbevis:

- `KaiBrainService.swift:7-75` definierar tre fria krediter och metoden `recordFreeGeneration()`. Global kodsokning visar ingen anropande produktkod.
- `KaiExperienceView.swift:367-381`, `ContentView.swift:1429-1525`, `SleepStoriesExperienceView.swift:230` och `SavedMeditationsLibraryView.swift:227-228` lagger betalvagg fore de kontrollerade AI-/premiumstarterna.
- `website/index.html:113` och `website/personalized-meditation.html:96` lovar tre fria Mimir-sessioner varje manad.
- `backend/kai-proxy/server.js:401,472,551` loggar IP plus ra anvandarinmatningar som mood, goal och theme.
- `website/privacy.html:67,80` beskriver AI-overforingen som anonym och uppger att historik synkas via iCloud.
- `MeditationManager.swift:147-224` lagrar huvuddelen av historik och sparat innehall i `UserDefaults`; `KaiBrainService` anvander iCloud KVS for kreditrakning.
- `Products.storekit` har en manadsprenumeration pa 3,99 USD med tre dagars provperiod, men ingen arsplan. Separata engangskop ar 0,99, 1,99 och 4,99 USD.
- `ReflectionPromptView.swift` och `MeditationManager.swift` har redan efter-session-reflektion och signaler som kan paverka nasta resdag. Det saknas en anvandarvand sammanfattning av vad som verkar fungera over tid.

### Externa kallspar

Sokningen anvande fyra evidenslager:

1. Faktiska kop eller betalningsnara beteenden i oberoende anvandarkallor.
2. Officiella App Store-produktsidor och konkurrentpriser.
3. Vetenskapliga oversikter och randomiserade studier for vad som rimligen skapar nytta och vana.
4. Primarkallor for svensk problemstorlek, Apple-plattformen, integritet och abonnemang.

Anvandarcitat behandlas som signaler, inte prevalens. Leverantorsrapporter behandlas som riktmarken, inte som kausala bevis eller prognos for Vindla.

## Nulage: mycket produkt, for lite bevisat resultat

Vindla ar redan bredare an sin App Store-positionering "Personalized AI Meditation" antyder. Appen innehaller minst fem vardeslager:

1. Omedelbar reglering: timer, andning och korta sessioner.
2. Personlig guidning: mood/goal, atta rostpersonligheter och Mimir-generering.
3. Kvallsbruk: somnberattelser och ljudmiljoer.
4. Kontinuitet: sparade sessioner, rutiner, paminnelser, resor, historik och Apple Health.
5. Reflektion: efter-session-check-in, taggar, fritext och anpassning av nasta resdag.

Men tre centrala samband ar inte synliga for anvandaren:

- "Det har ar tillrackligt bra for mig" fore betalvaggen.
- "Det har hjalper mig oftast" efter upprepade sessioner.
- "Det har ar vad jag ska gora nasta gang samma situation uppstar."

Det ar ett storre strategiskt problem an innehallsmangd. Flera aktuella konkurrenter saljer redan samma yttre paket: AI-genererad meditation, journal, mood tracking, roster, insikter och somn. StillMind tar 9,99 USD/man eller 59,99 USD/ar; Shunyah 8,99/69,99; InnerLoop har AI-nivaer pa 4,99/39,99 respektive 9,99/79,99. En ensam "AI-personalisering" ar darfor en kategorietikett, inte en forsvarbar anledning att stanna.

Vindlas interna tillvaxtplan visar dessutom att det storsta nulagesproblemet ar rackvidd: nio livstidsnedladdningar till 24 augusti 2026, 105 visningar, 22 produktsidevisningar och fem forstagangsnedladdningar pa 90 dagar. En liten bas kan inte ge statistiskt stabila konverteringsexperiment. Varje faktisk betalare ar just nu mer vard som intervjuad anvandare an som datapunkt i en multivariat paywalltest.

## De tre starkaste obearbetade kopsignalerna

### 1. Betalning for personlig aterkoppling - inte bara loggning

Det starkaste nya betalningssparet utanfor ren somn ar att manniskor betalar nar deras egna anteckningar omvandlas till aterkoppling och langsiktiga monster:

- En Entries-anvandare skrev 18 november 2025 att journalen "pratar tillbaka" pa ett hjalpsamt satt och att Premium var vart priset. Appen tar 14,99 USD/man eller 99,99 USD/ar.
- En Justly-anvandare skrev 28 november 2025 att ett betalt ar var "totally worth it" och lyfte bland annat insikter, kanslograf och sambandet mellan somn och en dalig dag.
- En Lightly-anvandare skrev 10 november 2025 att hen betalat for ett ar och uppskattade veckovisa insikter som visade ett monster mellan veckodag och humor.
- En StillMind-recension beskriver den omedelbara journalen, progressionstrackern och en enkel 2-5-minuters morgonstund som det som gor appen "worth it".

Detta ar inte bevis for att dashboards eller mer mood tracking skapar effekt. En metaanalys fran 2026 av atta studier och 1 230 kliniska deltagare fann ingen robust symtomnytta av mood monitoring i sig. En randomiserad studie med 124 kvinnor fann daremot battre utfall nar experience sampling kombinerades med personlig aterkoppling; ren matning var ungefar som kontroll. Det viktiga ar alltsa nasta anvandbara beslut, inte fler kurvor.

**Vindla-gap:** reflektionen finns redan, och sju-dagarsresan kan anpassa nasta session. Men anvandaren far inte en tydlig, ackumulerad slutsats om vilka situationer, langder eller sessionstyper som oftast foljs av den effekt de sjalva valde.

**Produktmojlighet:** "Min effekt". Efter tre jamforbara sessioner, visa en enda forsiktig insikt och en atgard: "3-minuters andning efter jobbet har oftast gett dig mer lugn. Starta samma igen." Ingen diagnos, ingen kausal formulering, ingen rangordning av kanslor.

**Evidensbedomning:** hog betalningssignal i angransande journaling, medel evidens for personlig aterkoppling, hog produktpassning, lag-medel bygginsats. Osakerheten ar om Vindlas anvandare betalar for reflektion eller primart for guidning/somn.

### 2. Betalning for aterkommande kvallshjalp

Sverige har ett stort problemutrymme: Folkhalsomyndigheten rapporterade 2024 att 45 procent av vuxna uppgav somnbesvar och 44 procent oro/angslan, oftast lattare besvar. Det ar sjalvrapporterad prevalens med 39 procents svarsfrekvens, inte en appmarknadsprognos.

Betalningssignalerna ar anekdotiska men konkreta:

- En BetterSleep-anvandare uppgav att hen betalar 29,99 USD/ar framst for somnberattelser och har ateranvant dem i flera ar.
- I samma diskussion uppgav en annan att hen betalar 2,99 USD/man for Endel och anvander den bade varje kvall och dagtid.
- Waking Up har App Store-recensioner dar betalande anvandare beskriver helmedlemskapet som vart det och nattlig meditation som aterkommande anvandning.
- Samma kategorikallor visar en viktig motsignal: betalande anvandare reagerar starkt nar favoriter eller mixar flyttas bakom en ny betalvagg.

Vetenskapen stodjer ett strukturerat program battre an ett lost ljudbibliotek. En Headspace-RCT 2025 med 132 vuxna med klinisk insomnia testade ett 18-sessioners sjalvlett program med mindfulness och CBT-I-tekniker mot vantelista. Deltagarna genomforde i snitt 13 av 18 sessioner; remission och respons var hogre an kontroll men absoluta effekter var smala, uppfoljningen kort och flera forfattare arbetade pa Headspace. En Calm-studie med 263 personer med forh ojda insomnisymtom fann battre trotthet, dagtrotthet och forsomnsaktivering mot vantelista, men aven dar fanns foretagskopplingar och ingen aktiv behandlingskontroll.

**Vindla-gap:** appen har berattelser och resor, men inte ett avgransat kvallsjobb som lar sig av kvallens faktiska utfall. En samling berattelser ar ateranvandbar underhallning; ett program maste visa varfor nasta kvall blir mer relevant.

**Produktmojlighet:** "Vindla Kväll", beskriven nedan.

**Evidensbedomning:** hog problemforekomst, medel betalningssignal, medel vetenskaplig evidens, mycket hog produktpassning, medel bygginsats. De vetenskapliga resultaten motiverar inte behandlingspastanden eller en kopia av CBT-I.

### 3. Betalning for en egen praktik - men den ar inte forst

En Inner Wave-anvandare uppgav att Pro koptes specifikt for att klistra in egen text och gora den till rostad meditation; nar en extern ElevenLabs-nyckel senare kravdes hade anvandaren inte kopts och begarde aterbetalning. En angransande Innertune-recension kallar livstidsuppgradering for egen rost over bakgrund for sin basta investering.

Det ar en skarp signal om agande och kontinuitet: betalvardet ligger i den egna praktiken, inte i en oandlig leverantorskatalog. Men den ar tunn, tekniskt kostsam och kan oka rost-, innehalls- och integritetsrisk. Vindla har redan sparade script och atta roster. Ratt drag nu ar att gora sparat personligt innehall tryggt, exporterbart och latt att aterstarta - inte att bygga röstkloning.

**Evidensbedomning:** medel betalningssignal men lag prevalenssakerhet, medel produktpassning, hog risk/insats. Avvakta.

## P0: fyra saker att laga fore en ny stor funktion

### A. Gor det publika gratisloftet sant

Idag finns en direkt motsagelse:

- Marknadssidan: tre fria Mimir-sessioner varje manad.
- Tjanstelagret: tre fria krediter och en metod for att registrera bruk.
- Anvandarflodena: premiumkontroll fore Mimir, snabb mood-start, resa, somnberattelse och sparad premiumsession.

Det kan betyda att produktens karnupplevelse aldrig provas. RevenueCats aggregerade 2026-data visar samtidigt att 55 procent av alla avbokningar av tredagarsprov sker dag noll och att AI-appar monetiserar battre initialt men har 30 procent snabbare churn. Det ar kommersiell aggregatdata, inte ett kausalt bevis, men den forstarker samma produktlogik: forsta sessionen maste visa mer an AI-nyfikenhet.

**Beslut:** koppla minst en faktisk gratis Mimir-generation till onboardingens slut och registrera den i den befintliga kreditraknaren. Efter sessionen: ett frivilligt ett-trycks fore/efter-svar och forst da erbjudande om provperiod. Om avsikten verkligen ar tre fria varje manad, gor alla tre tillgangliga och lat copy, app och webb saga samma sak. Om kostnaden inte tillater det, ta bort loftet. Testa inte komplexa varianter innan grundloftet ar sant.

### B. Ta bort ra kansliga loggar och korrigera integritetstext

IP-adress plus fri text om mood, goal och somntema ar inte "anonym" bara for att namn saknas. GDPR definierar halsouppgifter brett, inklusive mental halsa, och EU-praxis behandlar onlineidentifierare som IP som potentiellt personidentifierande. EDPB skiljer tydligt pa anonymisering och pseudonymisering. OpenAI uppger att API-data inte anvands for traning som standard, men abuse-monitoring-loggar kan innehalla prompts/svar och normalt behallas upp till 30 dagar om inte sarskilda kontroller som Zero Data Retention ar godkanda.

**Beslut:** sluta logga fri anvandartext och IP tillsammans. Behall endast grova, uppraknade driftfalt som felkod, modellvariant, svarstid och genereringstyp. Dokumentera faktisk leverantor, andamal och retention. Korrigera iCloud-pastandet eller bygg verklig synk. Detta ar produktfortroende och riskminskning, inte ett juridiskt slutomdome; lat integritetsjurist granska slutlig text.

### C. Gor abonnemanget begripligt och reversibelt

Vindla visar tre dagar gratis, pris och aterstall kop, men ingen tydlig "Hantera abonnemang"-vag hittades. Tidigare research visade flera faktiska betalare som lamnat appar efter ovantade fornyelser eller lasproblem. Apple har officiella ytor for att visa hantering, erbjudanden och abonnemangsstatus.

**Beslut:** lagg in Hantera abonnemang i installningar och efter kop; visa exakt provslut och vad som hander efterat; aktivera Billing Grace Period om driftmodellen tillater; erbjud aldrig en lokal "paminnelse" som skapar falsk garanti om Apple-debitering.

### D. Skydda reflektioner och gor dem portabla

Betalande journaling-anvandare rapporterar bade oro for var intima data lagras och konkret churnrisk nar utkast eller poster forsvinner. Vindlas reflektion sparas forst vid explicit Save och delningsexporten innehaller bara scriptet.

**Beslut:** autospara lokalt utkast, visa lagringsplats begripligt och erbjud export/radering. Bygg inte analys ovanpa fri reflektionstext forran lagring, retention och anvandarkontroll ar robusta.

## Huvudbetet: Vindla Kväll

### Jobbet som produkten ska vinna

"Nar jag gar och lagger mig men hjarnan fortsatter jobba vill jag komma ned i varv pa nagra minuter, utan att valja ur ett stort bibliotek, och efter nagra kvallar forsta vad som faktiskt hjalper mig."

Detta ar smalare och mer kopbart an "personlig meditation". Det skapar ett aterkommande ogonblick, ett synligt utfall och en naturlig sju-dagarsperiod som passar provperiod och befintlig resmotor.

### Minsta upplevelse

1. **Valj hinder, inte innehall:** tankesnurr, jobbet foljer med hem, kroppen ar spanning, eller "jag vill bara landa".
2. **Valj ankare:** efter tandborstning, nar telefonen laddas, efter att lampan slackts eller egen tid. Opt-in och tysta tider ar obligatoriska.
3. **Starta direkt:** 3-5 minuters personlig nedvarvning; optional fortsattning med sparad berattelse, ljud eller tystnad. Senast fungerande pass ska finnas lokalt om generering misslyckas.
4. **En fore-signal:** "Hur uppvarvad ar du?" 1-5, frivilligt.
5. **En efter-signal:** "Lite lugnare, oforandrat eller mer uppvarvad?" plus "detta hjalpte" som valfri tagg.
6. **Nasta morgon endast om användaren vill:** "Var det lattare att komma till ro?" Ja/ungefar/nej. Ingen sokmatt klinisk diagnos.
7. **Efter tre kvallar:** en enda forklarbar insikt och ett forslag. Exempel: "Korta kroppsovningar verkar oftare hjalpa an berattelser. Gor samma i kvall?"

### Varfor detta kan skapa betalvarde

- Det loser ett konkret och frekvent problem, inte bara ett diffust valmaende.
- Det gor AI:n till en osynlig anpassningsmotor i stallet for sjalva produkten.
- Det skapar personligt ackumulerat varde som en gratis ljudfil inte har.
- Det ateranvander Vindlas befintliga resor, somnmotor, reflektion, rutiner och sparad uppspelning.
- Det ger en arlig plan en rimlig berattelse: en fortsatt personlig vana, inte ett dyrt innehallsbibliotek.

### Vad som uttryckligen inte ska lovas

- Ingen behandling av insomnia, angest eller annan diagnos.
- Ingen garanti om battre somn.
- Ingen formulering som gor korrelation till kausalitet.
- Ingen generativ terapi eller psykologersattning.
- Ingen sensorstyrd intervention utan separat evidens- och integritetsarbete.

## Andra betet: Min effekt

"Min effekt" ar den generella motorn under Vindla Kväll och andra anvandningsfall. Den ska inte vara en tung analysvy. Den ska svara pa en enda fraga: "Vad verkar vara vart att upprepa for mig?"

Minsta datamodell:

- Anvandarvalt jobb: somn, tankesnurr, stress fore mote, aterhamtning efter jobb, fokus eller vana.
- Situation/ankare: ett uppraknat val, inte fri text.
- Sessionstyp, langd och persona.
- Frivilligt fore/efter-utfall pa enkel skala.
- Nasta relevanta start.

Regler for presentation:

- Visa inget monster innan minst tre jamforbara tillfallen.
- Skriv "verkar", "oftare" och antal tillfallen.
- Lat anvandaren oppna vilka sessioner som ligger bakom insikten.
- Ge alltid en atgard: upprepa, jamfor med annan langd eller ignorera.
- Ingen dold analys av fri reflektionstext som standard.

Den vetenskapliga begransningen ar viktig: mood tracking ensam har svag effekt, och en app kan latt fa slumpmonster att se meningsfulla ut. Funktionen ska darfor optimeras for begripligt sjalvlarande och aterstart, inte for medicinsk precision.

## Monetisering som matchar vardeloopen

### Behall gratisverktygen

Timer, grundandning och en verklig forsta Mimir-upplevelse ska forbli smakprov och nyttiga verktyg. Apples granskningsregler betonar att prenumerationer ska ge lopande varde; en enkel timer eller systempaminnelse ar ett svagt abonnemangslofte.

### Flytta betalogonblicket till efter ett lyckat utfall

Rekommenderad ordning:

1. Onboarding valjer ett jobb.
2. En riktig 2-3-minuters Mimir-session genomfors gratis.
3. Anvandaren markerar valfritt utfall.
4. Paywall: "Fortsatt i sju dagar och lat Vindla anpassa nasta kvall."

Detta gor betalvaggen forklarande: den saljer kontinuitet, sparande och personlig larloop, inte bara "AI".

### Testa sju dagar och en arsplan - men kalla det en hypotes

Vindla har tre dagars provperiod och enbart 3,99 USD/man, motsvarande 47,88 USD per ar om abonnemanget behalls. RevenueCats 2026-urval visar att 54 procent av Health & Fitness-appar med prov anvander 5-9 dagar, att korta provperioder har lagre aggregerad trial-to-paid-konvertering an langre och att 68 procent av kategorins intakter kommer fran arsplaner. Kategorins medianpris ligger runt 39,94 USD/ar och 9,99 USD/man. Urvalet omfattar appar som anvander RevenueCat och klarar vissa installations-/intaktstrosklar; det ar riktmarken, inte effekt av en enskild andring.

**Hypotes att testa:** 7 dagar gratis, 3,99 USD/man och 29,99-34,99 USD/ar. Visa arsplanen efter forsta genomforda vardesessionen. Intervallet ger en tydlig besparing mot manadsplanen men ar inte en slutlig prisrekommendation.

Med bara nio livstidsnedladdningar ska Vindla inte A/B-testa tre priser samtidigt. Valj en tydlig arsplan, intervjua varje ny betalare och byt endast efter minst 20-30 relevanta provstarter eller stark kvalitativ disconfirming evidence.

## Mata koporsaken utan att samla kanslig text

Vindla kan inte i dag svara pa varfor en anvandare betalade. App Store Connect kan visa nedladdningar, kop, prenumerationer, erbjudanden, retention och kampanjkallor, men inte vilken intern session som skapade vardet.

Lagg till en frivillig fraga precis efter provstart eller kop:

> "Vilket ogonblick vill du att Vindla ska hjalpa dig med?"

Val: Somn, tankesnurr, stress fore mote, aterhamtning efter jobb, skapa vana, annat/vill inte svara.

Efter tredje lyckade sessionen:

> "Vad gjorde detta vart att fortsatta med?"

Val: ratt session direkt, personlig anpassning, hjalpte i stunden, latt att gora till vana, somn/kva ll, annat/vill inte svara.

Minimal handelsespecifikation:

| Handelse | Tillatna falt | Inte tillatet |
|---|---|---|
| `first_value_completed` | job_enum, duration_bucket, session_type | mood-text, reflektion, IP |
| `paywall_seen_after_value` | job_enum, free_session_count | fritext |
| `trial_started` | plan, trial_days, entry_surface | fri anvandartext |
| `day2_return` | job_enum, return_surface | identifierbar halsodata |
| `journey_night_completed` | night_number, session_type, duration_bucket | prompt/svarstext |
| `subscription_converted` | plan, acquisition_campaign | reflektion, HealthKit-data |

Lat App Store Connect vara sanningen for intakt och kanal. Om en egen analyspipeline anvands, pseudonymisera, minimera retention och dokumentera samtycke/andamal. Skicka inte HealthKit-data till annonsering eller till en tredjepartsanalysprodukt.

## Prioritering

| Prio | Mojlighet | Kopsignal | Evidens | Produktpassning | Insats | Beslut |
|---:|---|---|---|---|---|---|
| 0A | Sant gratislofte + en vardesession fore paywall | Indirekt men kritisk for att prova karnan | Mycket hog intern evidens | Mycket hog | S | Gor nu |
| 0B | Integritets-, logg- och abonnemangstillit | Stark churn-/fortroendesignal | Mycket hog intern/primar evidens | Mycket hog | S-M | Gor nu |
| 1 | Vindla Kväll, sju kvallar | Faktisk betalning for aterkommande somnhjalp | Medel, flera lager | Mycket hog | M | Validera och bygg minsta loop |
| 2 | Min effekt + nasta basta session | Faktisk betalning i angransande journalappar | Medel-hog | Hog | S-M | Bygg ovanpa Kväll |
| 3 | Situationsankare + tysta tider | Beteendeevidens, svag direkt koporsak | Medel | Hog | S | Inkludera i Kväll |
| 4 | Arsplan + sju dagars prov | Aggregerat kommersiellt benchmark | Medel, ej kausalt | Hog | S | Testa efter vardesession |
| 5 | Export/autospar av reflektion | Betalarchurn och fortroende | Medel | Medel-hog | S-M | Bygg fore mer reflektion |
| Senare | Egen text/rost-praktik | Tunn men explicit betalning | Lag-medel | Medel | L | Avvakta |
| Nej nu | HRV/Watch-biofeedback | Tva faktiska betalningssignaler | Lag prevalens, hog tolkningsrisk | Lag-medel | L | Avvakta |

## 90-dagars plan med stoppregler

### Fas 1: sanera och prova varde, vecka 1-2

- Koppla kreditraknaren till minst en riktig gratis Mimir-session.
- Lat onboarding sluta i session, inte persona-val.
- Ta bort ra mood/goal/theme + IP-loggar.
- Korrigera iCloud/anonymitetscopy.
- Lag till Hantera abonnemang och tydlig provinformation.
- Autospara reflektionens utkast lokalt.

Kvalitetsgrind: fem av fem testpersoner ska kunna genomfora ratt gratis session, se vad som sparas och forsta nar betalning borjar utan hjalp.

### Fas 2: concierge-validering, vecka 2-4

Rekrytera 5-8 personer som redan betalar eller nyligen har betalat for somn-, meditation- eller journalingapp. Urvalet ska innehalla minst tre som anvander nattlig hjalp fyra eller fler kvallar per vecka.

Genomfor sju kvallar manuellt med en enkel prototyp:

- ett valt kvallshinder,
- 3-5 minuters session,
- ett frivilligt fore/efter-svar,
- nasta kvalls anpassning,
- intervju dag 1, 3 och 7.

Fraga inte "skulle du betala?" forst. Fraga vad de betalar for nu, nar de senast anvande det, vad de gor nar det inte fungerar och vad de avstar fran. Avsluta med ett verkligt val: boka fortsatt betatest med angiven prisniva eller tacka nej.

Stoppregel: bygg inte full loop om farre an 4 av 8 genomfor minst 4 av 7 kvallar, farre an 3 vill fortsatta till konkret pris, eller om den manuella anpassningen inte upplevs battre an att spela samma sparade pass.

### Fas 3: minsta produkt, vecka 4-8

Bygg endast:

- kvallsjobb + rutinankare,
- 3-5 minuters start,
- lokal fallback,
- fore/efter-signal,
- en regelbaserad nasta-session-rekommendation,
- en insikt efter minst tre jamforbara kvallar.

Primara matt:

- `first_value_completed / onboarding_started`
- forsta kvalls slutförande
- andel med minst 4 av 7 kvallar
- andel som uppger "lite lugnare" eller egen vald nytta
- D2, D7, D14-retur for samma jobb
- provstart efter forsta vardesession
- trial-to-paid och tidig refund/avslut

Sekundara matt: genereringsfel, tid till ljud, fallback-anvandning och andel som avstar fore/efter-svar. Mood-vardet i sig ar inte ett tillvaxtmal.

### Fas 4: paketering, vecka 8-12

- Visa Min effekt for kvalificerade anvandare.
- Introducera arsplan och sju dagars provperiod i en enda variant.
- Intervjua varje betalare: koporsak, alternativet de annars anvander, och vad som skulle fa dem att saga upp.
- Behall gratis timer och andning; lat Pro vara anpassade program, sparande/kontinuitet och personlig larloop.

Beslutsgrind efter minst 20 relevanta provstarter: fortsatt bara om kvalitativa intervjuer pekar pa samma jobb och trial-to-paid inte kommer med hog tidig churn/refund. RevenueCats 37,7 procent trial-to-paid och 3,5 procent iOS download-to-paid for Health & Fitness ar externa medianer, inte rimliga miniminivaer for en nio-nedladdningsprodukt.

## Vad som inte bor byggas nu

- Ett storre bibliotek av generiska meditationer eller somnljud.
- Fler AI-personas som huvuddifferentiering.
- En mood-dashboard utan aterkoppling och nasta atgard.
- Sensorstyrd JITAI med manga paminnelser. En systematisk oversikt fann inga tydliga primara beteendeskillnader i de fa RCT:erna och mer an fem dagliga prompts upplevdes ofta som storande.
- HRV/Watch-biofeedback. Det finns tva tydliga betalningsanekdoter men lag prevalenssakerhet, plattformsbegransningar och medicinsk tolkningsrisk.
- Klinisk CBT-I, terapi eller behandlingspastanden utan separat klinisk, regulatorisk och integritetsmassig grund.
- Röstkloning eller anvandarens egen AI-röst fore lagring, export, rettigheter och kostnad ar utredda.
- Social feed, community eller gamifierad skuld.
- Lifetime-plan innan verklig retention och kostnad per genererad minut ar kand.

## Risker och begransningar

- Vindlas interna bas ar mycket liten. Ingen procentsats fran dagens funnel ar stabil nog att ensam styra roadmap.
- App Store- och Reddit-kallor ar sjalvselekterade, ibland anonymiserade och kan inte visa hur vanligt ett behov ar.
- "Worth it" bevisar upplevt varde men inte alltid vilket enskilt inslag som orsakade kopet.
- Konkurrentpriser visar vad som erbjuds, inte vad kunder faktiskt betalar eller behaller.
- RevenueCats urval ar kommersiellt, inkluderar bara integrerade appar som klarar trosklar och kan ha urvalsbias. Jamforelser mellan provlangder ar inte randomiserade.
- Studierna av meditations- och somnappar visar oftast sma effekter, korta uppfoljningar och vantelistekontroller. Flera har industrikopplingar.
- Svensk prevalens ar sjalvrapporterad och svarsfrekvensen var 39 procent.
- Integritetsanalysen ar en produkt- och riskbedomning, inte juridisk radgivning.

## Slutsats

Vindlas nasta verkliga varde finns inte i en ny AI-funktion. Det finns i att gora den befintliga bredden till ett personligt, aterkommande bevis: "det har hjalper mig i det har ogonblicket, och jag vet vad jag ska gora nasta gang."

Det mest lovande forsta jobbet ar kvallens tankesnurr. Det har stor svensk problemforekomst, verkliga betalningssignaler, en rimlig evidensbas och mycket hog ateranvandning av befintlig kod. Men det ska inte byggas forran den nuvarande produkten faktiskt levererar det gratislofte den marknadsfor och tills loggning, lagring och abonnemang ar tillrackligt begripliga for en app som hanterar intima reflektioner.

Det mest rationella nasta draget ar darfor: **laga sanningen, lat anvandaren kanna varde, validera sju kvallar, bygg sedan lar-loopen.**

## Kallor

### Primar och vetenskaplig evidens

1. Folkhalsomyndigheten, "Varannan vuxen har somnbesvar", 2024. https://www.folkhalsomyndigheten.se/nyheter-och-press/nyhetsarkiv/2024/november/varannan-vuxen-har-somnbesvar/
2. Folkhalsomyndigheten, befolkningens psykiska halsa, uppdaterad 2025. https://www.folkhalsomyndigheten.se/vara-amnesomraden/psykisk-halsa/befolkningens-psykiska-halsa/
3. Linardon et al., efficacy of mindfulness and meditation apps, Clinical Psychology Review, 2024. https://pubmed.ncbi.nlm.nih.gov/38056219/
4. Linardon et al., attrition in randomized trials of mental health apps, 2023. https://pubmed.ncbi.nlm.nih.gov/37862854/
5. Jakob et al., adherence to mobile health interventions, JMIR, 2022. https://doi.org/10.2196/35371
6. Meditation habit anchoring RCT, 2021. https://pubmed.ncbi.nlm.nih.gov/34941558/
7. Just-in-time adaptive interventions systematic review, 2021. https://pmc.ncbi.nlm.nih.gov/articles/PMC8663593/
8. Mood tracking meta-analysis, 2026. https://pmc.ncbi.nlm.nih.gov/articles/PMC12779106/
9. Experience sampling with personalized feedback RCT. https://hub.hku.hk/handle/10722/322551
10. Headspace insomnia program RCT, JMIR mHealth, 2025. https://mhealth.jmir.org/2025/1/e68665
11. Calm sleep RCT, PLOS ONE. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0244717
12. GDPR, Regulation (EU) 2016/679. https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32016R0679
13. EDPB, anonymisation and pseudonymisation. https://www.edpb.europa.eu/topics/ai-and-technology/anonymisation-pseudonymisation_en
14. OpenAI API data usage policies. https://platform.openai.com/docs/models/default-usage-policies-by-endpoint

### Plattform och marknad

15. RevenueCat, State of Subscription Apps 2026: Health & Fitness. https://www.revenuecat.com/state-of-subscription-apps-2026-health-and-fitness/
16. Apple, App Review Guidelines. https://developer.apple.com/app-store/review/guidelines/
17. Apple, auto-renewable subscriptions. https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions
18. Apple, subscriptions overview. https://developer.apple.com/app-store/subscriptions/
19. Apple, App Store Connect Analytics. https://developer.apple.com/help/app-store-connect-analytics/overview/analytics-dashboard/
20. Apple, HealthKit mindful session. https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/mindfulsession
21. Apple, App Intents. https://developer.apple.com/documentation/appintents
22. Vindla App Store. https://apps.apple.com/us/app/vindla/id6761864704
23. StillMind App Store. https://apps.apple.com/us/app/stillmind-meditation-journal/id6749165508
24. Shunyah App Store. https://apps.apple.com/us/app/shunyah-ai-guided-meditation/id6760863460
25. InnerLoop App Store. https://apps.apple.com/us/app/innerloop-ai-meditation/id6757369840
26. Timefully App Store. https://apps.apple.com/us/app/timefully-meditation-timer/id1440679849?platform=watch

### Oberoende betalnings- och anvandarsignaler

27. Entries App Store. https://apps.apple.com/us/app/entries-ai-journal-diary/id6745230196
28. Justly App Store. https://apps.apple.com/us/app/justly-ai-journal-ai-therapy/id1570951174
29. Lightly App Store. https://apps.apple.com/us/app/lightly-wellbeing-companion/id6575383588
30. Inner Wave App Store. https://apps.apple.com/us/app/inner-wave-meditate-your-way/id6759627198
31. Innertune App Store. https://apps.apple.com/us/app/innertune-affirmations/id6443625379
32. BetterSleep/Endel betalningsdiskussion. https://www.reddit.com/r/sleep/comments/1l43pks/bettersleep_app_to_worsleep_app/
33. Waking Up App Store reviews. https://apps.apple.com/us/app/waking-up-meditation-wisdom/id1307736395?see-all=reviews
34. Digital journaling betalnings- och integritetsdiskussion. https://www.reddit.com/r/digitaljournaling/comments/1oevtn3/what_digital_journaling_app_are_you_actually/
35. Breathwork HRV-diskussion. https://www.reddit.com/r/breathwork/comments/1qmev5j/what_are_the_best_apps_for_breathwork/
36. HRV4 Biofeedback betalningsdiskussion. https://www.reddit.com/r/Neurofeedback/comments/1pwnoxq/hrv_biofeedback/

### Interna underlag

37. `GROWTH_PLAN.md`, granskat 2026-09-05.
38. `Research/2026-09-03/report-source.md` och `Research/2026-09-04/report-source.md`, tidigare signalkartor.
39. Vindla-kodbas och publik webb, granskat 2026-09-05. Se kodhänvisningarna ovan.
