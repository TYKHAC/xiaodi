import io, sys, os
sys.stdout.reconfigure(encoding="utf-8")
b64 = io.open(r"D:\xiaodi-push\design\icon-b64.txt", encoding="utf-8").read().strip()
p = r"D:\xiaodi-push\_preview\chat-fonts2.html"
s = io.open(p, encoding="utf-8").read()
s = s.replace('src="ICON"', 'src="data:image/jpeg;base64,' + b64 + '"')
io.open(p, "w", encoding="utf-8").write(s)
print("图标已内嵌")
