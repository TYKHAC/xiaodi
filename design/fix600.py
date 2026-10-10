import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = "DeepSeekHarnessMobile/Views/DirectChatView.swift"
s = io.open(p, encoding="utf-8").read()
n = s.count("weight: .600")
s = s.replace("font(.system(size: 15, weight: .600))", "font(.system(size: 15, weight: .semibold))")
io.open(p, "w", encoding="utf-8").write(s)
print("替换 weight: .600 共", n, "处 → 剩", s.count(".600"))
