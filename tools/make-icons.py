"""Every platform's icons from the vector icon's renders in design/brand
(tools/icon/app-icon.js): app-icon-1024.png (on its space background) and
app-icon-foreground-1024.png (transparent).

    python tools/make-icons.py

Android: launcher PNGs and an adaptive icon (the foreground inside the safe
zone on the app's background). iOS: opaque squares, the system rounds them.
macOS: a rounded square on Apple's icon grid. Windows: app_icon.ico. The app:
assets/brand/logo.png.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'apps' / 'player'
BRAND = ROOT / 'design' / 'brand'
FULL = Image.open(BRAND / 'app-icon-1024.png').convert('RGBA')
FOREGROUND = Image.open(BRAND / 'app-icon-foreground-1024.png').convert('RGBA')


def rounded(size: int, radius: float, inset: float = 0) -> Image.Image:
    """The full icon as a rounded square, [inset] of the canvas left clear."""
    inner = round(size * (1 - 2 * inset))
    art = FULL.resize((inner, inner), Image.LANCZOS)
    s = 4
    mask = Image.new('L', (inner * s, inner * s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, inner * s - 1, inner * s - 1), radius=inner * s * radius, fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(art, ((size - inner) // 2,) * 2, mask.resize((inner, inner), Image.LANCZOS))
    return out


def foreground(size: int, scale: float) -> Image.Image:
    inner = round(size * scale)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(FOREGROUND.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2,) * 2)
    return out


def android() -> None:
    res = APP / 'android' / 'app' / 'src' / 'main' / 'res'
    for density, dp in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}.items():
        folder = res / f'mipmap-{density}'
        folder.mkdir(parents=True, exist_ok=True)
        rounded(round(48 * dp), 0.22).save(folder / 'ic_launcher.png')
        # 108 dp canvas; launchers show about the middle 72 dp.
        foreground(round(108 * dp), 0.74).save(folder / 'ic_launcher_foreground.png')
    anydpi = res / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n',
        encoding='utf-8',
    )
    (res / 'values' / 'ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n    <color name="ic_launcher_background">#0B0B10</color>\n</resources>\n',
        encoding='utf-8',
    )


def apple(contents: Path, mac: bool) -> None:
    spec = json.loads(contents.read_text(encoding='utf-8'))
    for image in spec['images']:
        if 'filename' not in image:
            continue
        px = round(float(image['size'].split('x')[0]) * int(image['scale'].rstrip('x')))
        if mac:
            # Apple's grid: an 824 px rounded square inside 1024.
            rounded(px, 0.2237, inset=0.0977).save(contents.parent / image['filename'])
        else:
            FULL.convert('RGB').resize((px, px), Image.LANCZOS).save(contents.parent / image['filename'])


def windows() -> None:
    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = [rounded(s, 0.22) for s in sizes]
    images[-1].save(APP / 'windows' / 'runner' / 'resources' / 'app_icon.ico', sizes=[(s, s) for s in sizes], append_images=images[:-1])


if __name__ == '__main__':
    android()
    apple(APP / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset' / 'Contents.json', mac=False)
    apple(APP / 'macos' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset' / 'Contents.json', mac=True)
    windows()
    # In the app (titlebar, first run, About): the mark without its square.
    foreground(256, 1.0).save(APP / 'assets' / 'brand' / 'logo.png')
    print('icons written')
