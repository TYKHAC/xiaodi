import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\voice-modes.html"
s = io.open(p, encoding="utf-8").read()

# 新增：语音模式「无边框 + 大球 + 两片长弧半围」
css = """
  /* 语音模式：椭圆边框消失、球变大、两片长弧半围着球 */
  .voicezone{flex:none;position:relative;z-index:6;height:150px;display:flex;align-items:center;justify-content:center}
  .ringwrap{position:relative;width:230px;height:150px;display:flex;align-items:center;justify-content:center}
  .half{position:absolute;width:150px;height:150px;border-radius:50%;border:13px solid var(--ink);
        border-color:transparent}
  .half.left{border-left-color:var(--ink);border-top-color:var(--ink);transform:rotate(-38deg)}
  .half.right{border-right-color:var(--ink);border-top-color:var(--ink);transform:rotate(38deg)}
  .orb-xl{width:96px;height:96px;border-radius:50%;position:relative;overflow:hidden;
     background:radial-gradient(circle at 36% 30%,#3A3A3C 0%,#0A0A0B 70%)}
  .orb-xl::before{content:"";position:absolute;inset:-30%;background:repeating-conic-gradient(from 0deg,rgba(255,255,255,.55) 0deg 1deg,transparent 1deg 14deg);animation:spin 9s linear infinite}
  .orb-xl::after{content:"";position:absolute;left:20%;top:20%;width:60%;height:60%;border-radius:50%;background:radial-gradient(circle,#fff 0%,rgba(255,255,255,.5) 42%,transparent 70%)}
  .arclbl{position:absolute;font-size:12px;font-weight:700;color:var(--ink);white-space:nowrap}
  .arclbl.l{left:-6px;top:34px}
  .arclbl.r{right:-14px;top:34px;font-size:11.5px}
  /* 语音模式底部栏：无边框、无底色 */
  .bar.bare{border:0;background:transparent;padding:0 16px}
"""
s = s.replace("  .notes{margin-top:30px", css + "  .notes{margin-top:30px", 1)

# ① 语音模式那台：换成「无边框 + 大球 + 两片长弧」
s = s.replace("""      <div class="barbox"><div class="bar">
        <span class="icbtn">⌨️</span>            <!-- 左：点按 → 切键盘模式 -->
        <span class="orb-lg"></span>            <!-- 圆球：屏幕下方居中 -->
        <span class="icbtn">📷</span>            <!-- 右：相机，点按拍照 / 长按图库 -->
      </div></div>""",
"""      <div class="voicezone">
        <div class="ringwrap">
          <span class="half left"></span><span class="half right"></span>
          <span class="arclbl l">取消</span><span class="arclbl r">滑到这里 转文字</span>
          <span class="orb-xl"></span>
        </div>
      </div>
      <div class="barbox"><div class="bar bare">
        <span class="icbtn">⌨️</span>
        <span class="icbtn">📷</span>
      </div></div>""", 1)

# ③ 按住说话那台：同样去掉椭圆边框、球变大、保留两片弧标签
s = s.replace("""      <div class="arcs">
        <span class="arc left">取消</span>
        <span class="arc right">滑到这里 转文字</span>
      </div>
      <div class="barbox"><div class="bar">
        <span class="icbtn">⌨️</span>
        <span class="orb-lg"></span>
        <span class="icbtn">📷</span>
      </div></div>""",
"""      <div class="voicezone">
        <div class="ringwrap">
          <span class="half left"></span><span class="half right"></span>
          <span class="arclbl l" style="color:var(--red)">取消 ✓</span><span class="arclbl r">滑到这里 转文字</span>
          <span class="orb-xl"></span>
        </div>
      </div>
      <div class="barbox"><div class="bar bare">
        <span class="icbtn">⌨️</span>
        <span class="icbtn">📷</span>
      </div></div>""", 1)

s = s.replace("底部从左到右：<b>键盘/语音切换</b>　·　<b>圆球（居中）</b>　·　<b>相机</b>。点左边键盘图标→切到键盘模式。",
 "进入语音模式后：<b>底部那条椭圆边框消失</b>，<b>圆球变大</b>并居中；<b>取消 / 转文字变成两片长弧半围着圆球</b>（按住时才显示）。左下角仍是键盘图标、右下角相机。")
io.open(p, "w", encoding="utf-8").write(s)
print("已改成：无边框 + 大球 + 两片长弧")
