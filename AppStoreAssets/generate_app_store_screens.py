from pathlib import Path
import math
import unicodedata

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "AppStoreAssets"

W, H = 1290, 2796
SCREEN_W, SCREEN_H = 1170, 2532
PHONE_SCREEN_W = 950
PHONE_SCREEN_H = round(PHONE_SCREEN_W * SCREEN_H / SCREEN_W)
BEZEL = 28
PHONE_W = PHONE_SCREEN_W + BEZEL * 2
PHONE_H = PHONE_SCREEN_H + BEZEL * 2
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = 610

FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_BOLD = "/System/Library/Fonts/SFNS.ttf"
FONT_SERIF = "/System/Library/Fonts/NewYork.ttf"


def normalized_path(path: str) -> Path:
    return Path(unicodedata.normalize("NFC", path))


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def vertical_gradient(top, bottom):
    image = Image.new("RGB", (W, H), top)
    pixels = image.load()
    for y in range(H):
        t = y / (H - 1)
        for x in range(W):
            pixels[x, y] = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
    return image.convert("RGBA")


def add_radial_glow(base, center, radius, color, alpha):
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    px = overlay.load()
    cx, cy = center
    for y in range(max(0, cy - radius), min(H, cy + radius)):
        for x in range(max(0, cx - radius), min(W, cx + radius)):
            d = math.hypot(x - cx, y - cy) / radius
            if d < 1:
                a = round(alpha * (1 - d) ** 2)
                px[x, y] = (*color, a)
    base.alpha_composite(overlay)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def draw_text_block(draw, title, subtitle, title_color=(255, 255, 255), subtitle_color=(201, 198, 207)):
    title_font = font(FONT_BOLD, 82)
    subtitle_font = font(FONT_REGULAR, 38)
    max_width = W - 132

    def wrap(text, f):
        words = text.split()
        lines = []
        current = ""
        for word in words:
            candidate = f"{current} {word}".strip()
            if draw.textbbox((0, 0), candidate, font=f)[2] <= max_width:
                current = candidate
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        return lines

    title_lines = wrap(title, title_font)
    subtitle_lines = wrap(subtitle, subtitle_font)
    y = 120
    for line in title_lines:
        bbox = draw.textbbox((0, 0), line, font=title_font)
        draw.text(((W - (bbox[2] - bbox[0])) / 2, y), line, font=title_font, fill=title_color)
        y += 94
    y += 14
    for line in subtitle_lines:
        bbox = draw.textbbox((0, 0), line, font=subtitle_font)
        draw.text(((W - (bbox[2] - bbox[0])) / 2, y), line, font=subtitle_font, fill=subtitle_color)
        y += 51


def draw_feature_chips(draw, labels, y, accent):
    chip_font = font(FONT_BOLD, 27)
    gap = 18
    metrics = []
    total = 0
    for label in labels:
        bbox = draw.textbbox((0, 0), label, font=chip_font)
        width = bbox[2] - bbox[0] + 44
        metrics.append((label, width))
        total += width
    total += gap * (len(labels) - 1)
    x = (W - total) // 2
    for label, width in metrics:
        draw.rounded_rectangle((x, y, x + width, y + 54), radius=27, fill=(*accent, 38), outline=(*accent, 96), width=2)
        bbox = draw.textbbox((0, 0), label, font=chip_font)
        draw.text((x + (width - (bbox[2] - bbox[0])) / 2, y + 11), label, font=chip_font, fill=(240, 246, 246))
        x += width + gap


