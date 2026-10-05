/**
 * 把小弟新增的两个 Swift 文件登记进 Xcode 工程（老式 pbxproj, objectVersion 60）。
 *
 * 为什么必须这么做：pbxproj 是**显式文件清单**，不是目录扫描。
 * 光把 .swift 丢进文件夹，Xcode 根本不知道它存在 —— 编译时不会报错，
 * 只是「文件不见了」。这正是「静默失败」，比报错更可怕。
 *
 * 要登记四处（缺一不可）：
 *   1. PBXBuildFile     —— 参与编译
 *   2. PBXFileReference —— 文件本身
 *   3. PBXGroup (Core)  —— 在 Xcode 里能看到
 *   4. PBXSourcesBuildPhase —— 真正进编译列表
 *
 * 用法：node tools/register-xiaodi-files.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// 注意：不能用 import.meta.url 拼路径 —— 大脑目录名是中文（%E5%A4%A7%E8%84%91），
// URL 会百分号编码，fs 读不到。必须先 fileURLToPath 解码再用 path.join。
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const PBX = path.join(ROOT, 'DeepSeekHarnessMobile.xcodeproj', 'project.pbxproj');

// 用可辨识但不与现有冲突的 ID 前缀
const NEW = [
  { name: 'VoiceInputController.swift', group: 'Core',      id: 'A9F1X01' },
  { name: 'SiriMicButton.swift',        group: 'Components', id: 'A9F1X02' },
];

let text = fs.readFileSync(PBX, 'utf8');
const before = text;
let changed = [];

for (const f of NEW) {
  const buildId = `${f.id}0`;
  const refId = `${f.id}1`;

  // 已有就跳过（脚本可重复跑）
  if (text.includes(`/* ${f.name} */`)) {
    changed.push(`skip ${f.name} (已登记)`);
    continue;
  }
  if (!fs.existsSync(path.join(ROOT, 'DeepSeekHarnessMobile', f.group, f.name))) {
    changed.push(`MISSING FILE ${f.group}/${f.name} —— 先把文件放好再跑`);
    continue;
  }

  // 1. PBXBuildFile
  text = text.replace(
    /(A9F100000000000000000001 \/\* AppPreferences\.swift in Sources \*\/ = \{isa = PBXBuildFile)/,
    `${buildId} /* ${f.name} in Sources */ = {isa = PBXBuildFile; fileRef = ${refId} /* ${f.name} */; };\n\t$1`,
  );

  // 2. PBXFileReference
  text = text.replace(
    /(A9F100000000000000000002 \/\* AppPreferences\.swift \*\/ = \{isa = PBXFileReference)/,
    `${refId} /* ${f.name} */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = ${f.name}; sourceTree = "<group>"; };\n\t$1`,
  );

  // 3. Group：在同组的 AppPreferences（Core）或 ConversationViewport（Components）后面挂一行
  const anchor = f.group === 'Core'
    ? '(A9F100000000000000000002 /* AppPreferences.swift */,'
    : '(D863208EF01781A899165473448240DD51AFA530 /* Components */,';
  if (text.includes(anchor)) {
    text = text.replace(anchor, `${anchor}\n\t\t\t\t${refId} /* ${f.name} */,`);
  } else {
    changed.push(`WARN ${f.name}: 没找到 ${f.group} 组锚点，需要手工加到分组`);
  }

  // 4. Sources build phase
  text = text.replace(
    /(A9F100000000000000000001 \/\* AppPreferences\.swift in Sources \*\/,)/,
    `${buildId} /* ${f.name} in Sources */,\n\t$1`,
  );

  changed.push(`added ${f.group}/${f.name}`);
}

if (text === before) {
  console.log('pbxproj 无变化');
} else {
  fs.writeFileSync(PBX, text, 'utf8');
  console.log('pbxproj 已更新：');
  changed.forEach((c) => console.log('  ' + c));
}

// 校验：每个新文件四处齐全
let verify = true;
for (const f of NEW) {
  const n = (text.match(new RegExp(f.name, 'g')) || []).length;
  const ok = n >= 4;
  if (!ok) verify = false;
  console.log(`  ${ok ? 'OK ' : 'BAD'} ${f.name}: 出现 ${n} 次（需要 ≥4）`);
}
console.log(verify ? 'REGISTER=PASS' : 'REGISTER=FAIL');
process.exit(verify ? 0 : 1);
