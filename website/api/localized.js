const BASE_URL = "https://vindla-three.vercel.app";
const APP_STORE_URL = "https://apps.apple.com/us/app/vindla/id6761864704";

const LOCALES = {
  da: {
    lang: "da",
    title: "Personlig meditation til iPhone | Vindla",
    description: "Fortæl Mimir, hvordan du har det, vælg tid og guidestil, og få en personlig meditation til øjeblikket. Prøv Vindla gratis på iPhone uden konto.",
    navTry: "Prøv ét minut",
    navHow: "Sådan virker det",
    navGet: "Hent appen",
    eyebrow: "Personlig meditation til iPhone",
    headline: "En meditation skabt til det øjeblik, du er i.",
    lead: "Beskriv, hvad der fylder, vælg hvor meget tid du har, og lad Mimir forme en guidet meditation efter dit humør og din foretrukne stil.",
    primary: "Prøv Vindla gratis",
    secondary: "Se, hvordan det virker",
    trust: "Ingen konto · Tre gratis Mimir-sessioner hver måned · Gem dem, du vil vende tilbage til",
    screenshotAlt: "Vindlas engelske App Store-billede med palmer og personlig meditation",
    howEyebrow: "Sådan virker det",
    howTitle: "Start med én ærlig sætning.",
    howIntro: "Du behøver ikke gennemse hundredvis af optagelser eller kende den rigtige teknik på forhånd.",
    steps: [
      ["Fortæl, hvad der sker", "Skriv naturligt: “Jeg har tre minutter før et svært møde” eller “Mine tanker kører stadig ved sengetid.”"],
      ["Vælg tid og tone", "Vælg en realistisk varighed og en af otte guidestile, fra enkel Zen Minimalist til tryg Warm Guardian."],
      ["Begynd denne session", "Mimir skaber struktureret vejledning til øjeblikket. Gem sessionen, hvis du vil vende tilbage til den."]
    ],
    momentsEyebrow: "Til virkelige øjeblikke",
    momentsTitle: "Når en almindelig optagelse ikke helt passer.",
    moments: [
      ["Før et møde", "Gå fra indre gennemgang og spænding til det næste konkrete øjeblik."],
      ["Efter en lang dag", "Giv sindet en overgang, før arbejdet følger med ind i aftenen."],
      ["Når fokus spreder sig", "Sæt ord på støjen, saml opmærksomheden, og vælg ét sted at begynde."],
      ["Ved sengetid", "Bed om et langsommere tempo, eller åbn Vindlas fortællende søvnunivers."]
    ],
    screensEyebrow: "Ét visuelt udtryk",
    screensTitle: "Palmer, skov og nat — de samme stærke billeder overalt.",
    screensIntro: "Vindla bruger den engelske App Store-serie i alle lande, mens appen og den søgbare tekst er lokaliseret.",
    privacyEyebrow: "Personligt uden konto",
    privacyTitle: "Din praksis tilhører dig.",
    privacyBody: "Vindla kræver ingen konto. Din historik og dit gemte bibliotek bliver på din enhed. Når Mimir skaber en session, sendes din tekst og valgte varighed til Vindlas cloudtjeneste.",
    privacyLink: "Læs privatlivspolitikken",
    faqTitle: "Før din første session.",
    faqs: [
      ["Hvordan virker en personlig meditation?", "Fortæl Mimir, hvad der fylder, vælg varighed og guidestil, og Vindla skaber en struktureret session til øjeblikket."],
      ["Skal jeg oprette en konto?", "Nej. Vindla virker uden konto og indeholder tre gratis Mimir-sessioner hver måned."],
      ["Kan jeg gemme en session?", "Ja. Gem en Mimir-rejse i biblioteket, giv den et nyt navn, og vend tilbage senere."]
    ],
    finalEyebrow: "Start dér, hvor du er",
    finalTitle: "Fortæl Mimir, hvordan du har det lige nu.",
    finalBody: "Vælg et par minutter og din guide, og begynd uden at oprette en konto.",
    finalCta: "Hent Vindla gratis på iPhone",
    footer: "En meditation skabt til det, du mærker lige nu."
  },
  fr: {
    lang: "fr",
    title: "Méditation personnalisée sur iPhone | Vindla",
    description: "Dites à Mimir comment vous vous sentez, choisissez la durée et le style de guide, puis recevez une méditation personnalisée. Essayez Vindla gratuitement, sans compte.",
    navTry: "Essayer une minute",
    navHow: "Comment ça marche",
    navGet: "Télécharger",
    eyebrow: "Méditation personnalisée sur iPhone",
    headline: "Une méditation pensée pour le moment que vous vivez.",
    lead: "Décrivez ce qui vous préoccupe, choisissez le temps dont vous disposez et laissez Mimir façonner une méditation guidée selon votre humeur et le style qui vous convient.",
    primary: "Essayer Vindla gratuitement",
    secondary: "Voir comment ça marche",
    trust: "Aucun compte · Trois séances Mimir gratuites par mois · Enregistrez celles que vous souhaitez retrouver",
    screenshotAlt: "Capture App Store anglaise de Vindla avec palmiers et méditation personnalisée",
    howEyebrow: "Comment ça marche",
    howTitle: "Commencez par une phrase sincère.",
    howIntro: "Pas besoin de parcourir des centaines d’enregistrements ni de connaître la bonne technique à l’avance.",
    steps: [
      ["Dites ce qui se passe", "Écrivez naturellement : « J’ai trois minutes avant une réunion difficile » ou « Mon esprit continue de tourner au coucher »."],
      ["Choisissez le temps et le ton", "Sélectionnez une durée réaliste et l’un des huit styles de guide, du sobre Zen Minimalist au rassurant Warm Guardian."],
      ["Commencez cette séance", "Mimir crée un accompagnement structuré pour ce moment. Enregistrez la séance si vous souhaitez y revenir."]
    ],
    momentsEyebrow: "Pour les vrais moments",
    momentsTitle: "Quand un enregistrement générique ne correspond pas tout à fait.",
    moments: [
      ["Avant une réunion", "Passez des répétitions mentales et de la tension au prochain instant concret."],
      ["Après une longue journée", "Offrez à votre esprit une transition avant que le travail ne gagne votre soirée."],
      ["Quand l’attention se disperse", "Nommez le bruit, rassemblez votre attention et choisissez un point de départ."],
      ["Au coucher", "Demandez un rythme plus lent ou ouvrez l’espace d’histoires nocturnes de Vindla."]
    ],
    screensEyebrow: "Une identité visuelle cohérente",
    screensTitle: "Palmiers, forêt et nuit — les mêmes images fortes partout.",
    screensIntro: "Vindla utilise la série anglaise de captures App Store dans tous les pays, tandis que l’app et les textes de recherche sont localisés.",
    privacyEyebrow: "Personnel, sans compte",
    privacyTitle: "Votre pratique vous appartient.",
    privacyBody: "Vindla ne nécessite aucun compte. Votre historique et votre bibliothèque restent sur votre appareil. Pour créer une séance Mimir, votre texte et la durée choisie sont envoyés au service cloud de Vindla.",
    privacyLink: "Lire la politique de confidentialité",
    faqTitle: "Avant votre première séance.",
    faqs: [
      ["Comment fonctionne une méditation personnalisée ?", "Dites à Mimir ce qui vous préoccupe, choisissez une durée et un style de guide, puis Vindla crée une séance structurée pour ce moment."],
      ["Dois-je créer un compte ?", "Non. Vindla fonctionne sans compte et comprend trois séances Mimir gratuites chaque mois."],
      ["Puis-je enregistrer une séance ?", "Oui. Enregistrez un voyage Mimir dans votre bibliothèque, renommez-le et retrouvez-le plus tard."]
    ],
    finalEyebrow: "Commencez là où vous êtes",
    finalTitle: "Dites à Mimir comment vous vous sentez maintenant.",
    finalBody: "Choisissez quelques minutes et votre guide, puis commencez sans créer de compte.",
    finalCta: "Télécharger Vindla gratuitement sur iPhone",
    footer: "Une méditation pensée pour ce que vous ressentez maintenant."
  },
  nb: {
    lang: "nb",
    title: "Personlig meditasjon for iPhone | Vindla",
    description: "Fortell Mimir hvordan du har det, velg tid og guidestil, og få en personlig meditasjon for øyeblikket. Prøv Vindla gratis på iPhone uten konto.",
    navTry: "Prøv ett minutt",
    navHow: "Slik fungerer det",
    navGet: "Hent appen",
    eyebrow: "Personlig meditasjon for iPhone",
    headline: "En meditasjon laget for øyeblikket du er i.",
    lead: "Beskriv hva du har på hjertet, velg hvor mye tid du har, og la Mimir forme en guidet meditasjon etter humøret ditt og stilen du foretrekker.",
    primary: "Prøv Vindla gratis",
    secondary: "Se hvordan det fungerer",
    trust: "Ingen konto · Tre gratis Mimir-økter hver måned · Lagre dem du vil vende tilbake til",
    screenshotAlt: "Vindlas engelske App Store-bilde med palmer og personlig meditasjon",
    howEyebrow: "Slik fungerer det",
    howTitle: "Start med én ærlig setning.",
    howIntro: "Du trenger ikke bla gjennom hundrevis av opptak eller kjenne riktig teknikk på forhånd.",
    steps: [
      ["Fortell hva som skjer", "Skriv naturlig: «Jeg har tre minutter før et vanskelig møte» eller «Tankene mine går fortsatt ved leggetid»."],
      ["Velg tid og tone", "Velg en realistisk varighet og én av åtte guidestiler, fra enkel Zen Minimalist til trygg Warm Guardian."],
      ["Begynn denne økten", "Mimir lager strukturert veiledning for øyeblikket. Lagre økten hvis du vil vende tilbake til den."]
    ],
    momentsEyebrow: "For virkelige øyeblikk",
    momentsTitle: "Når et generelt opptak ikke passer helt.",
    moments: [
      ["Før et møte", "Gå fra indre øving og spenning til det neste konkrete øyeblikket."],
      ["Etter en lang dag", "Gi tankene en overgang før arbeidet følger med inn i kvelden."],
      ["Når fokuset sprer seg", "Sett ord på støyen, samle oppmerksomheten og velg ett sted å begynne."],
      ["Ved leggetid", "Be om et roligere tempo eller åpne Vindlas historiebaserte nattmodus."]
    ],
    screensEyebrow: "Ett tydelig visuelt uttrykk",
    screensTitle: "Palmer, skog og natt — de samme sterke bildene overalt.",
    screensIntro: "Vindla bruker den engelske App Store-serien i alle land, mens appen og den søkbare teksten er lokalisert.",
    privacyEyebrow: "Personlig uten konto",
    privacyTitle: "Praksisen din tilhører deg.",
    privacyBody: "Vindla krever ingen konto. Historikken og det lagrede biblioteket blir på enheten din. Når Mimir lager en økt, sendes teksten og valgt varighet til Vindlas skytjeneste.",
    privacyLink: "Les personvernerklæringen",
    faqTitle: "Før den første økten.",
    faqs: [
      ["Hvordan fungerer en personlig meditasjon?", "Fortell Mimir hva du har på hjertet, velg varighet og guidestil, og Vindla lager en strukturert økt for øyeblikket."],
      ["Må jeg opprette en konto?", "Nei. Vindla fungerer uten konto og inkluderer tre gratis Mimir-økter hver måned."],
      ["Kan jeg lagre en økt?", "Ja. Lagre en Mimir-reise i biblioteket, gi den et nytt navn og kom tilbake senere."]
    ],
    finalEyebrow: "Start der du er",
    finalTitle: "Fortell Mimir hvordan du har det akkurat nå.",
    finalBody: "Velg noen minutter og guiden din, og begynn uten å opprette en konto.",
    finalCta: "Hent Vindla gratis på iPhone",
    footer: "En meditasjon laget for det du kjenner akkurat nå."
  },
  es: {
    lang: "es",
    title: "Meditación personalizada para iPhone | Vindla",
    description: "Cuéntale a Mimir cómo te sientes, elige la duración y el estilo de guía, y recibe una meditación personalizada. Prueba Vindla gratis y sin cuenta.",
    navTry: "Prueba un minuto",
    navHow: "Cómo funciona",
    navGet: "Descargar",
    eyebrow: "Meditación personalizada para iPhone",
    headline: "Una meditación creada para el momento que estás viviendo.",
    lead: "Describe lo que tienes en mente, elige cuánto tiempo tienes y deja que Mimir cree una meditación guiada según tu estado de ánimo y el estilo que prefieras.",
    primary: "Prueba Vindla gratis",
    secondary: "Descubre cómo funciona",
    trust: "Sin cuenta · Tres sesiones gratuitas de Mimir al mes · Guarda las que quieras repetir",
    screenshotAlt: "Captura inglesa de Vindla en el App Store con palmeras y meditación personalizada",
    howEyebrow: "Cómo funciona",
    howTitle: "Empieza con una frase sincera.",
    howIntro: "No hace falta explorar cientos de grabaciones ni conocer de antemano la técnica adecuada.",
    steps: [
      ["Cuenta qué está pasando", "Escribe con naturalidad: «Tengo tres minutos antes de una reunión difícil» o «Mi mente sigue activa a la hora de dormir»."],
      ["Elige tiempo y tono", "Escoge una duración realista y uno de ocho estilos de guía, desde el sencillo Zen Minimalist hasta el tranquilizador Warm Guardian."],
      ["Empieza esta sesión", "Mimir crea una guía estructurada para ese momento. Guarda la sesión si quieres volver a ella."]
    ],
    momentsEyebrow: "Para momentos reales",
    momentsTitle: "Cuando una grabación genérica no encaja del todo.",
    moments: [
      ["Antes de una reunión", "Pasa del ensayo mental y la tensión al siguiente momento concreto."],
      ["Después de un día largo", "Dale a tu mente una transición antes de llevarte el trabajo a la noche."],
      ["Cuando el enfoque se dispersa", "Pon nombre al ruido, reúne tu atención y elige un único punto de partida."],
      ["A la hora de dormir", "Pide un ritmo más lento o abre el espacio nocturno de historias de Vindla."]
    ],
    screensEyebrow: "Una identidad visual coherente",
    screensTitle: "Palmeras, bosque y noche: las mismas imágenes potentes en todas partes.",
    screensIntro: "Vindla utiliza la serie inglesa de capturas del App Store en todos los países, mientras la app y el texto de búsqueda están localizados.",
    privacyEyebrow: "Personal, sin cuenta",
    privacyTitle: "Tu práctica te pertenece.",
    privacyBody: "Vindla no requiere una cuenta. Tu historial y biblioteca guardada permanecen en tu dispositivo. Para crear una sesión de Mimir, el texto y la duración elegida se envían al servicio en la nube de Vindla.",
    privacyLink: "Leer la política de privacidad",
    faqTitle: "Antes de tu primera sesión.",
    faqs: [
      ["¿Cómo funciona una meditación personalizada?", "Cuéntale a Mimir qué tienes en mente, elige la duración y el estilo de guía, y Vindla crea una sesión estructurada para ese momento."],
      ["¿Necesito crear una cuenta?", "No. Vindla funciona sin cuenta e incluye tres sesiones gratuitas de Mimir cada mes."],
      ["¿Puedo guardar una sesión?", "Sí. Guarda un viaje de Mimir en tu biblioteca, cámbiale el nombre y vuelve a él más adelante."]
    ],
    finalEyebrow: "Empieza donde estás",
    finalTitle: "Cuéntale a Mimir cómo te sientes ahora.",
    finalBody: "Elige unos minutos y tu guía, y empieza sin crear una cuenta.",
    finalCta: "Descarga Vindla gratis para iPhone",
    footer: "Una meditación creada para lo que sientes ahora."
  },
  sv: {
    lang: "sv",
    title: "Personlig meditation för iPhone | Vindla",
    description: "Berätta för Mimir hur du mår, välj tid och guidestil och få en personlig meditation för stunden. Prova Vindla gratis på iPhone utan konto.",
    navTry: "Prova en minut",
    navHow: "Så fungerar det",
    navGet: "Hämta appen",
    eyebrow: "Personlig meditation för iPhone",
    headline: "En meditation skapad för stunden du befinner dig i.",
    lead: "Beskriv vad som pågår, välj hur mycket tid du har och låt Mimir forma en guidad meditation efter ditt humör och den stil du föredrar.",
    primary: "Prova Vindla gratis",
    secondary: "Se hur det fungerar",
    trust: "Inget konto · Tre kostnadsfria Mimir-sessioner varje månad · Spara dem du vill återvända till",
    screenshotAlt: "Vindlas engelska App Store-bild med palmer och personlig meditation",
    howEyebrow: "Så fungerar det",
    howTitle: "Börja med en ärlig mening.",
    howIntro: "Du behöver inte bläddra bland hundratals inspelningar eller känna till rätt teknik i förväg.",
    steps: [
      ["Berätta vad som händer", "Skriv naturligt: ”Jag har tre minuter före ett svårt möte” eller ”Mina tankar fortsätter snurra vid läggdags”."],
      ["Välj tid och ton", "Välj en realistisk längd och en av åtta guidestilar, från avskalade Zen Minimalist till trygga Warm Guardian."],
      ["Börja den här sessionen", "Mimir skapar strukturerad vägledning för stunden. Spara sessionen om du vill återvända till den."]
    ],
    momentsEyebrow: "För verkliga stunder",
    momentsTitle: "När en allmän inspelning inte riktigt passar.",
    moments: [
      ["Före ett möte", "Gå från inre repetition och spänning till nästa konkreta ögonblick."],
      ["Efter en lång dag", "Ge tankarna en övergång innan arbetet följer med in i kvällen."],
      ["När fokuset splittras", "Sätt ord på bruset, samla uppmärksamheten och välj en plats att börja på."],
      ["Vid läggdags", "Be om ett långsammare tempo eller öppna Vindlas berättelsedrivna nattläge."]
    ],
    screensEyebrow: "Ett tydligt visuellt uttryck",
    screensTitle: "Palmer, skog och natt — samma starka bilder överallt.",
    screensIntro: "Vindla använder den engelska App Store-serien i alla länder, medan appen och den sökbara texten är lokaliserad.",
    privacyEyebrow: "Personligt utan konto",
    privacyTitle: "Din praktik tillhör dig.",
    privacyBody: "Vindla kräver inget konto. Din historik och ditt sparade bibliotek stannar på din enhet. När Mimir skapar en session skickas din text och valda längd till Vindlas molntjänst.",
    privacyLink: "Läs integritetspolicyn",
    faqTitle: "Före din första session.",
    faqs: [
      ["Hur fungerar en personlig meditation?", "Berätta för Mimir vad som pågår, välj längd och guidestil, så skapar Vindla en strukturerad session för stunden."],
      ["Behöver jag skapa ett konto?", "Nej. Vindla fungerar utan konto och innehåller tre kostnadsfria Mimir-sessioner varje månad."],
      ["Kan jag spara en session?", "Ja. Spara en Mimir-resa i biblioteket, byt namn på den och återvänd senare."]
    ],
    finalEyebrow: "Börja där du är",
    finalTitle: "Berätta för Mimir hur du mår just nu.",
    finalBody: "Välj några minuter och din guide och börja utan att skapa ett konto.",
    finalCta: "Hämta Vindla gratis på iPhone",
    footer: "En meditation skapad för det du känner just nu."
  }
};

