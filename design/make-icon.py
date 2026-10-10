from PIL import Image, ImageChops
import os, sys
sys.stdout.reconfigure(encoding="utf-8")

src = r"D:\xiaodi-push\design\hestia-icon-source.jpg"
im = Image.open(src).convert("RGB")
W, H = im.size
print("源图", W, H)

# 背景取左上角像素
bg = im.getpixel((5, 5))
print("背景色", bg)

# 找出与背景差异明显的区域（就是那张圆角方块图标）
diff = ImageChops.difference(im, Image.new("RGB", im.size, bg)).convert("L")
bbox = diff.point(lambda v: 255 if v > 18 else 0).getbbox()
print("图标 bbox", bbox)

x0, y0, x1, y1 = bbox
# 取正方形（以宽为准，居中）
w = x1 - x0; h = y1 - y0
side = max(w, h)
cx = (x0 + x1) // 2; cy = (y0 + y1) // 2
half = side // 2
box = (cx - half, cy - half, cx + half, cy + half)
print("裁成正方形", box, "边长", side)

icon = im.crop(box)
# iOS 图标需要 1024x1024、不带圆角、不带透明
icon = icon.resize((1024, 1024), Image.LANCZOS)
out = r"D:\xiaodi-push\design\hestia-icon-1024.png"
icon.save(out, "PNG")
print("已生成", out, os.path.getsize(out)//1024, "KB")
