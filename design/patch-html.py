from PIL import Image
import base64, io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")

# 1) 生成小尺寸图标 data URI（内联进 HTML，侧边栏沙箱不读本地文件）
im = Image.open(r"D:\xiaodi-push\design\hestia-icon-1024.png").convert("RGB")
im.thumbnail((256, 256), Image.LANCZOS)
buf = io.BytesIO(); im.save(buf, "JPEG", quality=86)
b64 = base64.b64encode(buf.getvalue()).decode()
os.makedirs(r"D:\xiaodi-push\design", exist_ok=True)
open(r"D:\xiaodi-push\design\icon-b64.txt", "w").write(b64)
print("icon data URI 长度", len(b64))

p = r"D:\xiaodi-push\_preview\zhuxiaojie-ui-opt.html"
s = open(p, encoding="utf-8").read()

# 2) CSS：把三种圆球都换成 Siri 风格（深色球 + 流动彩色光带 + 动画）
new_orb_css = """
  /* === Hestia 语音球：Siri 风格（深色球体 + 流动彩色光带 + 动画）=== */
  @keyframes orbspin{to{transform:rotate(360deg)}}
  @keyframes orbspin-rev{to{transform:rotate(-360deg)}}
  @keyframes orbpulse{0%,100%{transform:scale(1);opacity:.92}50%{transform:scale(1.22);opacity:1}}
  .orb,.orbmini,.orb-mid,.orb-big2{position:relative;border-radius:50%;overflow:hidden;
     background:radial-gradient(circle at 34% 28%, #3a4260 0%, #0b0e1c 72%);
     box-shadow:0 4px 18px rgba(80,130,255,.34)}
  .orb::before,.orbmini::before,.orb-mid::before,.orb-big2::before{
     content:"";position:absolute;left:-25%;top:-25%;width:150%;height:150%;
     background:conic-gradient(from 0deg,#2f8cff,#ff5cbf,#3fe8dc,#a066ff,#2f8cff);
     filter:blur(7px);opacity:.85;animation:orbspin 5.5s linear infinite}
  .orb::after,.orbmini::after,.orb-mid::after,.orb-big2::after{
     content:"";position:absolute;left:20%;top:20%;width:60%;height:60%;border-radius:50%;
     background:radial-gradient(circle,#fff 0%,rgba(160,200,255,.75) 45%,transparent 72%);
     filter:blur(4px);animation:orbpulse 2.8s ease-in-out infinite}
  .orb-hold .ring-h, .orb-center .ringbig{animation:orbpulse 2.4s ease-in-out infinite}
  .icon-card{display:flex;align-items:center;gap:18px;background:#fff;border-radius:16px;padding:16px 20px;
             box-shadow:0 6px 18px rgba(16,24,40,.07);margin-bottom:22px}
  .icon-card img{width:86px;height:86px;border-radius:19px;box-shadow:0 4px 14px rgba(16,24,40,.18)}
  .icon-card .nm{font-size:20px;font-weight:700;letter-spacing:.3px}
  .icon-card .sub2{font-size:12.5px;color:#6B7280;margin-top:4px;line-height:1.55}
"""
# 插到第一个 .notes 规则之前
s = s.replace('  .notes{margin-top:40px', new_orb_css + '  .notes{margin-top:40px', 1)

# 3) 顶部加「图标 + 名字」卡
card = ('<div class="icon-card">\n'
        '  <img src="data:image/jpeg;base64,' + b64 + '" alt="Hestia icon">\n'
        '  <div>\n'
        '    <div class="nm">Hestia</div>\n'
        '    <div class="sub2">新名字 · 新图标（用户 2026-10-10 定）<br>'
        '    图标 = 御姐头像（黑白线稿）；语音球 = Siri 风格动态球（下面几屏能看到）。</div>\n'
        '  </div>\n'
        '</div>\n\n')
s = s.replace('<div class="row">', card + '<div class="row">', 1)

# 4) 标题里的名字
s = s.replace("朱小姐 · 界面优化设计稿", "Hestia · 界面优化设计稿")
s = s.replace("Hestia · 界面优化设计稿（首页无返回键", "Hestia · 界面优化设计稿（首页无返回键")
open(p, "w", encoding="utf-8").write(s)
print("HTML 已更新：", os.path.getsize(p)//1024, "KB")
