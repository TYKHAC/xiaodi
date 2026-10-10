from PIL import Image
import numpy as np, sys, os
sys.stdout.reconfigure(encoding="utf-8")
im = Image.open(r"D:\xiaodi-push\design\hestia-icon-source.jpg").convert("RGB")
a = np.asarray(im).astype(np.int16)
H, W, _ = a.shape
whiteish = (a[:,:,0]>=250)&(a[:,:,1]>=250)&(a[:,:,2]>=250)

def longest_run(mask):
    best=(0,0,0); cur=0; start=0
    for i,v in enumerate(mask):
        if v:
            if cur==0: start=i
            cur+=1
            if cur>best[0]: best=(cur,start,i)
        else: cur=0
    return best  # 长度, 起, 止

rows = whiteish.sum(axis=1) > W*0.10
rl, ry0, ry1 = longest_run(rows)
band = whiteish[ry0:ry1+1]
cols = band.sum(axis=0) > (ry1-ry0)*0.10
cl, cx0, cx1 = longest_run(cols)
print(f"行带 y {ry0}..{ry1} (共 {rl})")
print(f"列带 x {cx0}..{cx1} (共 {cl})")

x0,x1,y0,y1 = cx0, cx1, ry0, ry1
side = max(x1-x0, y1-y0)
cx,cy = (x0+x1)//2, (y0+y1)//2
half = side//2
box=(max(0,cx-half), max(0,cy-half), min(W,cx+half), min(H,cy+half))
print("正方形裁切", box, "边长", side)
icon = im.crop(box).resize((1024,1024), Image.LANCZOS)
out = r"D:\xiaodi-push\design\hestia-icon-1024.png"
icon.save(out,"PNG")
print("生成", out, os.path.getsize(out)//1024, "KB")
