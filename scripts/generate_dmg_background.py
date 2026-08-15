#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

def generate_background(output_path):
    # Standard 1:1 points size for macOS Finder: 540 x 360
    w, h = 540, 360
    img = Image.new("RGB", (w, h), (26, 28, 35))
    draw = ImageDraw.Draw(img)

    # 1. Subtle, elegant modern dark gradient
    for y in range(h):
        ratio = y / float(h)
        # Deep macOS dark slate: #1f232b down to #14171d
        r = int(31 * (1 - ratio) + 20 * ratio)
        g = int(35 * (1 - ratio) + 23 * ratio)
        b = int(43 * (1 - ratio) + 29 * ratio)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    # 2. Sleek, minimalist arrow in the center (between X=220 and X=320, Y=175)
    arrow_color = (110, 150, 220)
    line_y = 175
    draw.line([(230, line_y), (300, line_y)], fill=arrow_color, width=3)
    
    # Modern arrowhead
    draw.polygon([
        (312, line_y),
        (298, line_y - 8),
        (298, line_y + 8)
    ], fill=arrow_color)

    # 3. Clean, subtle header typography (no duplicate icon labels!)
    font_title = None
    for font_path in [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf"
    ]:
        if os.path.exists(font_path):
            try:
                font_title = ImageFont.truetype(font_path, 15)
                break
            except Exception:
                pass
                
    if not font_title:
        font_title = ImageFont.load_default()

    sub_text = "Drag Integra to Applications to install"
    bbox_sub = draw.textbbox((0, 0), sub_text, font=font_title)
    sw = bbox_sub[2] - bbox_sub[0]
    draw.text(((w - sw) // 2, 45), sub_text, font=font_title, fill=(180, 190, 205))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG", dpi=(72, 72))
    print(f"Clean DMG background generated at {output_path}")

if __name__ == "__main__":
    generate_background("Resources/dmg_background.png")
