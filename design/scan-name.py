import json, io, os, sys, re
sys.stdout.reconfigure(encoding="utf-8")
R = r"D:\xiaodi-push\DeepSeekHarnessMobile\Resources"
targets = [os.path.join(R,"Info.plist"), os.path.join(R,"InfoPlist.xcstrings"), os.path.join(R,"Localizable.xcstrings")]
for p in targets:
    if not os.path.exists(p): print("缺", p); continue
    s = io.open(p, encoding="utf-8").read()
    n = s.count("朱小姐")
    print(f"{os.path.basename(p)}: 出现 朱小姐 {n} 次")
    if n:
        for m in re.finditer("朱小姐", s):
            seg = s[max(0,m.start()-70):m.start()+40].replace("\n"," ")
            print("   …", seg)
