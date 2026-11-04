"""Generate Kingmakers RP brand images for the launcher (crown + K mark).

Usage: python3 scripts/generate_brand_images.py <repo-root>   (needs Pillow + numpy)
Overwrites the logo, splash, launcher icon and loading-screen images in place.
"""
import sys
import functools
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

REPO = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else REPO
FONT_DIR = f"{REPO}/android/app/src/main/res/font"
K_FONT = f"{FONT_DIR}/montserrat_bold.ttf"
WORD_FONT = f"{FONT_DIR}/muller_bold.ttf"

PINK_TOP = (247, 160, 182)
PINK_BOTTOM = (240, 72, 110)
PINK_TEXT = (245, 97, 123)  # matches HUD "RP" colour #F5617B
OUTLINE = (52, 50, 54)
SS = 4  # supersampling factor


def lerp(t, a, b):
    """Blend colours a->b by array t (0..1), returning an RGB image."""
    t = np.clip(t, 0, 1)[..., None]
    arr = np.array(a, float) + (np.array(b, float) - np.array(a, float)) * t
    return Image.fromarray(arr.round().astype(np.uint8), "RGB")


def gradient(size, top, bottom):
    w, h = size
    t = np.repeat(np.linspace(0, 1, h)[:, None], w, axis=1)
    return lerp(t, top, bottom)


def dilate(mask, r):
    """Grow a mask by ~r px (Gaussian blur + threshold; fast at any radius)."""
    sigma = r / 1.4
    return mask.filter(ImageFilter.GaussianBlur(sigma)).point(lambda v: 255 if v > 20 else 0)


def mark_mask(S):
    """Alpha mask (S x S) of the crown + K mark."""
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    # Crown: band with three peaks, each tipped with a jewel.
    x0, x1 = 0.14 * S, 0.86 * S
    base, band_top, valley, peak = 0.45 * S, 0.38 * S, 0.25 * S, 0.13 * S
    d.polygon([
        (x0, base), (x0, peak + 0.05 * S), (0.32 * S, valley),
        (0.50 * S, peak), (0.68 * S, valley), (x1, peak + 0.05 * S),
        (x1, base),
    ], fill=255)
    r = 0.045 * S
    for cx, cy in ((x0, peak + 0.05 * S), (0.50 * S, peak), (x1, peak + 0.05 * S)):
        d.ellipse((cx - r, cy - r - 0.03 * S, cx + r, cy + r - 0.03 * S), fill=255)
    # Notch separating the crown band from the peaks.
    d.rectangle((x0 + 0.04 * S, band_top, x1 - 0.04 * S, band_top + 0.025 * S), fill=0)
    # Bold italic-feel K under the crown.
    font = ImageFont.truetype(K_FONT, int(0.62 * S))
    kb = d.textbbox((0, 0), "K", font=font)
    kw, kh = kb[2] - kb[0], kb[3] - kb[1]
    k = Image.new("L", (S, S), 0)
    ImageDraw.Draw(k).text(((S - kw) / 2 - kb[0], 0.48 * S - kb[1]), "K", font=font, fill=255)
    k = k.transform(k.size, Image.AFFINE, (1, 0.16, -0.16 * 0.7 * S, 0, 1, 0), Image.BICUBIC)
    # Gap between crown and K so the two read as separate pieces.
    gap = dilate(m, 0.035 * S / 2)
    k = ImageChops.subtract(k, gap)
    return ImageChops.lighter(m, k)


MASTER = 1024


def render_mark(size, style="pink"):
    """Mark on transparent background, resized from one master render."""
    return _master_mark(style).resize((size, size), Image.LANCZOS)


@functools.lru_cache(maxsize=None)
def _master_mark(style):
    """style: pink (gradient with dark outline) or white (flat)."""
    size = MASTER
    S = size * SS
    mask = mark_mask(S)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if style == "pink":
        outline = dilate(mask, 0.05 * S / 2)
        img.paste(Image.new("RGB", (S, S), OUTLINE), (0, 0), outline)
        img.paste(gradient((S, S), PINK_TOP, PINK_BOTTOM), (0, 0), mask)
    else:
        img.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), mask)
    return img.resize((size, size), Image.LANCZOS)


