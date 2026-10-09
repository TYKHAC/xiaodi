//
//  朱小姐 · 大脑双向（P0 用户点名）
//  ─────────────────────────────────────────────────────────────
//  读：GET  http://<网关主机>:8902/search?q=… → brain.mjs search --json
//  写：POST http://<网关主机>:8902/capture     → brain.mjs capture → knowledge/90-inbox/
//  桥的另一头是 PC 上的 D:\dsh大脑\tools\brain-bridge.mjs（不动 DSH、无需重启）。
//
//  断连写入不丢：capture 失败进本地队列，恢复后可一键补投。
//
//  ⚠️ 编译坑（第20轮教训）：List 里塞大段复合表达式会触发
//  "unable to type-check in reasonable time" —— 必须拆成小节 computed var。
//

import SwiftUI

struct BrainBridgeView: View {
    @EnvironmentObject private var store: AppStore

    // 读
    @State private var query = ""
    @State private var hits: [BrainHit] = []
    @State private var isSearching = false
    @State private var searchError: String?

    // 写
    @State private var draft = ""
    @State private var tagsText = ""
    @State private var isCapturing = false
    @State private var captureTip: String?

    var body: some View {
        List {
            if let searchError {
                Label(searchError, systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            captureSection

            if !store.brainPending.isEmpty {
                queueSection
            }

            searchSection
        }
        .navigationTitle("大脑")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.flushBrainQueue() }
    }

    // MARK: - 写：捕获

    private var captureSection: some View {
        Section {
            TextEditor(text: $draft)
                .frame(minHeight: 96)
            TextField("标签（逗号分隔，如 朱小姐,进度）", text: $tagsText)
                .textInputAutocapitalization(.never)
            Button {
                capture()
            } label: {
                HStack {
                    Text("记入大脑")
                    Spacer()
                    if isCapturing { ProgressView() }
                }
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCapturing)
            if let captureTip {
                Text(captureTip)
                    .font(.caption)
                    .foregroundStyle(captureTip.hasPrefix("✓") ? Color.green : Color.orange)
            }
        } header: {
            Text("捕获（写入 90-inbox）")
        } footer: {
            Text(queueFooter)
        }
    }

    private var queueFooter: String {
        if store.brainPending.isEmpty {
            return "离线时自动排队，不丢；联网后可补投。"
        }
        return "离线队列 \(store.brainPending.count) 条 —— 下面补投。"
    }

    // MARK: - 离线队列

    private var queueSection: some View {
        Section("离线队列") {
            ForEach(store.brainPending) { item in
                Text(previewText(item.text))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("全部补投（\(store.brainPending.count) 条）") {
                store.flushBrainQueue()
            }
        }
    }

    private func previewText(_ text: String) -> String {
        text.count > 60 ? String(text.prefix(60)) + "…" : text
    }

    // MARK: - 读：检索

    private var searchSection: some View {
        Section {
            HStack {
                TextField("搜索大脑…（如：直连模式 决策）", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { search() }
                if isSearching {
                    ProgressView()
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(hits) { hit in
                hitRow(hit)
            }
        } header: {
            Text("检索（读大脑）")
        } footer: {
            Text("点结果=复制原文片段。数据来自电脑大脑的实时索引，不是过期快照。")
        }
    }

    private func hitRow(_ hit: BrainHit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hitTitle(hit))
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(hit.t.replacingOccurrences(of: "\n", with: " "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            Text(hit.p)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            UIPasteboard.general.string = hit.t
            captureTip = "✓ 片段已复制"
        }
    }

    private func hitTitle(_ hit: BrainHit) -> String {
        let heading = (hit.h ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return heading.isEmpty ? hit.p : heading
    }

    // MARK: - 动作

    private func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isSearching else { return }
        isSearching = true
        searchError = nil
        Task {
            do {
                hits = try await store.brainSearch(q)
                if hits.isEmpty { searchError = "没找到（换更短的关键词试试）" }
            } catch {
                searchError = shortError(error)
                hits = []
            }
            isSearching = false
        }
    }

    private func capture() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isCapturing else { return }
        isCapturing = true
        captureTip = nil
        Task {
            let inbox = await store.brainCapture(text: text, tags: tagsText.trimmingCharacters(in: .whitespacesAndNewlines))
            isCapturing = false
            if let inbox {
                captureTip = "✓ 已写入 \(inbox)"
                draft = ""
                tagsText = ""
            } else {
                captureTip = "⏳ 已排队，联网补投（见离线队列）"
            }
        }
    }

    private func shortError(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("无法连接") || text.contains("Could not connect") || text.contains("network") {
            return "连不上电脑桥（brain-bridge :8902）—— 电脑要开着且在同一网络"
        }
        return String(text.prefix(120))
    }
}

/// brain-bridge /search 的命中（字段名对齐 brain.mjs --json：p/h/l/t/n/m）
struct BrainHit: Decodable, Identifiable, Hashable {
    let score: Double?
    let p: String
    let h: String?
    let l: Int?
    let t: String
    let n: Int?
    let m: String?

    var id: String { "\(p)#\(l ?? 0)#\(t.prefix(24))" }
}

/// 断连时排队的捕获条目（UserDefaults 持久化，AppStore 负责收发）
struct BrainCaptureItem: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let text: String
    let tags: String
    let createdAt: Date

    init(text: String, tags: String) {
        self.id = UUID()
        self.text = text
        self.tags = tags
        self.createdAt = Date()
    }
}
