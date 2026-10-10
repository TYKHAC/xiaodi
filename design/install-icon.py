from PIL import Image
import os, sys
sys.stdout.reconfigure(encoding="utf-8")
src = r"D:\xiaodi-push\design\hestia-icon-1024.png"
im = Image.open(src).convert("RGB")
w, h = im.size
inset = int(w * 0.035)          # 往里收 3.5%，去掉源图自带圆角的灰边
icon = im.crop((inset, inset, w-inset, h-inset)).resize((1024,1024), Image.LANCZOS)
ic = r"D:\xiaodi-push\DeepSeekHarnessMobile\Resources\Assets.xcassets\AppIcon.appiconset"
for name in ("AppIcon-light.png", "AppIcon-dark.png"):
    p = os.path.join(ic, name)
    icon.save(p, "PNG")
    print("已装", name, os.path.getsize(p)//1024, "KB")
