from PIL import Image, ImageFilter
import numpy as np, sys, os
from collections import deque
sys.stdout.reconfigure(encoding="utf-8")

im = Image.open(r"D:\xiaodi-push\design\hestia-icon-source.jpg").convert("RGB")
a = np.asarray(im).astype(np.int16)
H, W, _ = a.shape
bg = np.median(a[:20,:20].reshape(-1,3), axis=0)
mask = (np.abs(a - bg).sum(axis=2) > 20)
mimg = Image.fromarray((mask*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
mask = np.asarray(mimg) > 0

# 降采样 4 倍做连通域
S = 4
small = mask[:H//S*S, :W//S*S].reshape(H//S, S, W//S, S).any(axis=(1,3))
h, w = small.shape
lab = np.zeros((h, w), dtype=np.int32)
cur = 0; best = (0, None)
for sy in range(h):
    for sx in range(w):
        if small[sy, sx] and lab[sy, sx] == 0:
            cur += 1
            q = deque([(sy, sx)]); lab[sy, sx] = cur; cnt = 0
            ys=[]; xs=[]
            while q:
                y, x = q.popleft(); cnt += 1; ys.append(y); xs.append(x)
                for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                    ny, nx = y+dy, x+dx
                    if 0 <= ny < h and 0 <= nx < w and small[ny, nx] and lab[ny, nx] == 0:
                        lab[ny, nx] = cur; q.append((ny, nx))
            if cnt > best[0]:
                best = (cnt, (min(xs)*S, min(ys)*S, (max(xs)+1)*S, (max(ys)+1)*S))
cnt, box = best
print(f"连通域数 {cur}；最大块 {cnt*S*S} px  bbox {box}")
x0, y0, x1, y1 = box
side = max(x1-x0, y1-y0)
cx, cy = (x0+x1)//2, (y0+y1)//2
half = side//2
crop = (max(0,cx-half), max(0,cy-half), min(W,cx+half), min(H,cy+half))
print("正方形裁切", crop, "边长", side)
icon = im.crop(crop).resize((1024,1024), Image.LANCZOS)
out = r"D:\xiaodi-push\design\hestia-icon-1024.png"
icon.save(out,"PNG")
print("生成", out, os.path.getsize(out)//1024, "KB")
