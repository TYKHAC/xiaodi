import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\voice-modes.html"
s = io.open(p, encoding="utf-8").read()

# CSS：微信式浮层（角标 + 球靠下 + 波形）
css = """
  /* 微信式按住说话：左上「取消」/ 右上「转文字」，球靠下居中，球下「松开 发送」 */
  .wxoverlay{flex:none;position:relative;z-index:7;padding:0 18px 14px}
  .wxhints{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px}
  .wxhint{font-size:13.5px;font-weight:700;color:var(--ink);display:flex;align-items:center;gap:5px}
  .wxhint.on{color:var(--red)}
  .wxcenter{display:flex;flex-direction:column;align-items:center;gap:8px}
  .wxbars{display:flex;align-items:flex-end;gap:3px;height:26px;margin-bottom:2px}
  .wxbars i{width:4px;border-radius:2px;background:var(--ink);display:block;animation:wv 1s ease-in-out infinite}
  .wxbars i:nth-child(1){height:9px;animation-delay:0s}
  .wxbars i:nth-child(2){height:18px;animation-delay:.1s}
  .wxbars i:nth-child(3){height:26px;animation-delay:.2s}
  .wxbars i:nth-child(4){height:14px;animation-delay:.3s}
  .wxbars i:nth-child(5){height:22px;animation-delay:.4s}
  .wxbars i:nth-child(6){height:11px;animation-delay:.5s}
  .wxbars i:nth-child(7){height:17px;animation-delay:.6s}
  @keyframes wv{0%,100%{transform:scaleY(.5)}50%{transform:scaleY(1)}}
  .wxsend{font-size:12.5px;color:#6E7278}
  .orb-xl{margin-top:2px}
"""
s = s.replace("  .notes{margin-top:30px", css + "  .notes{margin-top:30px", 1)

# 语音模式那台：换成微信式浮层（球靠下 + 角标）
s = s.replace("""      <div class="voicezone">
        <div class="ringwrap">
          <span class="half left"></span><span class="half right"></span>
          <span class="arclbl l">取消</span><span class="arclbl r">滑到这里 转文字</span>
          <span class="orb-xl"></span>
        </div>
      </div>""",
"""      <div class="wxoverlay">
        <div class="wxhints">
          <span class="wxhint">↖ 取消</span>
          <span class="wxhint">转文字 ↗</span>
        </div>
        <div class="wxcenter">
          <div class="wxbars"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
          <span class="orb-xl" style="width:78px;height:78px"></span>
          <span class="wxsend">松开 发送</span>
        </div>
      </div>""", 1)

# 按住说话那台：微信式 + 左上高亮（取消）
s = s.replace("""      <div class="voicezone">
        <div class="ringwrap">
          <span class="half left"></span><span class="half right"></span>
          <span class="arclbl l" style="color:var(--red)">取消 ✓</span><span class="arclbl r">滑到这里 转文字</span>
          <span class="orb-xl"></span>
        </div>
      </div>""",
"""      <div class="wxoverlay">
        <div class="wxhints">
          <span class="wxhint on">↖ 松开 取消</span>
          <span class="wxhint">转文字 ↗</span>
        </div>
        <div class="wxcenter">
          <div class="wxbars"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
          <span class="orb-xl" style="width:78px;height:78px;opacity:.55"></span>
          <span class="wxsend" style="color:var(--red)">松开手指，取消发送</span>
        </div>
      </div>""", 1)

s = s.replace("进入语音模式后：<b>底部那条椭圆边框消失</b>，<b>圆球变大</b>并居中；<b>取消 / 转文字变成两片长弧半围着圆球</b>（按住时才显示）。左下角是相机、右下角是键盘/语音切换。",
 "进入语音模式后：<b>椭圆边框消失</b>、<b>圆球变大并往下靠</b>；<b>按住时照微信那样</b> —— 左上角「↖ 取消」、右上角「转文字 ↗」，球上方一排音量波形，球下写「松开 发送」；左上滑=取消（变红），右上滑=转文字。左下相机、右下键盘/语音。")
io.open(p, "w", encoding="utf-8").write(s)
print("已改成微信式")
