import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\voice-modes.html"
s = io.open(p, encoding="utf-8").read()

# 语音模式栏：相机左 / 键盘右
s = s.replace("""        <span class="icbtn">⌨️</span>
        <span class="icbtn">📷</span>""",
"""        <span class="icbtn">📷</span>
        <span class="icbtn">⌨️</span>""")

# 键盘模式栏：相机左 / 语音切换右
s = s.replace("""        <span class="orb-sm"></span>              <!-- 左：点按 → 切回语音模式 -->
        <span class="field">说点什么…</span>
        <span class="icbtn">📷</span>              <!-- 右：相机 -->""",
"""        <span class="icbtn">📷</span>              <!-- 左：相机 -->
        <span class="field">说点什么…</span>
        <span class="orb-sm"></span>              <!-- 右：点按 → 切回语音模式 -->""")

s = s.replace("左下角仍是键盘图标、右下角相机",
              "左下角是相机、右下角是键盘/语音切换")
s = s.replace("<b>键盘/语音切换</b>在<b>最左</b>，<b>圆球</b>居中，<b>相机</b>在<b>最右</b>（你要求互换）",
              "<b>相机在左</b>、<b>圆球</b>居中、<b>键盘/语音切换在右</b>")
s = s.replace("<li><b>位置（你要求互换）</b> —— <b>键盘/语音切换在左</b>、圆球居中、<b>相机在右</b>。</li>",
              "<li><b>位置</b> —— <b>相机在左</b>、圆球居中、<b>键盘/语音切换在右</b>。</li>")
io.open(p, "w", encoding="utf-8").write(s)
print("已换成：相机左 / 键盘右")
