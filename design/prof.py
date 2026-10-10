from PIL import Image
import numpy as np, sys
sys.stdout.reconfigure(encoding="utf-8")
im = Image.open(r"D:\xiaodi-push\design\hestia-icon-source.jpg").convert("RGB")
a = np.asarray(im).astype(np.int16)
H, W, _ = a.shape
whiteish = (a[:,:,0]>=250)&(a[:,:,1]>=250)&(a[:,:,2]>=250)
rowsum = whiteish.sum(axis=1)
# 每 40 行打印一次
print("行剖面（每40行）：")
for y in range(0, H, 40):
    bar = "#" * int(rowsum[y:y+40].mean() / (W/60))
    print(f"  y{y:>5} {rowsum[y:y+40].mean():>7.0f} {bar}")
colsum = whiteish.sum(axis=0)
print("列剖面（每60列）：")
for x in range(0, W, 60):
    print(f"  x{x:>5} {colsum[x:x+60].mean():>7.0f} " + "#"*int(colsum[x:x+60].mean()/(H/50)))
