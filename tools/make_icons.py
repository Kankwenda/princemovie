#!/usr/bin/env python3
"""Génère le logo et les icônes PrinceMovie : « P » doré (#D4AF37) sur fond noir.

Sorties :
  - assets/images/logo.png            (512x512, P + nom PrinceMovie)
  - android/.../mipmap-*/ic_launcher.png            (icône classique)
  - android/.../mipmap-*/ic_launcher_foreground.png (avant-plan adaptatif)
  - android/.../mipmap-anydpi-v26/ic_launcher.xml  (définition adaptative)
Usage : python3 tools/make_icons.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOLD = (212, 175, 55)      # #D4AF37
BLACK = (11, 11, 15)       # #0B0B0F
FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

DENSITIES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def gold_p(draw, size, font_px, center):
    """Dessine un « P » doré centré sur (cx, cy)."""
    font = ImageFont.truetype(FONT_PATH, font_px)
    draw.text(center, "P", font=font, fill=GOLD, anchor="mm")


def make_foreground(size):
    """Avant-plan adaptatif : P centré, marges larges (zone sûre 66dp/108dp)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Le P occupe ~55 % de la largeur pour rester dans la zone sûre.
    gold_p(draw, size, int(size * 0.62), (size // 2, size // 2))
    return img


def make_launcher(size):
    """Icône classique : fond noir plein + P doré centré."""
    img = Image.new("RGBA", (size, size), BLACK + (255,))
    draw = ImageDraw.Draw(img)
    gold_p(draw, size, int(size * 0.62), (size // 2, size // 2))
    return img


def make_logo(size=512):
    """Logo complet : P doré + nom PRINCE MOVIE en dessous."""
    img = Image.new("RGBA", (size, size), BLACK + (255,))
    draw = ImageDraw.Draw(img)
    gold_p(draw, size, int(size * 0.52), (size // 2, int(size * 0.38)))
    font = ImageFont.truetype(FONT_PATH, int(size * 0.075))
    draw.text(
        (size // 2, int(size * 0.78)),
        "PRINCE MOVIE",
        font=font,
        fill=GOLD,
        anchor="mm",
    )
    return img


def main():
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    # Logo applicatif
    logo_path = os.path.join(ROOT, "assets", "images", "logo.png")
    make_logo().save(logo_path)
    print("OK", logo_path)
    # Icônes par densité
    for density, size in DENSITIES.items():
        d = os.path.join(res, density)
        os.makedirs(d, exist_ok=True)
        fg = os.path.join(d, "ic_launcher_foreground.png")
        make_foreground(size).save(fg)
        lg = os.path.join(d, "ic_launcher.png")
        make_launcher(size).save(lg)
        print("OK", fg, "|", lg)
    # Icône adaptative (fond = couleur @color/ic_launcher_background)
    anydpi = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    xml = os.path.join(anydpi, "ic_launcher.xml")
    with open(xml, "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            "</adaptive-icon>\n"
        )
    print("OK", xml)


if __name__ == "__main__":
    main()
