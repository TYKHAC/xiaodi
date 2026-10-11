import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\voice-modes.html"
s = io.open(p, encoding="utf-8").read()
s = s.replace(".wxoverlay{flex:none;position:relative;z-index:7;padding:0 18px 14px}",
              ".wxoverlay{flex:none;position:relative;z-index:7;padding:0 18px 2px}")
s = s.replace(".wxcenter{display:flex;flex-direction:column;align-items:center;gap:8px}",
              ".wxcenter{display:flex;flex-direction:column;align-items:center;gap:3px}")
s = s.replace(".wxbars{display:flex;align-items:flex-end;gap:3px;height:26px;margin-bottom:2px}",
              ".wxbars{display:flex;align-items:flex-end;gap:3px;height:26px;margin-bottom:0}")
s = s.replace(".orb-xl{margin-top:2px}", ".orb-xl{margin-top:0}")
s = s.replace('.wxhints{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px}',
              '.wxhints{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}')
io.open(p, "w", encoding="utf-8").write(s)
print("球已下移")
