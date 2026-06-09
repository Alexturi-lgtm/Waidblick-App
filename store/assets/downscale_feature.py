import os
from PIL import Image
d = os.path.dirname(os.path.abspath(__file__))
p = os.path.join(d, "feature-graphic.png")
im = Image.open(p)
if im.size != (1024, 500):
    im = im.convert("RGB").resize((1024, 500), Image.LANCZOS)
    im.save(p, "PNG")
out = Image.open(p)
print("feature-graphic.png", out.size, out.mode)
