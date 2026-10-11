import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\voice-modes.html"
s = io.open(p, encoding="utf-8").read()

# ① 语音模式栏：相机与键盘互换（键盘左 / 相机右）
s = s.replace("""        <span class="icbtn">📷</span>            <!-- 相机：点按拍照 / 长按图库 -->
        <span class="orb-lg"></span>            <!-- 圆球：屏幕下方居中 -->
        <span class="icbtn">⌨️</span>            <!-- 点按 → 切键盘模式 -->""",
"""        <span class="icbtn">⌨️</span>            <!-- 左：点按 → 切键盘模式 -->
        <span class="orb-lg"></span>            <!-- 圆球：屏幕下方居中 -->
        <span class="icbtn">📷</span>            <!-- 右：相机，点按拍照 / 长按图库 -->""", 1)

# ② 键盘模式栏：同样互换（左=切回语音，右=相机）
s = s.replace("""        <span class="icbtn">📷</span>
        <span class="field">说点什么…</span>
        <span class="orb-sm"></span>              <!-- 点按 → 切回语音模式 -->""",
"""        <span class="orb-sm"></span>              <!-- 左：点按 → 切回语音模式 -->
        <span class="field">说点什么…</span>
        <span class="icbtn">📷</span>              <!-- 右：相机 -->""", 1)

# ③ 按住说话那台的栏也互换
s = s.replace("""        <span class="icbtn">📷</span>
        <span class="orb-lg"></span>
        <span class="icbtn">⌨️</span>""",
"""        <span class="icbtn">⌨️</span>
        <span class="orb-lg"></span>
        <span class="icbtn">📷</span>""", 1)

# ④ 文案同步（左键盘/右相机 + 键盘弹起收起规则）
s = s.replace("底部从左到右：<b>相机</b>　·　<b>圆球（居中）</b>　·　<b>键盘</b>。点键盘→切到键盘模式。",
              "底部从左到右：<b>键盘/语音切换</b>　·　<b>圆球（居中）</b>　·　<b>相机</b>。点左边键盘图标→切到键盘模式。")
s = s.replace("出现输入框；右边那颗小球<b>点一下切回语音模式</b>。相机位置不变（点按拍照 / 长按图库）。",
              "出现输入框；<b>点输入框弹起键盘，点键盘外任意处收起键盘</b>；左边小球点一下切回语音模式。右边仍是相机（点按拍照 / 长按图库）。")
s = s.replace("<b>相机</b>在<b>最左</b>，<b>圆球</b>中间，<b>键盘/语音切换</b>在<b>最右</b>",
              "<b>键盘/语音切换</b>在<b>最左</b>，<b>圆球</b>居中，<b>相机</b>在<b>最右</b>（你要求互换）")
s = s.replace("<li><b>位置</b> —— 相机在<b>最左</b>，圆球<b>中间</b>，键盘/语音切换在<b>最右</b>。</li>",
              "<li><b>位置（你要求互换）</b> —— <b>键盘/语音切换在左</b>、圆球居中、<b>相机在右</b>。</li>"
              "<li><b>键盘行为</b> —— 键盘模式点输入框弹起键盘；<b>点键盘外区域收起键盘</b>。</li>")
io.open(p, "w", encoding="utf-8").write(s)
print("已互换位置")
