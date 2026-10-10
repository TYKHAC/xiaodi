import io, os, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\zhuxiaojie-ui-opt.html"
s = io.open(p, encoding="utf-8").read()
orig = s

# ---------- 1) 手势胶囊：改成参考图的深色半透明 + 白字 ----------
old_btn = """  .gbtn{font-size:13.5px;color:#4B5563;background:#fff;border:1.5px solid rgba(0,0,0,.14);
        border-radius:12px;padding:11px 18px;min-width:74px;text-align:center;font-weight:500;
        box-shadow:0 2px 8px rgba(16,24,40,.06)}
  .gbtn.blue{background:#2E6BE6;border-color:#2E6BE6;color:#fff}
  .gbtn.red{background:#D9534F;border-color:#D9534F;color:#fff}"""
new_btn = """  /* 手势胶囊：借参考图（深色半透明 + 白字；右侧更宽并带引导语） */
  .gbtn{font-size:13px;color:#F3F5F8;background:rgba(22,24,30,.72);border:none;
        border-radius:16px;padding:13px 18px;min-width:76px;text-align:center;font-weight:500;
        -webkit-backdrop-filter:blur(12px);backdrop-filter:blur(12px);
        box-shadow:0 8px 22px rgba(0,0,0,.30), inset 0 1px 0 rgba(255,255,255,.10)}
  .gbtn.wide{padding:13px 24px}
  .gbtn.blue{background:rgba(46,107,230,.90);box-shadow:0 8px 22px rgba(46,107,230,.45), inset 0 1px 0 rgba(255,255,255,.18)}
  .gbtn.red{background:rgba(214,78,74,.90);box-shadow:0 8px 22px rgba(214,78,74,.42), inset 0 1px 0 rgba(255,255,255,.18)}"""
assert old_btn in s, "没找到 gbtn CSS"
s = s.replace(old_btn, new_btn, 1)

# ---------- 2) 波纹：硬边圆环 → 柔光晕 ----------
old_ring = """  .ringbig{position:absolute;border-radius:50%;border:1.5px solid rgba(46,107,230,.35)}
  .ringbig.r1{width:98px;height:98px}
  .ringbig.r2{width:128px;height:128px;border-color:rgba(46,107,230,.16)}"""
new_ring = """  /* 柔光波纹：模糊的渐变光环，不是硬边圈（用户 2026-10-10「波纹不高级」） */
  .ringbig{position:absolute;border-radius:50%;border:0;filter:blur(1.6px);
     background:radial-gradient(circle, transparent 60%, rgba(130,175,255,.42) 69%, rgba(170,130,255,.16) 77%, transparent 84%);
     animation:orbpulse 2.8s ease-out infinite}
  .ringbig.r1{width:104px;height:104px}
  .ringbig.r2{width:140px;height:140px;opacity:.62;animation-delay:.6s}
  .orbglow{position:absolute;width:150px;height:150px;border-radius:50%;filter:blur(12px);
     background:radial-gradient(circle, rgba(90,140,255,.45) 0%, rgba(150,90,255,.18) 45%, transparent 70%);
     animation:orbpulse 2.2s ease-in-out infinite}"""
assert old_ring in s, "没找到 ringbig CSS"
s = s.replace(old_ring, new_ring, 1)
s = s.replace("  .ringbig.red{border-color:rgba(217,83,79,.45)}\n", "")
s = s.replace("  .ringbig.blue{border-color:rgba(46,107,230,.55)}\n", "")

# ---------- 3) 文案：右边胶囊改成「滑到这里 转文字」，并加柔光层 ----------
s = s.replace('<span class="gbtn">转文字</span>', '<span class="gbtn wide">滑到这里 转文字</span>')
s = s.replace('<span class="gbtn blue">转文字 ✓</span>', '<span class="gbtn wide blue">滑到这里 转文字 ✓</span>')
s = s.replace('<span class="gbtn red">取消 ✓</span>', '<span class="gbtn red">取消 ✓</span>')
s = s.replace('<span class="ringbig r2"></span>\n            <span class="ringbig r1"></span>',
              '<span class="orbglow"></span>\n            <span class="ringbig r2"></span>\n            <span class="ringbig r1"></span>')

# 说明文案同步
s = s.replace("上方左右两块：<b>取消</b>（左）/ <b>转文字</b>（右）。",
              "上方两块深色胶囊：<b>取消</b>（左）/ <b>滑到这里 转文字</b>（右，更宽）。")

io.open(p, "w", encoding="utf-8").write(s)
print("补丁应用完成，", len(orig), "→", len(s), "字节")
print("检查：gbtn.wide 出现", s.count("gbtn wide"), "次；orbglow", s.count("orbglow"), "次")
