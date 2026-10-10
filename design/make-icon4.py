from PIL import Image, ImageFilter
import numpy as np, sys, os
sys.stdout.reconfigure(encoding="utf-8")
im = Image.open(r"D:\xiaodi-push\design\hestia-icon-source.jpg").convert("RGB")
a = np.asarray(im).astype(np.int16)
H, W, _ = a.shape
bg = np.median(a[:20,:20].reshape(-1,3), axis=0)
d = np.abs(a - bg).sum(axis=2)
mask = d > 20           # 非背景
# 膨胀，让方块内部的黑白都连成一片
m = Image.fromarray((mask*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
mm = np.asarray(m) > 0
try:
    from scipy import ndimage
    lab, n = ndimage.label(mm)
    sizes = ndimage.sum(mm, lab, range(1, n+1))
    idx = int(np.argmax(sizes)) + 1
    ys, xs = np.where(lab == idx)
    print(f"scipy: 共 {n} 块，最大块 {int(sizes.max())} px")
except Exception as e:
    print("scipy 不可用:", e)
    ys, xs = np.where(mm)   # 退路：全部
x0,x1,y0,y1 = xs.min(), xs.max(), ys.min(), ys.max()
print(f"最大块 bbox: x {x0}..{x1} (宽 {x1-x0})  y {y0}..{y1} (高 {y1-y0})")
side = max(x1-x0, y1-y0)
cx,cy=(x0+x1)//2,(y0+y1)//2; half=side//2
box=(max(0,cx-half),max(0,cy-half),min(W,cx+half),min(H,cy+half))
print("裁切", box)
icon = im.crop(box).resize((1024,1024), Image.LANCZOS)
out = r"D:\xiaodi-push\design\hestia-icon-1024.png"
icon.save(out,"PNG")
print("生成", out, os.path.getsize(out)//1024, "KB")