def wordmark(width):
    """'KINGMAKERS RP' with letter spacing, white + pink."""
    W = width * SS
    size = int(W / 9.2)
    font = ImageFont.truetype(WORD_FONT, size)
    spacing = size * 0.22
    parts = [("KINGMAKERS", (255, 255, 255)), (" RP", PINK_TEXT)]
    chars = [(c, col) for text, col in parts for c in text]
    total = sum(font.getlength(c) + spacing for c, _ in chars) - spacing
    scale = min(1.0, W * 0.98 / total)
    font = ImageFont.truetype(WORD_FONT, int(size * scale))
    spacing *= scale
    total = sum(font.getlength(c) + spacing for c, _ in chars) - spacing
    asc, desc = font.getmetrics()
    img = Image.new("RGBA", (W, asc + desc), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = (W - total) / 2
    for c, col in chars:
        d.text((x, 0), c, font=font, fill=col)
        x += font.getlength(c) + spacing
    img = img.crop(img.getbbox())
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def lockup(w, h):
    """Mark above wordmark, fitted to w x h (same proportions as the old logo)."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    word = wordmark(w)
    m = min(w, h - word.height - int(0.06 * h))
    mark = render_mark(m)
    img.alpha_composite(mark, ((w - m) // 2, 0))
    img.alpha_composite(word, ((w - word.width) // 2, h - word.height - int(0.01 * h)))
    return img


def rounded_square(size, fill, radius_frac=0.22):
    S = size * SS
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), int(radius_frac * S), fill=255)
    bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg.paste(fill if isinstance(fill, Image.Image) else Image.new("RGB", (S, S), fill), (0, 0), mask)
    return bg.resize((size, size), Image.LANCZOS)


def circle(size, fill):
    S = size * SS
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, S - 1, S - 1), fill=255)
    bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg.paste(fill, (0, 0), mask)
    return bg.resize((size, size), Image.LANCZOS)


def plum(size):
    """Diagonal dark-plum gradient used by the old launcher icon."""
    S = size * SS
    y, x = np.mgrid[0:S, 0:S]
    return lerp((x + y) / (2 * S - 2), (38, 20, 34), (150, 92, 128))


def centered(canvas, item, scale=1.0):
    w = int(canvas.width * scale)
    item = item.resize((w, int(item.height * w / item.width)), Image.LANCZOS)
    canvas.alpha_composite(item, ((canvas.width - item.width) // 2, (canvas.height - item.height) // 2))
    return canvas


def main():
    res = f"{OUT}/android/app/src/main/res"
    # Launcher screens: logo with wordmark.
    lockup(354, 468).save(f"{OUT}/src/assets/images/logo.png")
    lockup(354, 468).save(f"{OUT}/assets/images/logo.png")
    lockup(169, 223).save(f"{OUT}/src/assets/images/bootsplash_logo_original.png")
    # "Site" social button: white mark on the orange tile, as before.
    tile = rounded_square(211, (253, 176, 34))
    centered(tile, render_mark(211, "white"), 0.74).crop((0, 0, 211, 210)).save(f"{OUT}/src/assets/icons/logo_link.png")
    # In-game HUD menu button.
    render_mark(120, "pink").resize((118, 120), Image.LANCZOS).save(f"{res}/drawable/logo.png")
    # Splash + launcher icons for every density.
    for dpi, mult in (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)):
        s = int(288 * mult)
        splash = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        lw = int(s * 0.34)
        splash.alpha_composite(lockup(lw, int(lw * 468 / 354)), ((s - lw) // 2, (s - int(lw * 468 / 354)) // 2))
        splash.save(f"{res}/mipmap-{dpi}/bootsplash_logo.png")
        i = int(48 * mult)
        sq = centered(rounded_square(i * 4, plum(i * 4), 0.18), render_mark(i * 4), 0.8)
        sq.resize((i, i), Image.LANCZOS).save(f"{res}/mipmap-{dpi}/ic_launcher.png")
        rd = centered(circle(i * 4, plum(i * 4)), render_mark(i * 4), 0.78)
        rd.resize((i, i), Image.LANCZOS).save(f"{res}/mipmap-{dpi}/ic_launcher_round.png")
    # Game loading screen background (was the Touch Roleplay holiday art).
    W, H = 1452, 620
    y, x = np.mgrid[0:H, 0:W]
    cx, cy = W / 2, H * 0.45
    d = np.sqrt(((x - cx) / (W * 0.6)) ** 2 + ((y - cy) / (H * 0.9)) ** 2)
    bg = lerp(d, (120, 28, 52), (18, 14, 20))
    bg = bg.convert("RGBA")
    lh = int(H * 0.62)
    bg.alpha_composite(lockup(int(lh * 354 / 468), lh), ((W - int(lh * 354 / 468)) // 2, (H - lh) // 2))
    bg.convert("RGB").save(f"{res}/drawable/mylogo.jpg", quality=92)


if __name__ == "__main__":
    main()
