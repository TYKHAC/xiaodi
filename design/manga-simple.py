import io, sys, os
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\theme-manga.html"
s = io.open(p, encoding="utf-8").read()

# 1) 线框：2px → 1px（更简）
s = s.replace("border:2px solid var(--line)", "border:1px solid var(--line)")
s = s.replace("border:2px solid var(--ink)", "border:1px solid var(--ink)")
s = s.replace("border:1.5px solid var(--ink)", "border:1px solid var(--ink)")
s = s.replace("border:1.5px solid var(--line)", "border:1px solid var(--line)")
# 2) 网点压淡
s = s.replace("background-size:5px 5px;opacity:.10", "background-size:5px 5px;opacity:.06")
s = s.replace("background-size:8px 8px;opacity:.14", "background-size:8px 8px;opacity:.08")
# 3) 去掉放射速度线（花哨）—— 换成球外一圈极细的柔环
s = s.replace(""".burst{position:absolute;inset:0;z-index:1;pointer-events:none;
     background:repeating-conic-gradient(from 0deg, rgba(11,11,12,.22) 0deg 1deg, transparent 1deg 7deg);
     mask-image:radial-gradient(circle, transparent 30%, #000 62%);
     -webkit-mask-image:radial-gradient(circle, transparent 30%, #000 62%)}""",
""".burst{position:absolute;inset:0;z-index:1;pointer-events:none}""")
# 4) 球内的速度线也简化成更细更慢的白线
s = s.replace("background:repeating-conic-gradient(from 0deg, rgba(255,255,255,.85) 0deg 2deg, transparent 2deg 12deg);",
              "background:repeating-conic-gradient(from 0deg, rgba(255,255,255,.55) 0deg 1deg, transparent 1deg 14deg);")
# 5) 标题说明改成"最简版"
s = s.replace("Hestia · 主题方向：黑白日漫（NANA 风）", "Hestia · 主题方向：黑白日漫（最简版）")
s = s.replace("""  按你要的：<b>日漫黑白，不是水墨</b>。规则取自日漫「分镜排版」的成文规范 ——
  <b>墨黑压纸白 + 网点灰做层次 + 粗墨线画格 + 只留一记烈焰赤红</b>；
  NANA（矢泽爱）那边的特征是<b>优雅细线 + 网点阴影 + 朋克元素（桃心/玫瑰/格纹）</b>。
  所以：<b>没有一处柔光渐变、没有灰度晕染</b>（那是水墨路数），层次全部用<b>网点圆点</b>做。""",
"""  <b>黑白日漫，最简</b>：墨黑 + 纸白 + <b>很淡的网点</b>，线框细到 1px，<b>不要朋克元素</b>（桃心/玫瑰/格纹全去掉），
  也不要花哨的放射线。层次只靠<b>网点 + 线条粗细</b>，别的一概不加。""")
# 6) 去掉 NANA 元素的整块说明，换成"极简规则"
s = s.replace("""      <li><b>桃心 / 玫瑰 / 链条</b>：NANA 的标志物（西太后朋克那一路），可以做成很淡的线稿纹样，只出现在空态或加载态。</li>
      <li><b>格纹（tartan）</b>：NANA 的第二个标志，适合做抽屉顶部的一条窄带。</li>
      <li>我建议<b>克制用</b>：主界面保持"纸白 + 墨线 + 网点"，标志物只在少数地方点一下 —— 用多了就不冷酷了。</li>""",
"""      <li><b>不加任何图案</b>：没有桃心、没有玫瑰、没有格纹 —— 你要简单，那这些全砍掉。</li>
      <li><b>不加装饰线</b>：分隔只用 1px 细线，不用花纹。</li>
      <li><b>赤红只留一处</b>（"准备就绪"那个点）；你说不要红也行，那就是纯黑白。</li>""")
s = s.replace("<h3>NANA 专属元素（要不要加，你定）</h3>", "<h3>「再简单一点」我砍掉了什么</h3>")
io.open(p, "w", encoding="utf-8").write(s)
print("已改到最简版")
