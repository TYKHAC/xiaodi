import io, re, sys, glob
sys.stdout.reconfigure(encoding="utf-8")
files = glob.glob("DeepSeekHarnessMobile/**/*.swift", recursive=True)
total = 0
for p in files:
    raw = io.open(p, encoding="utf-8").read()
    if "朱小姐" not in raw: continue
    n = raw.count("朱小姐")
    # 用户可见的文案 + 注释头统一改成 Hestia
    new = raw.replace("朱小姐", "Hestia")
    io.open(p, "w", encoding="utf-8").write(new)
    total += n
    print(f"  {p.replace(chr(92),'/').split('/')[-1]}: {n} 处")
print("Swift 共替换", total, "处")
