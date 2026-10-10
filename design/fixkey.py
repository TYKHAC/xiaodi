import json, io, os, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\DeepSeekHarnessMobile\Resources\Localizable.xcstrings"
raw = io.open(p, encoding="utf-8").read()
before = len(json.loads(raw)["strings"])
raw = raw.replace('"正在生成": {', '"正在生成…": {')
after = json.loads(raw)
assert len(after["strings"]) == before, "条目数变了"
io.open(p, "w", encoding="utf-8").write(raw)
print("key 已对齐代码：正在生成… ；条目数", len(after["strings"]), "未变 ✓")
