import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\voice-modes.html"
s = io.open(p, encoding="utf-8").read()
s = s.replace(".wxoverlay{flex:none;position:relative;z-index:7;padding:0 18px 2px}",
              ".wxoverlay{flex:none;position:relative;z-index:7;padding:0 18px 0;margin-bottom:-8px}")
s = s.replace(".wxcenter{display:flex;flex-direction:column;align-items:center;gap:3px}",
              ".wxcenter{display:flex;flex-direction:column;align-items:center;gap:1px}")
s = s.replace('.wxhints{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}',
              '.wxhints{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}')
s = s.replace(".wxsend{font-size:12.5px;color:#6E7278}",
              ".wxsend{font-size:12px;color:#6E7278;margin-top:-2px}")
io.open(p, "w", encoding="utf-8").write(s)
print("再下移")
