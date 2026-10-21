"""App icons for Android, iOS and macOS from design/brand/app-icon-512.png.

    python tools/make-icons.py

Android: legacy launcher PNGs and an adaptive icon (the glow on the app's
background, inside the 66% safe zone). iOS: opaque squares (the App Store
refuses transparency). macOS: the rounded square macOS draws icons in.
Windows keeps windows/runner/resources/app_icon.ico (same artwork).
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'apps' / 'player'
SOURCE = Image.open(ROOT / 'design' / 'brand' / 'app-icon-512.png').convert('RGBA')
BG = (11, 11, 16, 255)  # --bg, #0b0b10


def glow(size: int, scale: float = 1.0) -> Image.Image:
    """The artwork at [size], shrunk by [scale] and centred on transparency."""
    inner = max(1, round(size * scale))
    art = SOURCE.resize((inner, inner), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(art, ((size - inner) // 2, (size - inner) // 2))
    return out


def on_background(size: int, scale: float, radius: float = 0) -> Image.Image:
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=round(size * radius), fill=255)
    out.paste(Image.new('RGBA', (size, size), BG), (0, 0), mask)
    out.alpha_composite(glow(size, scale))
    return out


def android() -> None:
    res = APP / 'android' / 'app' / 'src' / 'main' / 'res'
    for density, dp in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}.items():
        folder = res / f'mipmap-{density}'
        folder.mkdir(parents=True, exist_ok=True)
        on_background(round(48 * dp), 0.92, radius=0.22).save(folder / 'ic_launcher.png')
        # 108 dp canvas; launchers show the middle 72 dp, so the art fills ~66%.
        glow(round(108 * dp), 0.62).save(folder / 'ic_launcher_foreground.png')
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


def apple(contents: Path, opaque: bool, radius: float) -> None:
    spec = json.loads(contents.read_text(encoding='utf-8'))
    for image in spec['images']:
        if 'filename' not in image:
            continue
        points = float(image['size'].split('x')[0])
        px = round(points * int(image['scale'].rstrip('x')))
        icon = on_background(px, 0.92 if opaque else 0.8, radius=radius)
        if opaque:
            icon = icon.convert('RGB')
        icon.save(contents.parent / image['filename'])


if __name__ == '__main__':
    android()
    # iOS rounds the corners itself and wants no alpha.
    apple(APP / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset' / 'Contents.json', opaque=True, radius=0)
    # macOS shows the file as is: a rounded square inside the canvas.
    apple(APP / 'macos' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset' / 'Contents.json', opaque=False, radius=0.18)
    print('icons written')
