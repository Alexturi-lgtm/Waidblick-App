#!/usr/bin/env python3
"""Generate store icons for Gamssinn from the app source icon.
Play: 512x512 PNG (RGBA / 32-bit).
Apple: 1024x1024 PNG, NO alpha (flattened on white), no rounded corners.
"""
import os
from PIL import Image

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(BASE, "assets", "app_icon.png")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon")
os.makedirs(OUT, exist_ok=True)

src = Image.open(SRC)
print("Source:", src.size, src.mode)
upscaled = src.size[0] < 1024 or src.size[1] < 1024
if upscaled:
    print("WARNING: source icon smaller than 1024 -> upscaled (quality loss)")

# Play Store: 512x512, 32-bit PNG (RGBA)
play = src.convert("RGBA").resize((512, 512), Image.LANCZOS)
play.save(os.path.join(OUT, "play-icon-512.png"), "PNG")

# Apple: 1024x1024, no alpha (flatten on white), square corners
apple = src.convert("RGBA")
if apple.size != (1024, 1024):
    apple = apple.resize((1024, 1024), Image.LANCZOS)
bg = Image.new("RGB", apple.size, (255, 255, 255))
bg.paste(apple, mask=apple.split()[3])
bg.save(os.path.join(OUT, "apple-icon-1024.png"), "PNG")

for f in ["play-icon-512.png", "apple-icon-1024.png"]:
    im = Image.open(os.path.join(OUT, f))
    print(f, im.size, im.mode, "has_alpha:", im.mode in ("RGBA", "LA", "PA"))
print("UPSCALED" if upscaled else "NO_UPSCALE")
