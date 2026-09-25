from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "MarketingAssets" / "AppStoreScreens"
UI_CAPTURE_DIR = OUTPUT_DIR / "LocalizedUICaptures"
BACKGROUND_DIR = OUTPUT_DIR / "Backgrounds"

W, H = 1242, 2688
PHONE_SCREEN_W = 1040
PHONE_SCREEN_H = round(PHONE_SCREEN_W * 2868 / 1320)
BEZEL = 28
PHONE_W = PHONE_SCREEN_W + BEZEL * 2
PHONE_H = PHONE_SCREEN_H + BEZEL * 2
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = 610

FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_SERIF = "/System/Library/Fonts/NewYork.ttf"


SCREENS = [
    {
        "filename": "01-meditation-shaped-around-you.png",
        "theme": "home",
        "background": "palm-beach-clean.png",
        "copy_index": 0,
        "accent": (151, 241, 255),
        "title_color": (255, 255, 255),
    },
    {
        "filename": "02-soundscapes.png",
        "theme": "sound",
        "background": "sunlit-forest-clean.png",
        "copy_index": 2,
        "accent": (194, 222, 119),
        "title_color": (255, 255, 255),
    },
    {
        "filename": "03-sleep-stories.png",
        "theme": "sleep",
        "background": "moonlit-night-clean.png",
        "copy_index": 1,
        "accent": (255, 218, 141),
        "title_color": (255, 220, 148),
    },
]

LOCALIZATIONS = {
    "da": [
        {
            "title": "Meditation, skabt til dig",
            "subtitle": "Beskriv dit humør, og lad Mimir skabe en session til øjeblikket.",
        },
        {
            "title": "Fald i søvn til personlige historier",
            "subtitle": "Vælg tema og længde, og lad natten falde til ro.",
        },
        {
            "title": "Lydlandskaber til dybere ro",
            "subtitle": "Bland naturlyde, frekvenser, klangspil og blød atmosfære.",
        },
    ],
    "fr": [
        {
            "title": "Une méditation faite pour vous",
            "subtitle": "Exprimez votre humeur et laissez Mimir créer une séance pour cet instant.",
        },
        {
            "title": "Endormez-vous avec une histoire personnalisée",
            "subtitle": "Choisissez un thème et une durée, puis laissez la nuit ralentir.",
        },
        {
            "title": "Des ambiances pour un calme profond",
            "subtitle": "Mélangez nature, fréquences, carillons et sons apaisants.",
        },
    ],
    "nb": [
        {
            "title": "Meditasjon, formet for deg",
            "subtitle": "Beskriv humøret ditt, og la Mimir lage en økt for øyeblikket.",
        },
        {
            "title": "Sov inn med personlige søvnhistorier",
            "subtitle": "Velg tema og lengde, og la natten roe seg.",
        },
        {
            "title": "Lydlandskap for dypere ro",
            "subtitle": "Bland naturlyder, frekvenser, klokkespill og myk atmosfære.",
        },
    ],
    "es": [
        {
            "title": "Meditación hecha a tu medida",
            "subtitle": "Cuenta cómo te sientes y deja que Mimir cree una sesión para este momento.",
        },
        {
            "title": "Duerme con historias personalizadas",
            "subtitle": "Elige un tema y una duración y deja que la noche baje el ritmo.",
        },
        {
            "title": "Sonidos para una calma más profunda",
            "subtitle": "Combina naturaleza, frecuencias, campanas y ambientes suaves.",
        },
    ],
    "sv": [
        {
            "title": "Meditation, formad efter dig",
            "subtitle": "Beskriv ditt humör och låt Mimir skapa en meditation för stunden.",
        },
        {
            "title": "Somna till personliga sömnberättelser",
            "subtitle": "Välj tema och längd och låt natten sakta ner.",
        },
        {
            "title": "Ljudlandskap för djupare lugn",
            "subtitle": "Blanda naturljud, frekvenser, klockspel och mjuk atmosfär.",
        },
    ],
}

LOCALE_NAMES = {
    "da": "Danish",
    "fr": "French",
    "nb": "Norwegian Bokmål",
    "es": "Spanish",
    "sv": "Swedish",
}


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def wrap(draw: ImageDraw.ImageDraw, text: str, selected_font: ImageFont.FreeTypeFont, max_width: int):
    lines = []
    current = ""
    for word in text.split():
        candidate = f"{current} {word}".strip()
        if draw.textbbox((0, 0), candidate, font=selected_font)[2] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def fitted_lines(
    draw: ImageDraw.ImageDraw,
    text: str,
    font_path: str,
    initial_size: int,
    minimum_size: int,
    max_lines: int,
    max_width: int,
):
    for size in range(initial_size, minimum_size - 1, -2):
        selected_font = font(font_path, size)
        lines = wrap(draw, text, selected_font, max_width)
        if len(lines) <= max_lines:
            return selected_font, lines
    raise ValueError(f"Text does not fit in {max_lines} lines: {text}")


def centered_text(draw, line, selected_font, y, fill, stroke_width=0, stroke_fill=None):
    box = draw.textbbox((0, 0), line, font=selected_font, stroke_width=stroke_width)
    line_width = box[2] - box[0]
    draw.text(
        ((W - line_width) / 2, y),
        line,
        font=selected_font,
        fill=fill,
        stroke_width=stroke_width,
        stroke_fill=stroke_fill,
    )


