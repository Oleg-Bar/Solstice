#!/usr/bin/env python3
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


def font(size: int, rounded: bool = False) -> ImageFont.FreeTypeFont:
    name = "SFNSRounded.ttf" if rounded else "SFNS.ttf"
    return ImageFont.truetype(f"/System/Library/Fonts/{name}", size)


def make_background(hero: Image.Image, destination: Path) -> None:
    canvas = Image.new("RGB", (800, 500), "black")
    scene = ImageOps.contain(hero.convert("RGB"), (800, 450), Image.Resampling.LANCZOS)
    canvas.paste(scene, ((800 - scene.width) // 2, 25))
    canvas = ImageEnhance.Brightness(canvas).enhance(0.78).convert("RGBA")

    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    # A restrained macOS-style glass landing area keeps the installer label readable.
    draw.rounded_rectangle((36, 142, 764, 418), radius=34,
                           fill=(240, 246, 255, 46), outline=(255, 255, 255, 62), width=1)
    draw.text((42, 42), "Solstice", font=font(42, rounded=True), fill=(255, 255, 255, 242))
    draw.text((45, 92), "1.10  •  macOS", font=font(15), fill=(222, 228, 238, 205))
    draw.text((274, 380), "Drag Solstice to Applications", font=font(13), fill=(255, 255, 255, 222))
    Image.alpha_composite(canvas, overlay).convert("RGB").save(destination, "PNG", optimize=True)


def make_icon(hero: Image.Image, icns_destination: Path) -> None:
    width, height = hero.size
    side = min(height, width)
    center_x = width * 0.54
    left = max(0, min(width - side, int(center_x - side / 2)))
    scene = hero.crop((left, 0, left + side, side)).resize((824, 824), Image.Resampling.LANCZOS)

    icon = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shadow = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    shadow_mask = Image.new("L", (824, 824), 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle((0, 0, 823, 823), radius=190, fill=210)
    shadow_layer = Image.new("RGBA", (824, 824), (0, 0, 0, 170))
    shadow_layer.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(28)))
    shadow.alpha_composite(shadow_layer, (100, 124))
    icon.alpha_composite(shadow)

    mask = Image.new("L", (824, 824), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 823, 823), radius=190, fill=255)
    scene.putalpha(mask)
    icon.alpha_composite(scene, (100, 92))
    border = ImageDraw.Draw(icon)
    border.rounded_rectangle((100, 92, 923, 915), radius=190,
                             outline=(255, 255, 255, 105), width=3)
    icon.save(icns_destination, format="ICNS",
              sizes=[(16, 16), (32, 32), (64, 64), (128, 128),
                     (256, 256), (512, 512), (1024, 1024)])


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: create-brand-assets.py HERO BACKGROUND ICON")
    hero_path, background_path, icon_path = map(Path, sys.argv[1:])
    hero = Image.open(hero_path)
    make_background(hero, background_path)
    make_icon(hero, icon_path)


if __name__ == "__main__":
    main()
