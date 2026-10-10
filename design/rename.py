import json, io, os, sys
sys.stdout.reconfigure(encoding="utf-8")
R = r"D:\xiaodi-push\DeepSeekHarnessMobile\Resources"

# ---------- 1) Info.plist（纯文本，安全）----------
p = os.path.join(R, "Info.plist")
s = io.open(p, encoding="utf-8").read()
before = s.count("朱小姐")
s = s.replace("拍照发给朱小姐，或扫描电脑端生成的配对二维码。", "拍照发给 Hestia 分析。")
s = s.replace("朱小姐", "Hestia")
io.open(p, "w", encoding="utf-8").write(s)
print(f"Info.plist: 替换 {before} 处 → 剩 {s.count('朱小姐')}")

# ---------- 2) xcstrings（先改名 key，再改值；重新解析校验）----------
for fn in ("InfoPlist.xcstrings", "Localizable.xcstrings"):
    p = os.path.join(R, fn)
    raw = io.open(p, encoding="utf-8").read()
    orig = json.loads(raw)
    n_before = len(orig.get("strings", {}))
    before = raw.count("朱小姐")

    # key 改名（这些 key 就是源文案，改了要同步其英文翻译值）
    raw = raw.replace('"朱小姐 · 正在生成"', '"正在生成"')
    raw = raw.replace('"朱小姐 预览版"', '"Hestia 预览版"')
    # 值替换
    raw = raw.replace("朱小姐", "Hestia")

    after = json.loads(raw)          # 解析失败会抛错，不会写坏文件
    n_after = len(after.get("strings", {}))
    if n_after != n_before:
        print(f"  ✗ {fn}: 条目数变了 {n_before}→{n_after}，拒绝写入")
        continue
    io.open(p, "w", encoding="utf-8").write(raw)
    print(f"{fn}: 替换 {before} 处 → 剩 {raw.count('朱小姐')}；条目数 {n_after} 未变 ✓")

print("\n--- 校验：资源里还有没有 朱小姐 ---")
for fn in ("Info.plist", "InfoPlist.xcstrings", "Localizable.xcstrings"):
    s = io.open(os.path.join(R, fn), encoding="utf-8").read()
    print(f"  {fn}: {s.count('朱小姐')} 处")
