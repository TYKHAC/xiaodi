from PIL import Image
import numpy as np, sys, os
sys.stdout.reconfigure(encoding="utf-8")

src = r"D:\xiaodi-push\design\hestia-icon-source.jpg"
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.int16)
H, W, _ = a.shape

whiteish = (a[:,:,0] >= 250) & (a[:,:,1] >= 250) & (a[:,:,2] >= 250)
rowsum = whiteish.sum(axis=1)
colsum = whiteish.sum(axis=0)
# 图标带：近白像素很多的连续行
th_r = W * 0.12
th_c = H * 0.12
rows = np.where(rowsum > th_r)[0]
cols = np.where(colsum > th_c)[0]
if len(rows) == 0 or len(cols) == 0:
    print("没找到方块"); sys.exit(1)
y0, y1 = rows.min(), rows.max()
x0, x1 = cols.min(), cols.max()
print(f"白色方块: x {x0}..{x1} (宽 {x1-x0})  y {y0}..{y1} (高 {y1-y0})")

side = max(x1-x0, y1-y0)
cx, cy = (x0+x1)//2, (y0+y1)//2
half = side//2
box = (max(0,cx-half), max(0,cy-half), min(W,cx+half), min(H,cy+half))
print("裁切", box)
icon = im.crop(box).resize((1024,1024), Image.LANCZOS)
out = r"D:\xiaodi-push\design\hestia-icon-1024.png"
icon.save(out, "PNG")
print("生成", out, os.path.getsize(out)//1024, "KB")