const LOCALE_PATHS = {
  en: "/personalized-meditation",
  da: "/da",
  fr: "/fr",
  nb: "/nb",
  es: "/es",
  sv: "/sv"
};

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function absoluteURL(pathname) {
  return `${BASE_URL}${pathname}`;
}

function renderLocalizedPage(localeCode) {
  const content = LOCALES[localeCode];
  if (!content) return null;

  const canonicalURL = absoluteURL(LOCALE_PATHS[localeCode]);
  const alternates = Object.entries(LOCALE_PATHS)
    .map(([language, pathname]) =>
      `<link rel="alternate" hreflang="${language}" href="${absoluteURL(pathname)}">`
    )
    .concat(`<link rel="alternate" hreflang="x-default" href="${absoluteURL(LOCALE_PATHS.en)}">`)
    .join("\n    ");
  const sourcePrefix = `locale_${localeCode}`;
  const schema = JSON.stringify({
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: content.title,
        url: canonicalURL,
        inLanguage: content.lang,
        description: content.description
      },
      {
        "@type": "SoftwareApplication",
        name: "Vindla",
        operatingSystem: "iOS",
        applicationCategory: "HealthApplication",
        downloadUrl: APP_STORE_URL,
        offers: {"@type": "Offer", price: "0", priceCurrency: "USD"}
      },
      {
        "@type": "FAQPage",
        mainEntity: content.faqs.map(([question, answer]) => ({
          "@type": "Question",
          name: question,
          acceptedAnswer: {"@type": "Answer", text: answer}
        }))
      }
    ]
  });
  const steps = content.steps
    .map(([title, body], index) => `<article><span>0${index + 1}</span><h3>${escapeHTML(title)}</h3><p>${escapeHTML(body)}</p></article>`)
    .join("");
  const moments = content.moments
    .map(([title, body]) => `<li><strong>${escapeHTML(title)}</strong><span>${escapeHTML(body)}</span></li>`)
    .join("");
  const faqs = content.faqs
    .map(([question, answer]) => `<article><h3>${escapeHTML(question)}</h3><p>${escapeHTML(answer)}</p></article>`)
    .join("");
  const languageLinks = Object.entries(LOCALE_PATHS)
    .map(([language, pathname]) => `<a href="${pathname}" hreflang="${language}" lang="${language}">${language.toUpperCase()}</a>`)
    .join("");

  return `<!DOCTYPE html>
<html lang="${content.lang}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${escapeHTML(content.title)}</title>
    <meta name="description" content="${escapeHTML(content.description)}">
    <link rel="canonical" href="${canonicalURL}">
    <link rel="describedby" href="/llms.txt" type="text/markdown">
    ${alternates}
    <meta name="apple-itunes-app" content="app-id=6761864704">
    <meta property="og:type" content="website">
    <meta property="og:url" content="${canonicalURL}">
    <meta property="og:title" content="${escapeHTML(content.headline)} — Vindla">
    <meta property="og:description" content="${escapeHTML(content.description)}">
    <meta property="og:image" content="${BASE_URL}/press-assets/vindla-app-store-palm.png">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${escapeHTML(content.headline)} — Vindla">
    <meta name="twitter:description" content="${escapeHTML(content.description)}">
    <meta name="twitter:image" content="${BASE_URL}/press-assets/vindla-app-store-palm.png">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&amp;family=Outfit:wght@300;400;500;600;700&amp;display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/styles.css">
    <script type="application/ld+json">${schema}</script>
</head>
<body>
    <div class="page-shell use-case-shell">
        <header class="site-header use-case-header">
            <a class="brand" href="/" aria-label="Vindla">Vindla</a>
            <nav class="top-nav" aria-label="Navigation">
                <a href="/breathe">${escapeHTML(content.navTry)}</a>
                <a href="#how-it-works">${escapeHTML(content.navHow)}</a>
                <a class="nav-button" href="/download?campaign=website&amp;source=${sourcePrefix}_nav">${escapeHTML(content.navGet)}</a>
            </nav>
        </header>
        <main>
            <section class="use-case-hero locale-hero">
                <div class="use-case-hero-copy">
                    <span class="eyebrow">${escapeHTML(content.eyebrow)}</span>
                    <h1>${escapeHTML(content.headline)}</h1>
                    <p class="lead">${escapeHTML(content.lead)}</p>
                    <div class="hero-actions">
                        <a class="primary-button" href="/download?campaign=website&amp;source=${sourcePrefix}_hero">${escapeHTML(content.primary)}</a>
                        <a class="secondary-button" href="#how-it-works">${escapeHTML(content.secondary)}</a>
                    </div>
                    <p class="trust-line">${escapeHTML(content.trust)}</p>
                </div>
                <div class="use-case-visual locale-visual">
                    <img src="/press-assets/vindla-app-store-palm.png" alt="${escapeHTML(content.screenshotAlt)}">
                </div>
            </section>
            <section class="use-case-section" id="how-it-works" aria-labelledby="how-title">
                <div class="use-case-heading">
                    <span class="eyebrow">${escapeHTML(content.howEyebrow)}</span>
                    <h2 id="how-title">${escapeHTML(content.howTitle)}</h2>
                    <p>${escapeHTML(content.howIntro)}</p>
                </div>
                <div class="step-grid">${steps}</div>
            </section>
            <section class="use-case-panel" aria-labelledby="moments-title">
                <div><span class="eyebrow">${escapeHTML(content.momentsEyebrow)}</span><h2 id="moments-title">${escapeHTML(content.momentsTitle)}</h2></div>
                <ul class="moment-list">${moments}</ul>
            </section>
            <section class="use-case-section locale-gallery-section" aria-labelledby="screens-title">
                <div class="use-case-heading">
                    <span class="eyebrow">${escapeHTML(content.screensEyebrow)}</span>
                    <h2 id="screens-title">${escapeHTML(content.screensTitle)}</h2>
                    <p>${escapeHTML(content.screensIntro)}</p>
                </div>
                <div class="locale-screenshots">
                    <img src="/press-assets/vindla-app-store-palm.png" alt="${escapeHTML(content.screenshotAlt)}">
                    <img src="/press-assets/vindla-app-store-forest.png" alt="Vindla App Store — forest">
                    <img src="/press-assets/vindla-app-store-night.png" alt="Vindla App Store — night">
                </div>
            </section>
            <section class="use-case-section use-case-split" aria-labelledby="privacy-title">
                <div><span class="eyebrow">${escapeHTML(content.privacyEyebrow)}</span><h2 id="privacy-title">${escapeHTML(content.privacyTitle)}</h2></div>
                <div class="prose-stack"><p>${escapeHTML(content.privacyBody)}</p><p><a href="/privacy">${escapeHTML(content.privacyLink)}</a>.</p></div>
            </section>
            <section class="faq-section use-case-faq" aria-labelledby="faq-title">
                <span class="eyebrow">FAQ</span><h2 id="faq-title">${escapeHTML(content.faqTitle)}</h2>
                <div class="faq-grid">${faqs}</div>
            </section>
            <section class="use-case-cta">
                <span class="eyebrow">${escapeHTML(content.finalEyebrow)}</span>
                <h2>${escapeHTML(content.finalTitle)}</h2>
                <p>${escapeHTML(content.finalBody)}</p>
                <a class="primary-button" href="/download?campaign=website&amp;source=${sourcePrefix}_final">${escapeHTML(content.finalCta)}</a>
            </section>
        </main>
        <footer class="site-footer use-case-footer">
            <div><a class="brand footer-brand" href="/">Vindla</a><p>${escapeHTML(content.footer)}</p></div>
            <nav class="footer-links locale-links" aria-label="Languages">${languageLinks}</nav>
        </footer>
    </div>
    <a class="mobile-install" href="/download?campaign=website&amp;source=${sourcePrefix}_mobile">${escapeHTML(content.navGet)}</a>
</body>
</html>`;
}

function localeFromRequest(request) {
  const requestURL = new URL(request.url || "/api/localized", BASE_URL);
  return requestURL.searchParams.get("locale");
}

function localizedHandler(request, response) {
  const localeCode = localeFromRequest(request);
  const page = renderLocalizedPage(localeCode);
  response.setHeader("Cache-Control", "public, s-maxage=3600, stale-while-revalidate=86400");
  response.setHeader("Content-Type", "text/html; charset=utf-8");
  if (!page) {
    response.statusCode = 404;
    response.end("Not found");
    return;
  }
  response.statusCode = 200;
  response.end(page);
}

module.exports = localizedHandler;
module.exports.LOCALES = LOCALES;
module.exports.LOCALE_PATHS = LOCALE_PATHS;
module.exports.localeFromRequest = localeFromRequest;
module.exports.renderLocalizedPage = renderLocalizedPage;
