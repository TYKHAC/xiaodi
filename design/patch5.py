import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\zhuxiaojie-ui-opt.html"
s = io.open(p, encoding="utf-8").read()
old = """  .gbtn{font-size:13px;color:#F3F5F8;background:rgba(22,24,30,.72);border:none;
        border-radius:16px;padding:13px 18px;min-width:76px;text-align:center;font-weight:500;
        -webkit-backdrop-filter:blur(12px);backdrop-filter:blur(12px);
        box-shadow:0 8px 22px rgba(0,0,0,.30), inset 0 1px 0 rgba(255,255,255,.10)}
  .gbtn.wide{padding:13px 24px}"""
new = """  /* 手势胶囊 = 照用户参考图复刻（更大/更黑/圆角矩形/字重600，左窄右宽） */
  .gbtn{font-size:15px;color:#fff;background:rgba(12,13,16,.80);border:none;
        border-radius:14px;padding:15px 22px;min-width:88px;text-align:center;font-weight:600;
        -webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);
        box-shadow:0 8px 22px rgba(0,0,0,.32), inset 0 1px 0 rgba(255,255,255,.14)}
  .gbtn.wide{padding:15px 30px}"""
assert old in s, "gbtn CSS 没匹配上"
s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8").write(s)
print("已应用 B 样式")
