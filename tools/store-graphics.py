"""Store graphics from real screenshots: framed screens with a headline for
Google Play (1080x1920) and the App Store (1290x2796, 6.9"), and the Play
feature graphic (1024x500), in English and Turkish.

    tools\\shots.ps1 -Phone 360x640 -Scale 3 -Language en -Out <shots>\\android-en
    tools\\shots.ps1 -Phone 430x932 -Scale 3 -Language en -Out <shots>\\ios-en
    (the same with -Language tr; the mock provider with KP_MOCK_LANG=en for English data)
    python tools/store-graphics.py <shots> <out>

Every screen is a real capture of the app with the mock provider's test
data: the stores refuse screenshots that do not show the app as it is.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / 'design' / 'brand' / 'app-icon-foreground-1024.png'
FULL_ICON = ROOT / 'design' / 'brand' / 'app-icon-1024.png'
FONTS = Path('C:/Windows/Fonts')
BG = (11, 11, 16)
LINE = (38, 38, 51)
TEXT = (233, 231, 239)
MUTED = (141, 138, 156)
ACCENT = (255, 138, 31)

# (screen, headline, line under it) per language, in store order.
SCREENS = {
    'en': [
        ('live', 'Fast, smooth live TV', 'Add your own Xtream, M3U or Stalker source.'),
        ('player-timeshift', 'Pause and rewind live TV', 'Timeshift right on your device.'),
        ('guide', 'A TV guide you can read', 'XMLTV and catch-up support.'),
        ('movie-detail', 'Movies and series, in detail', 'Resume where you left off.'),
        ('home', 'Everything in one place', 'Favourites, history and search.'),
        ('settings', 'Private by design', 'No ads, no tracking. Passwords stay on your device.'),
    ],
    'tr': [
        ('live', 'Hızlı, akıcı canlı TV', 'Kendi Xtream, M3U veya Stalker kaynağınızı ekleyin.'),
        ('player-timeshift', 'Canlı yayını durdurun, geri sarın', 'Zaman kaydırma doğrudan cihazınızda.'),
        ('guide', 'Okunaklı yayın akışı', 'XMLTV ve geçmiş yayın desteği.'),
        ('movie-detail', 'Film ve diziler, ayrıntısıyla', 'Kaldığınız yerden devam edin.'),
        ('home', 'Her şey tek yerde', 'Favoriler, geçmiş ve arama.'),
        ('settings', 'Gizlilik öncelikli', 'Reklam ve takip yok. Şifreler cihazınızda kalır.'),
    ],
}

FEATURE = {
    'en': ('Karadelik Player', 'A fast player for your own IPTV sources'),
    'tr': ('Karadelik Player', 'Kendi IPTV kaynaklarınız için hızlı oynatıcı'),
}


def font(bold: bool, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / ('seguisb.ttf' if bold else 'segoeui.ttf')), size)


def background(w: int, h: int, glow_at: tuple[float, float], radius: float, strength: int = 110) -> Image.Image:
    """The app's background with a soft orange glow, like the icon's ring."""
    img = Image.new('RGB', (w, h), BG)
    glow = Image.new('L', (w, h), 0)
    cx, cy = glow_at[0] * w, glow_at[1] * h
    r = radius * max(w, h)
    ImageDraw.Draw(glow).ellipse((cx - r, cy - r, cx + r, cy + r), fill=strength)
    glow = glow.filter(ImageFilter.GaussianBlur(r * 0.45))
    img.paste(Image.new('RGB', (w, h), ACCENT), (0, 0), glow)
    return img


def wrap(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines, line = [], ''
    for word in text.split():
        trial = f'{line} {word}'.strip()
        if draw.textlength(trial, font=f) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def framed(shot: Image.Image, headline: str, sub: str, w: int, h: int) -> Image.Image:
    img = background(w, h, (0.5, 1.02), 0.42)
    draw = ImageDraw.Draw(img)
    margin = round(w * 0.08)
    big, small = font(True, round(w * 0.068)), font(False, round(w * 0.036))
    y = round(h * 0.055)
    for line in wrap(draw, headline, big, w - 2 * margin):
        draw.text((w / 2, y), line, font=big, fill=TEXT, anchor='ma')
        y += round(big.size * 1.18)
    y += round(small.size * 0.35)
    for line in wrap(draw, sub, small, w - 2 * margin):
        draw.text((w / 2, y), line, font=small, fill=MUTED, anchor='ma')
        y += round(small.size * 1.3)
    y += round(h * 0.03)

    # The screen in a rounded frame, running off the bottom edge.
    sw = round(w * 0.8)
    sh = round(shot.height * sw / shot.width)
    screen = shot.convert('RGB').resize((sw, sh), Image.LANCZOS)
    r = round(sw * 0.06)
    pad = max(3, round(w * 0.006))
    x = (w - sw) // 2
    shadow = Image.new('L', (w, h), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x - pad, y - pad + 20, x + sw + pad, y + sh + pad + 20), r + pad, fill=170)
    img.paste((0, 0, 0), (0, 0), shadow.filter(ImageFilter.GaussianBlur(28)))
    ImageDraw.Draw(img).rounded_rectangle((x - pad, y - pad, x + sw + pad, y + sh + pad), r + pad, fill=LINE)
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), r, fill=255)
    img.paste(screen, (x, y), mask)
    return img


def feature(title: str, sub: str) -> Image.Image:
    w, h = 1024, 500
    # The mark brings its own light: only a faint glow behind it.
    img = background(w, h, (0.8, 0.5), 0.22, strength=40)
    icon = Image.open(ICON).convert('RGBA').resize((520, 520), Image.LANCZOS)
    img.paste(icon, (w - 520 + 10, (h - 520) // 2), icon)
    draw = ImageDraw.Draw(img)
    draw.text((64, 188), title, font=font(True, 66), fill=TEXT, anchor='ls')
    y = 232
    for line in wrap(draw, sub, font(False, 30), 470):
        draw.text((66, y), line, font=font(False, 30), fill=MUTED, anchor='lt')
        y += 40
    return img


def main(shots: Path, out: Path) -> None:
    for store, size in [('android', (1080, 1920)), ('ios', (1290, 2796))]:
        for lang, screens in SCREENS.items():
            src = shots / f'{store}-{lang}'
            dest = out / store / lang
            dest.mkdir(parents=True, exist_ok=True)
            for n, (name, headline, sub) in enumerate(screens, 1):
                framed(Image.open(src / f'{name}.png'), headline, sub, *size).save(dest / f'{n:02}-{name}.png', optimize=True)
    for lang, (title, sub) in FEATURE.items():
        feature(title, sub).save(out / f'feature-graphic-{lang}.png', optimize=True)
    Image.open(FULL_ICON).convert('RGB').resize((512, 512), Image.LANCZOS).save(out / 'icon-512.png')
    print('written to', out)


if __name__ == '__main__':
    main(Path(sys.argv[1]), Path(sys.argv[2]))
