from PIL import Image
im = Image.open(r"D:\xiaodi-push\design\hestia-icon-1024.png").convert("RGB")
im.resize((512,512), Image.LANCZOS).save(r"D:\xiaodi-push\DeepSeekHarnessMobile\Resources\Assets.xcassets\HestiaMark.imageset\hestia-mark.png")
print("512 界面图标已生成")
