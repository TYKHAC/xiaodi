import io, os, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\zhuxiaojie-ui-opt.html"
s = io.open(p, encoding="utf-8").read()
print("残留 朱小姐:", s.count("朱小姐"))
s = s.replace("朱小姐", "Hestia")
s = s.replace("输入栏统一成 ZhuTheme 的珍珠圆球 + 发送键", "输入栏统一（圆球换成 Siri 风格动态球）")
s = s.replace("气泡淡染描边；输入栏统一。深色同样适用。", "气泡淡染描边；输入栏统一。深色同样适用。")

# 待办清单补两条：名字/图标 + 圆球动效
old = '<li><b>⑧ 【新增·按住说话】</b>'
new = ('<li><b>⑨ 新名字 + 新图标</b> —— App 名改为 <b>Hestia</b>；图标换成你给的御姐头像'
       '（已抠成 1024 装进 iOS 图标资产，light/dark 两套）。</li>\n'
       '        <li><b>⑩ 圆球换成 Siri 风格动态球</b> —— 深色球体 + 四团流动彩色光带（蓝/粉/青/紫）+ 中心呼吸亮核；'
       '空闲慢速暗淡、按住加速变亮、播报时脉冲；开了「减少动态效果」自动停。</li>\n'
       '        ' + old)
s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8").write(s)
print("更新完成，大小", os.path.getsize(p)//1024, "KB")
