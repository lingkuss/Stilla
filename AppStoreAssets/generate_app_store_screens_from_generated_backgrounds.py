from pathlib import Path
import unicodedata

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "AppStoreAssets"
GENERATED = Path("/Users/elias/.codex/generated_images/019dfd40-18ba-7001-99f6-379c58b7964b")

W, H = 1290, 2796
SOURCE_W, SOURCE_H = 853, 1844
SCREEN_W, SCREEN_H = 1170, 2532

PHONE_SCREEN_W = 650
PHONE_SCREEN_H = round(PHONE_SCREEN_W * SCREEN_H / SCREEN_W)
BEZEL = 20
PHONE_W = PHONE_SCREEN_W + BEZEL * 2
PHONE_H = PHONE_SCREEN_H + BEZEL * 2
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = 905


def normalized_path(path: str) -> Path:
    return Path(unicodedata.normalize("NFC", path))


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def scale_box(box):
    sx = W / SOURCE_W
    sy = H / SOURCE_H
    return tuple(round(v * (sx if i % 2 == 0 else sy)) for i, v in enumerate(box))


def cover_old_phone(base, source_box, tint):
    box = scale_box(source_box)
    x0, y0, x1, y1 = box
    pad = 90
    sample = base.crop((
        max(0, x0 - pad),
        max(0, y0 - pad),
        min(W, x1 + pad),
        min(H, y1 + pad),
    ))
    sample = sample.resize((max(1, x1 - x0 + pad * 2), max(1, y1 - y0 + pad * 2)), Image.Resampling.BICUBIC)
    sample = sample.filter(ImageFilter.GaussianBlur(72))
    mask = Image.new("L", sample.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, sample.size[0] - 1, sample.size[1] - 1), radius=170, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(34))
    base.paste(sample, (max(0, x0 - pad), max(0, y0 - pad)), mask)
    veil = Image.new("RGBA", sample.size, (*tint, 170))
    base.paste(veil, (max(0, x0 - pad), max(0, y0 - pad)), mask)


def phone_composite(screenshot_path):
    shot = Image.open(screenshot_path).convert("RGBA").resize((PHONE_SCREEN_W, PHONE_SCREEN_H), Image.Resampling.LANCZOS)
    phone = Image.new("RGBA", (PHONE_W, PHONE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(phone, "RGBA")
    d.rounded_rectangle((0, 0, PHONE_W - 1, PHONE_H - 1), radius=78, fill=(5, 6, 12, 255))
    d.rounded_rectangle((6, 6, PHONE_W - 7, PHONE_H - 7), radius=72, outline=(255, 255, 255, 36), width=2)
    d.rounded_rectangle((BEZEL - 1, BEZEL - 1, BEZEL + PHONE_SCREEN_W, BEZEL + PHONE_SCREEN_H), radius=56, outline=(0, 0, 0, 190), width=3)
    phone.paste(shot, (BEZEL, BEZEL), rounded_mask((PHONE_SCREEN_W, PHONE_SCREEN_H), 56))
    d.rounded_rectangle(((PHONE_W - 158) // 2, BEZEL + 2, (PHONE_W + 158) // 2, BEZEL + 34), radius=17, fill=(0, 0, 0, 230))
    return phone


def paste_phone(base, screenshot_path):
    shadow = Image.new("RGBA", (PHONE_W + 180, PHONE_H + 180), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((90, 90, 90 + PHONE_W, 90 + PHONE_H), radius=96, fill=(0, 0, 0, 210))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    base.alpha_composite(shadow, (PHONE_X - 90, PHONE_Y - 70))
    base.alpha_composite(phone_composite(screenshot_path), (PHONE_X, PHONE_Y))


def make_asset(source_name, screenshot, old_phone_box, tint, output_name):
    source = Image.open(GENERATED / source_name).convert("RGBA").resize((W, H), Image.Resampling.LANCZOS)
    cover_old_phone(source, old_phone_box, tint)
    paste_phone(source, screenshot)
    source.convert("RGB").save(OUT / output_name, "PNG", optimize=True)


def main():
    home = normalized_path("/Users/elias/Downloads/Skärmavbild 2026-05-06 kl. 13.56.09.png")
    sleep = normalized_path("/Users/elias/Downloads/Skärmavbild 2026-05-06 kl. 13.48.41.png")
    sound = normalized_path("/Users/elias/Downloads/Skärmavbild 2026-05-06 kl. 13.50.17.png")

    make_asset(
        "ig_05ceb593ed3bf90f0169fb368965148191baee0947e810a74b.png",
        home,
        (80, 610, 770, 1844),
        (7, 30, 42),
        "bg-original-01-meditation-shaped-around-you.png",
    )
    make_asset(
        "ig_05ceb593ed3bf90f0169fb36c116c88191ab59d45cc14c3065.png",
        sleep,
        (220, 600, 700, 1844),
        (15, 18, 29),
        "bg-original-02-sleep-stories.png",
    )
    make_asset(
        "ig_05ceb593ed3bf90f0169fb36f956ec819182f6a9fef54f1a0a.png",
        sound,
        (250, 575, 760, 1844),
        (26, 54, 39),
        "bg-original-03-soundscapes.png",
    )


if __name__ == "__main__":
    main()