def phone_composite(screenshot_path):
    shot = Image.open(screenshot_path).convert("RGBA").resize((PHONE_SCREEN_W, PHONE_SCREEN_H), Image.Resampling.LANCZOS)

    phone = Image.new("RGBA", (PHONE_W, PHONE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(phone)
    d.rounded_rectangle((0, 0, PHONE_W - 1, PHONE_H - 1), radius=96, fill=(7, 7, 13, 255))
    d.rounded_rectangle((8, 8, PHONE_W - 9, PHONE_H - 9), radius=88, outline=(255, 255, 255, 30), width=2)

    screen_mask = rounded_mask((PHONE_SCREEN_W, PHONE_SCREEN_H), 70)
    phone.paste(shot, (BEZEL, BEZEL), screen_mask)
    return phone


def paste_phone(base, screenshot_path):
    shadow = Image.new("RGBA", (PHONE_W + 150, PHONE_H + 150), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((75, 75, 75 + PHONE_W, 75 + PHONE_H), radius=110, fill=(0, 0, 0, 190))
    shadow = shadow.filter(ImageFilter.GaussianBlur(42))
    base.alpha_composite(shadow, (PHONE_X - 75, PHONE_Y - 55))

    phone = phone_composite(screenshot_path)
    base.alpha_composite(phone, (PHONE_X, PHONE_Y))


def decorate(base, theme):
    d = ImageDraw.Draw(base, "RGBA")
    if theme == "home":
        add_radial_glow(base, (250, 780), 620, (93, 128, 112), 175)
        add_radial_glow(base, (1060, 430), 520, (82, 94, 184), 135)
        add_radial_glow(base, (880, 2120), 700, (34, 107, 156), 105)
        d.arc((-280, 930, 620, 1830), start=286, end=62, fill=(161, 211, 194, 62), width=8)
        d.arc((720, 320, 1640, 1240), start=104, end=246, fill=(151, 141, 220, 50), width=7)
    elif theme == "sleep":
        add_radial_glow(base, (200, 600), 680, (148, 108, 86), 120)
        add_radial_glow(base, (1080, 520), 560, (55, 85, 140), 150)
        add_radial_glow(base, (730, 2240), 820, (42, 75, 102), 116)
        d.ellipse((1084, 282, 1186, 384), fill=(255, 232, 177, 45), outline=(255, 239, 198, 64), width=2)
        for x, y, a in [(180, 420, 85), (260, 520, 55), (1010, 340, 70), (1125, 710, 52), (160, 2190, 40)]:
            d.ellipse((x, y, x + 5, y + 5), fill=(255, 255, 240, a))
    else:
        add_radial_glow(base, (230, 650), 700, (71, 136, 112), 158)
        add_radial_glow(base, (1050, 520), 620, (86, 104, 184), 128)
        add_radial_glow(base, (760, 2240), 760, (44, 119, 132), 118)
        for i in range(6):
            y = 380 + i * 62
            d.arc((90, y, 1190, y + 410), start=190, end=350, fill=(142, 226, 212, 24 + i * 3), width=4)


def make_asset(filename, screenshot, title, subtitle, chips, theme, top, bottom, accent):
    base = vertical_gradient(top, bottom)
    decorate(base, theme)
    d = ImageDraw.Draw(base, "RGBA")
    draw_text_block(d, title, subtitle)
    draw_feature_chips(d, chips, 480, accent)
    paste_phone(base, screenshot)
    base.convert("RGB").save(OUT / filename, "PNG", optimize=True)


def main():
    sleep = normalized_path("/Users/elias/Downloads/Skärmavbild 2026-05-06 kl. 13.48.41.png")
    sound = normalized_path("/Users/elias/Downloads/Skärmavbild 2026-05-06 kl. 13.50.17.png")
    home = normalized_path("/Users/elias/Downloads/Skärmavbild 2026-05-06 kl. 13.56.09.png")

    make_asset(
        "01-meditation-shaped-around-you.png",
        home,
        "Meditation, shaped around you",
        "Speak your mood and let Mimir build a session for this moment.",
        ["Mimir", "Mood guided", "7-day path"],
        "home",
        (10, 9, 20),
        (18, 28, 38),
        (131, 205, 184),
    )
    make_asset(
        "02-sleep-stories.png",
        sleep,
        "Drift into personalized sleep stories",
        "Choose a theme, set the length, and let the night slow down.",
        ["Sleep stories", "1-20 min", "Fresh themes"],
        "sleep",
        (12, 9, 20),
        (31, 28, 42),
        (235, 196, 144),
    )
    make_asset(
        "03-soundscapes.png",
        sound,
        "Soundscapes for deeper calm",
        "Blend nature loops, frequencies, chimes, and soft ambience.",
        ["Binaural beats", "Nature loops", "Chimes"],
        "sound",
        (9, 10, 22),
        (18, 38, 43),
        (118, 220, 208),
    )


if __name__ == "__main__":
    main()
