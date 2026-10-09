# 第28轮：WorkspaceView 白字/白描边 → 自适应色（浅色珍珠底上白字隐身 = 用户说的"兼容性差"）
# 逐条替换 + 断言命中次数；任何一条没找到就报错不写盘。
import io, sys
sys.stdout.reconfigure(encoding="utf-8")

P = r"D:\xiaodi-push\DeepSeekHarnessMobile\Views\WorkspaceView.swift"

PAIRS = [
    # (old, new, expected_count)
    ("Color.green : Color.white.opacity(0.4)", "Color.green : Color.secondary", 1),
    (".foregroundStyle(.white.opacity(0.6))", ".foregroundStyle(.secondary)", 1),
    ("foregroundStyle(.white.opacity(0.55)).lineLimit(1)", "foregroundStyle(.secondary).lineLimit(1)", 1),
    ('Image(systemName: "chevron.down").font(.caption).foregroundStyle(.white.opacity(0.55))',
     'Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)', 1),
    ("stroke(.white.opacity(0.14))", "stroke(Color.primary.opacity(0.14))", 1),
    ('.foregroundStyle(.white.opacity(0.68))', '.foregroundStyle(.secondary)', 1),
    (".foregroundStyle(.white.opacity(0.58))", ".foregroundStyle(.secondary)", 1),
    (".foregroundStyle(.white.opacity(0.92))\n            .tint(.white)",
     ".foregroundStyle(.primary)\n            .tint(DSHColor.ocean)", 1),
    ("stroke(.white.opacity(0.1))", "stroke(Color.primary.opacity(0.1))", 1),
    ("foregroundStyle(.white.opacity(0.5))", "foregroundStyle(.secondary)", 1),
    (".overlay(.white.opacity(0.1))", ".overlay(Color.primary.opacity(0.1))", 1),
    (": .white.opacity(0.35)))", ": Color.secondary.opacity(0.35)))", 1),
    ("monospaced()).foregroundStyle(.white.opacity(0.42))", "monospaced()).foregroundStyle(.secondary)", 1),
    (".blue : .white.opacity(0.48))", ".blue : Color.secondary)", 1),
    ("Color.white.opacity(0.18), lineWidth: 0.8", "Color.primary.opacity(0.18), lineWidth: 0.8", 1),
    ("case .disconnected: .white.opacity(0.5)", "case .disconnected: Color.secondary", 1),
    (".foregroundStyle(.white.opacity(0.72))", ".foregroundStyle(.secondary)", 1),
]

src = io.open(P, encoding="utf-8").read()
errors = []
for old, new, want in PAIRS:
    n = src.count(old)
    if n != want:
        errors.append(f"命中{n}次(期望{want}): {old[:60]}")
        continue
    src = src.replace(old, new)

if errors:
    print("FAIL —— 未写盘：")
    for e in errors:
        print("  " + e)
    sys.exit(1)

io.open(P, "w", encoding="utf-8", newline="").write(src)
left = src.count(".white.opacity") + src.count(".foregroundStyle(.white)")
print(f"✓ 替换 {len(PAIRS)} 组；残留 white 样式={left}（L339 glassSurface dark 卡刻意保留）")