def draw_glowing_divider(base: Image.Image, y: int, accent: tuple[int, int, int]):
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    blurred = ImageDraw.Draw(glow, "RGBA")
    blurred.line((W // 2 - 235, y, W // 2 + 235, y), fill=(*accent, 150), width=5)
    blurred.ellipse((W // 2 - 13, y - 13, W // 2 + 13, y + 13), fill=(*accent, 220))
    glow = glow.filter(ImageFilter.GaussianBlur(15))
    base.alpha_composite(glow)

    draw = ImageDraw.Draw(base, "RGBA")
    draw.line((W // 2 - 235, y, W // 2 + 235, y), fill=(*accent, 110), width=2)
    draw.line((W // 2 - 105, y, W // 2 + 105, y), fill=(255, 255, 255, 195), width=2)
    draw.ellipse((W // 2 - 4, y - 4, W // 2 + 4, y + 4), fill=(255, 255, 255, 235))


def draw_copy(base: Image.Image, copy: dict, screen: dict):
    draw = ImageDraw.Draw(base, "RGBA")
    title_font, title_lines = fitted_lines(
        draw, copy["title"], FONT_SERIF, 100, 66, 3, W - 150
    )
    subtitle_font, subtitle_lines = fitted_lines(
        draw, copy["subtitle"], FONT_REGULAR, 38, 30, 3, W - 180
    )

    title_step = title_font.size + 8
    subtitle_step = subtitle_font.size + 10
    y = 92

    for line in title_lines:
        centered_text(
            draw,
            line,
            title_font,
            y,
            screen["title_color"],
            stroke_width=2,
            stroke_fill=(0, 0, 0, 100),
        )
        y += title_step

    y += 20
    for line in subtitle_lines:
        centered_text(
            draw,
            line,
            subtitle_font,
            y,
            (246, 246, 246, 245),
            stroke_width=2,
            stroke_fill=(0, 0, 0, 150),
        )
        y += subtitle_step

    divider_y = y + 18
    if divider_y > PHONE_Y - 40:
        raise ValueError(f"Copy collides with phone artwork: {copy['title']}")
    draw_glowing_divider(base, divider_y, screen["accent"])


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def phone_composite(capture_path: Path):
    shot = Image.open(capture_path).convert("RGBA")
    shot = ImageOps.fit(shot, (PHONE_SCREEN_W, PHONE_SCREEN_H), Image.Resampling.LANCZOS)

    phone = Image.new("RGBA", (PHONE_W, PHONE_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    draw.rounded_rectangle((0, 0, PHONE_W - 1, PHONE_H - 1), radius=104, fill=(8, 8, 14, 255))
    draw.rounded_rectangle(
        (7, 7, PHONE_W - 8, PHONE_H - 8),
        radius=97,
        outline=(255, 255, 255, 38),
        width=3,
    )
    screen_mask = rounded_mask((PHONE_SCREEN_W, PHONE_SCREEN_H), 76)
    phone.paste(shot, (BEZEL, BEZEL), screen_mask)
    return phone


def paste_phone(base: Image.Image, capture_path: Path):
    shadow = Image.new("RGBA", (PHONE_W + 180, PHONE_H + 180), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle(
        (90, 90, 90 + PHONE_W, 90 + PHONE_H),
        radius=125,
        fill=(0, 0, 0, 205),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(48))
    base.alpha_composite(shadow, (PHONE_X - 90, PHONE_Y - 70))
    base.alpha_composite(phone_composite(capture_path), (PHONE_X, PHONE_Y))


def render_screen(locale: str, screen: dict, copy: dict):
    background_path = BACKGROUND_DIR / screen["background"]
    if not background_path.exists():
        raise FileNotFoundError(f"Missing photographic background: {background_path}")
    base = ImageOps.fit(
        Image.open(background_path).convert("RGBA"),
        (W, H),
        Image.Resampling.LANCZOS,
    )
    draw_copy(base, copy, screen)

    capture = UI_CAPTURE_DIR / locale / f"{screen['theme']}.png"
    if not capture.exists():
        raise FileNotFoundError(f"Missing localized in-app capture: {capture}")
    paste_phone(base, capture)

    locale_dir = OUTPUT_DIR / locale
    locale_dir.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(locale_dir / screen["filename"], "PNG", optimize=True)


def make_contact_sheet(locale: str):
    canvas = Image.new("RGB", (1240, 860), (17, 17, 23))
    locale_dir = OUTPUT_DIR / locale
    for index, screen in enumerate(SCREENS):
        image = Image.open(locale_dir / screen["filename"]).convert("RGB")
        image.thumbnail((360, 780), Image.Resampling.LANCZOS)
        canvas.paste(image, (40 + index * 400, 40))
    canvas.save(locale_dir / "contact-sheet.png", "PNG", optimize=True)


def make_localized_overview():
    canvas = Image.new("RGB", (1240, 1420), (10, 10, 15))
    draw = ImageDraw.Draw(canvas)
    label_font = font(FONT_REGULAR, 28)

    for index, locale in enumerate(LOCALIZATIONS):
        column = index % 2
        row = index // 2
        x = 30 + column * 610
        y = 28 + row * 460
        draw.text((x, y), LOCALE_NAMES[locale], font=label_font, fill=(238, 238, 244))
        sheet = Image.open(OUTPUT_DIR / locale / "contact-sheet.png").convert("RGB")
        sheet.thumbnail((580, 402), Image.Resampling.LANCZOS)
        canvas.paste(sheet, (x, y + 38))

    canvas.save(OUTPUT_DIR / "localized-contact-sheet.png", "PNG", optimize=True)


def main():
    for locale, localized_copy in LOCALIZATIONS.items():
        for screen in SCREENS:
            render_screen(locale, screen, localized_copy[screen["copy_index"]])
        make_contact_sheet(locale)
        print(f"Generated {locale}: {OUTPUT_DIR / locale}")
    make_localized_overview()


if __name__ == "__main__":
    main()
