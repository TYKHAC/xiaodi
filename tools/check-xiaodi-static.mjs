/**
 * 小弟语音层的静态自检 —— 在没有 Mac / 编译不了的环境里，
 * 至少把「低级但致命」的错误挡在上传之前。
 *
 * ⚠️ 这**不等于**编译通过。它只做我能在 Windows 上真做的那几件事：
 *   1. 括号/引号平衡（最常见的低级错）
 *   2. 常见 Swift 陷阱（@MainActor 上下文误用、SwiftUI 必需 import）
 *   3. 我自己接的调用点，签名是否与定义一致（真实跨文件核对）
 *
 * 诚实边界：类型检查、SwiftUI 布局、AVAudioSession 真机行为
 * 都需要 Xcode 才能验 —— 这里一律不假装验过。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const APP = path.join(ROOT, 'DeepSeekHarnessMobile');

const problems = [];
const notes = [];

// ---- 检查的文件 ----
const targets = {
  'Core/VoiceInputController.swift':            path.join(APP, 'Core', 'VoiceInputController.swift'),
  'Components/SiriMicButton.swift':            path.join(APP, 'Components', 'SiriMicButton.swift'),
  'Core/AppStore.swift':                       path.join(APP, 'Core', 'AppStore.swift'),
  'Core/AppPreferences.swift':                 path.join(APP, 'Core', 'AppPreferences.swift'),
  'Views/ConversationView.swift':              path.join(APP, 'Views', 'ConversationView.swift'),
  'Resources/Info.plist':                      path.join(APP, 'Resources', 'Info.plist'),
};

const read = (p) => (fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null);

// ---- 1. 括号 / 引号平衡（跳过字符串与注释里的）----
function balance(text) {
  let depth = { '(': 0, '{': 0, '[': 0 };
  const close = { ')': '(', '}': '{', ']': '[' };
  let inLine = false, inBlock = false, inStr = false, inMulti = false, esc = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i], n = text[i + 1];
    if (inLine) { if (c === '\n') inLine = false; continue; }
    if (inBlock) { if (c === '*' && n === '/') { inBlock = false; i++; } continue; }
    if (inStr) {
      if (esc) { esc = false; continue; }
      if (c === '\\') { esc = true; continue; }
      if (c === '"') inStr = false;
      continue;
    }
    if (inMulti) { if (c === '"' && text.slice(i, i + 3) === '"""') { inMulti = false; i += 2; } continue; }
    if (c === '/' && n === '/') { inLine = true; i++; continue; }
    if (c === '/' && n === '*') { inBlock = true; i++; continue; }
    if (text.slice(i, i + 3) === '"""') { inMulti = true; i += 2; continue; }
    if (c === '"') { inStr = true; continue; }
    if (depth[c] !== undefined) depth[c]++;
    else if (close[c] !== undefined) depth[close[c]]--;
  }
  return depth;
}

for (const [name, p] of Object.entries(targets)) {
  const t = read(p);
  if (t == null) { problems.push(`${name}: 文件不存在`); continue; }
  if (!name.endsWith('.swift')) continue;
  const d = balance(t);
  for (const [k, v] of Object.entries(d)) {
    if (v !== 0) problems.push(`${name}: '${k}' 不平衡 (${v > 0 ? `多 ${v}` : `少 ${-v}`})`);
  }
  notes.push(`${name}: 括号平衡检查通过 (${Object.values(d).join('/')})`);
}

// ---- 2. 必需 import ----
const voice = read(targets['Core/VoiceInputController.swift']) || '';
const mic = read(targets['Components/SiriMicButton.swift']) || '';
const store = read(targets['Core/AppStore.swift']) || '';
const conv = read(targets['Views/ConversationView.swift']) || '';

const need = [
  ['VoiceInputController.swift', voice, ['import Foundation', 'import AVFoundation', 'import Speech']],
  ['SiriMicButton.swift', mic, ['import SwiftUI']],
];
for (const [n, t, imps] of need) {
  for (const imp of imps) {
    if (!t.includes(imp)) problems.push(`${n}: 缺少 ${imp}`);
  }
}

// ---- 3. 跨文件签名一致性（真实核对，不猜）----
const storeHas = (needle) => store.includes(needle);

const checks = [
  ['AppStore 声明 let voice', storeHas('let voice = VoiceInputController()')],
  ['AppStore 有 sendByVoice', /func sendByVoice\(/.test(store)],
  ['AppStore 有 lastAssistantReplyText', /func lastAssistantReplyText\(/.test(store)],
  ['AppStore 有 speakRepliesEnabled', storeHas('speakRepliesEnabled')],
  ['AppStore 接上 onTranscribed', storeHas('self.voice.onTranscribed')],
  ['AppStore 有 lastTurnWasVoice', storeHas('lastTurnWasVoice')],
  ['VoiceInputController 有 onTranscribed 回调', /var onTranscribed:/.test(voice)],
  ['VoiceInputController 有 beginRecording', /func beginRecording\(\)/.test(voice)],
  ['VoiceInputController 有 endRecording', /func endRecording\(\)/.test(voice)],
  ['VoiceInputController 有 speak(_:)', /func speak\(_ text: String\)/.test(voice)],
  ['VoiceInputController 有 stopSpeaking', /func stopSpeaking\(\)/.test(voice)],
  ['VoiceInputController 有 isHeld', /var isHeld: Bool/.test(voice)],
  ['VoiceInputController 有 requestPermissionsIfNeeded', /func requestPermissionsIfNeeded\(\)/.test(voice)],
  ['SiriMicButton 用 voice.isHeld', mic.includes('voice.isHeld')],
  ['SiriMicButton 用 voice.beginRecording', mic.includes('voice.beginRecording')],
  ['SiriMicButton 用 voice.endRecording', mic.includes('voice.endRecording')],
  ['ConversationView 放了 SiriMicButton', conv.includes('SiriMicButton(voice: store.voice')],
  ['ConversationView 放了 VoiceStateBadge', conv.includes('VoiceStateBadge(voice: store.voice')],
  ['ConversationView 申请了权限', conv.includes('requestPermissionsIfNeeded')],
  ['Info.plist 有麦克风权限', (read(targets['Resources/Info.plist']) || '').includes('NSMicrophoneUsageDescription')],
  ['Info.plist 有识别权限', (read(targets['Resources/Info.plist']) || '').includes('NSSpeechRecognitionUsageDescription')],
];
for (const [name, ok] of checks) {
  if (!ok) problems.push(`接线缺失: ${name}`);
}

// ---- 4. SwiftUI @ObservedObject 与 VoiceInputController 的 ObservableObject 兼容性 ----
// 允许多重继承：NSObject 必须排最前（AVSpeechSynthesizerDelegate 是 @objc 协议，
// Swift 类要实现 @objc 协议就得继承 NSObject），但 ObservableObject 仍必须存在。
if (!/final class VoiceInputController:[^{]*\bObservableObject\b/.test(voice)) {
  problems.push('VoiceInputController 未声明 ObservableObject —— @ObservedObject 用不了');
}

// ---- 5. pbxproj 四处登记 ----
const pbx = read(path.join(ROOT, 'DeepSeekHarnessMobile.xcodeproj', 'project.pbxproj')) || '';
for (const f of ['VoiceInputController.swift', 'SiriMicButton.swift']) {
  const n = (pbx.match(new RegExp(f.replace('.', '\\.'), 'g')) || []).length;
  if (n < 4) problems.push(`pbxproj: ${f} 只登记了 ${n} 处（需要 4 处）`);
}

// ---- 输出 ----
console.log('── 括号检查 ──');
notes.forEach((n) => console.log('  ' + n));
console.log('── 接线检查 ──');
console.log(`  ${checks.length} 项，通过 ${checks.filter(([, ok]) => ok).length}`);
console.log('── 结论 ──');
if (problems.length === 0) {
  console.log('STATIC=PASS');
  console.log('（仅静态检查通过；**编译与真机行为未验证**，需 GitHub Actions + AltStore）');
  process.exit(0);
}
problems.forEach((p) => console.log('  ✗ ' + p));
console.log(`STATIC=FAIL (${problems.length} 个问题)`);
process.exit(1);