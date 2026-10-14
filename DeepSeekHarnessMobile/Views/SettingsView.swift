import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pendingPermission: DefaultPermissionChoice?
    // 直连 API Key 的编辑态：首次从 Keychain 读出（回显即在位，可改可清空）
    @State private var directAPIKey: String = DirectAPIKeyStore.load() ?? ""
    // 模型配置中心：生图/视频各自的 Key 编辑态
    @State private var mediaImageKey: String = MediaAPIKeyStore.load(.image) ?? ""
    @State private var mediaVideoKey: String = MediaAPIKeyStore.load(.video) ?? ""
    // 模型配置默认收起（用户 2026-10-09：「配置模型那里要简洁一点，全摊开的收起来」）
    @State private var modelConfigExpanded = false
    /// 「连接设置」二级页是否推出（平时由那一行的 NavigationLink 推）
    @State private var showRemoteDetail = false
    /// 对话字体二级页（问题 C：16 行太长，收成一行点进来）
    @State private var showNameFontPicker = false
    // 用户 2026-10-11 图三：「这个聊天模型也要可以收起来」
    // —— 模型展开后，聊天/生图/视频三段各自还能再收起，默认收起（干净）
    @State private var chatModelExpanded = false
    @State private var imageModelExpanded = false
    @State private var videoModelExpanded = false

    /// 可收起的段头（照「模型」行那套：标题 + chevron，点一下开合）
    private func collapseHeader(
        _ title: String,
        isExpanded: Bool,
        toggle: @escaping () -> Void
    ) -> some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    /// CI 视觉自查模式（正常启动为空）
    private var shotMode: String? { ProcessInfo.processInfo.environment["ZXJ_SHOT"] }

    private var selectedPresetName: String {
        guard let id = store.agentPresetDefault else { return String(localized: "未读取") }
        return store.agentPresets.first(where: { $0.id == id })?.displayName ?? id
    }

    private var selectedPermissionName: String {
        guard let id = store.permissionDefault else { return String(localized: "未读取") }
        return store.permissionDefaultOptions.first(where: { $0.value == id })?.name ?? id
    }

    private var defaultsAreLoading: Bool {
        !store.defaultConfigurationLoadingKinds.isDisjoint(with: ["defaults", "agent-presets"])
    }

    private var defaultModelIsLoading: Bool {
        store.defaultConfigurationLoadingKinds.contains("default-model")
            || store.defaultConfigurationLoadingKinds.contains("save-default-model")
    }

    private var defaultModelValueText: String {
        guard let selection = store.defaultModelSelection else { return String(localized: "未读取") }
        let item = store.anyModelCatalog?.groups
            .first(where: { $0.id == selection.provider })?
            .models.first(where: { $0.id == selection.model })
        let name = item?.name ?? Self.modelDisplayName(selection.model)
        guard let effort = selection.reasoningEffort else { return name }
        let effortName = item?.reasoning?.efforts.first(where: { $0.id == effort })?.name ?? Self.reasoningEffortDisplayName(effort)
        return "\(name) · \(effortName)"
    }

    static func modelDisplayName(_ id: String) -> String {
        switch id {
        case "deepseek-chat": return "聊天模型"
        case "deepseek-reasoner": return "推理模型"
        default: return id
        }
    }

    static func reasoningEffortDisplayName(_ id: String) -> String {
        switch id.lowercased() {
        case "low": return String(localized: "低")
        case "medium": return String(localized: "中")
        case "high": return String(localized: "高")
        default: return id.capitalized
        }
    }

    var body: some View {
        Form {
            // Hestia：原来的「新会话默认配置」（Agent 预设 / 默认模型 / 权限）是电脑端
            // 部署级设置，手机独立 agent 用不上 —— 用户 2026-10-10 说设置不专业、有
            // 多余的设置，整段移除（相关 store 接口保留，将来要接再放回）。

            Section {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { modelConfigExpanded.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        SettingsTile(systemImage: "cpu")
                        Text(modelConfigExpanded ? "收起模型配置" : "模型（聊天 · 生图 · 视频）")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: modelConfigExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }

            if modelConfigExpanded {
            Section {
                if chatModelExpanded {
                TextField("接口地址（如 https://your-relay.com/v1）", text: $store.directConfig.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("模型（填你的模型名）", text: $store.directConfig.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Key", text: $directAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("保存 Key 到本机 Keychain") {
                    do {
                        let trimmed = directAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { DirectAPIKeyStore.delete() } else {
                            try DirectAPIKeyStore.save(trimmed)
                        }
                        store.directTestState = nil
                    } catch {
                        store.lastError = error.localizedDescription
                    }
                }
                Button {
                    store.testDirectConnection()
                } label: {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        switch store.directTestState {
                        case nil: EmptyView()
                        case .testing: ProgressView()
                        case .ok(let reply): Text("✓ " + reply).foregroundStyle(.green).lineLimit(1)
                        case .fail(let reason): Text(reason).foregroundStyle(.red).lineLimit(2)
                        }
                    }
                }
                .disabled(store.directTestState == .testing)
                }
            } header: {
                collapseHeader("聊天模型", isExpanded: chatModelExpanded) {
                    withAnimation(.easeInOut(duration: 0.2)) { chatModelExpanded.toggle() }
                }
            } footer: {
                if chatModelExpanded {
                Text("填好接口地址、模型名和 API Key，这个壳就是一个完整的 agent（不再需要任何「模式」开关）。Key 只存本机 Keychain。地址末尾写不写 /v1 都行 —— App 会自动试并记住能通的那个；「测试连接」成功时也会告诉你它实际用了哪个地址。")
                }
            }

            Section {
                if imageModelExpanded {
                Toggle("启用生图模型", isOn: $store.imageGenConfig.enabled)
                TextField("接口地址（…/v1）", text: $store.imageGenConfig.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("模型（如 flux2 / seedream）", text: $store.imageGenConfig.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("生图 Key", text: $mediaImageKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("保存 Key 到本机 Keychain") {
                    do {
                        let trimmed = mediaImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            MediaAPIKeyStore.delete(.image)
                        } else {
                            try MediaAPIKeyStore.save(.image, value: trimmed)
                        }
                        store.imageGenTestState = nil
                    } catch {
                        store.lastError = error.localizedDescription
                    }
                }
                Button {
                    store.testImageGeneration()
                } label: {
                    HStack {
                        Text("测试生图")
                        Spacer()
                        switch store.imageGenTestState {
                        case nil: EmptyView()
                        case .testing: ProgressView()
                        case .ok(let reply): Text(reply).foregroundStyle(.green).lineLimit(1)
                        case .fail(let reason): Text(reason).foregroundStyle(.red).lineLimit(2)
                        }
                    }
                }
                .disabled(store.imageGenTestState == .testing)
                }
            } header: {
                collapseHeader("生图模型（OpenAI 兼容）", isExpanded: imageModelExpanded) {
                    withAnimation(.easeInOut(duration: 0.2)) { imageModelExpanded.toggle() }
                }
            } footer: {
                if imageModelExpanded {
                Text("按 images/generations 格式请求；测试会真实生成一张图。Key 只存本机 Keychain。")
                }
            }

            Section {
                if videoModelExpanded {
                Toggle("启用视频模型", isOn: $store.videoGenConfig.enabled)
                TextField("接口地址（…/v1）", text: $store.videoGenConfig.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("模型（如 minimax-h3）", text: $store.videoGenConfig.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("视频 Key", text: $mediaVideoKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("保存 Key 到本机 Keychain") {
                    do {
                        let trimmed = mediaVideoKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            MediaAPIKeyStore.delete(.video)
                        } else {
                            try MediaAPIKeyStore.save(.video, value: trimmed)
                        }
                    } catch {
                        store.lastError = error.localizedDescription
                    }
                }
                }
            } header: {
                collapseHeader("视频模型", isExpanded: videoModelExpanded) {
                    withAnimation(.easeInOut(duration: 0.2)) { videoModelExpanded.toggle() }
                }
            } footer: {
                if videoModelExpanded {
                Text("视频接口各家差异大，先把配置存下；生成按钮随后接线。Key 只存本机 Keychain。")
                }
            }
            }

            // 用户 2026-10-11 第 7 项：**模型置顶**（模型是 agent 的核心）；
            // 字号属于外观类，挪到模型下面。
            Section {
                Picker("消息字号", selection: $store.messageFontScale) {
                    Text("较小").tag(0.85)
                    Text("标准").tag(1.0)
                    Text("较大").tag(1.18)
                    Text("最大").tag(1.4)
                }
                .pickerStyle(.segmented)
                Text("这是消息正文的字号预览。")
                    .font(.system(size: 15 * store.messageFontScale))
                    .foregroundStyle(.secondary)
            } header: {
                Text("文字大小")
            } footer: {
                Text("只影响对话里消息正文的字号；系统「更大文字」设置也依然有效。")
            }

            Section {
                Toggle(isOn: $store.remoteAutoConnectEnabled) {
                    HStack(spacing: 12) {
                        SettingsTile(systemImage: "power")
                        Text("启动时自动连接电脑")
                    }
                }
                // 用户 2026-10-11：原来那堆碎行（地址/状态/连接/Ping）收进二级页，
                // 主设置页只留「一行 + 开关」——照豆包那种行结构。
                NavigationLink {
                    RemoteControlDetailView()
                        .environmentObject(store)
                } label: {
                    HStack(spacing: 12) {
                        SettingsTile(systemImage: "link")
                        Text("连接设置")
                        Spacer()
                        Text(store.gateway.state.isConnected ? "已连接" : "未连接")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("远程操控电脑（可选）")
            } footer: {
                Text("可选能力：填电脑端地址后，可以远程看/用电脑端的会话与文件。不需要扫码 —— 它和电脑端只是共用一颗大脑。不填也不影响单独使用。")
            }

            Section {
                Picker("界面", selection: $store.interfaceStyle) {
                    ForEach(InterfaceStyle.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .pickerStyle(.navigationLink)

                // 主题（用户 2026-10-13：「还是没在外观那里看到主题选项」+「主题名字叫 nana」）
                NavigationLink {
                    ThemePickerView()
                        .environmentObject(store)
                } label: {
                    HStack(spacing: 12) {
                        SettingsTile(systemImage: "circle.lefthalf.filled")
                        Text("主题")
                        Spacer()
                        Text(store.theme.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("外观")
            }

            // 用户 2026-10-14：「这个删除，点我头像就可以进入个人信息编辑，然后点击头像就能换」
            // —— 设置页里的「我的头像」整块（从相册选照片 / 改用符号头像 / 16 个符号）
            //    全部删掉。头像和昵称统一在「个人信息」页里改，
            //    入口 = 抽屉底部的头像行（RootView 的 drawerBottomBar → ProfileEditView）。

            // 对话字体：用户 2026-10-13 明确「名字的字体是固定的，可选择的字体是针对对话的」。
            // 名字「Hestia」固定用 ⑫ 衬线斜体（不再可改），这里这 16 个候选改成作用于**消息正文**。
            Section {
                NavigationLink {
                    NameFontPickerView()
                        .environmentObject(store)
                } label: {
                    HStack(spacing: 12) {
                        SettingsTile(systemImage: "textformat")
                        Text("对话字体")
                        Spacer()
                        Text(store.bodyFont?.title ?? "系统默认")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("选对话正文用的字体（点一下立即生效）。名字「Hestia」的字体是固定的。")
            }
        }
        .navigationTitle("设置")
        .task {
            store.refreshDefaultConfiguration()
            // CI 截图模式：把对应状态直接摆出来（正常启动无此环境变量）
            if let shot = shotMode {
                if shot == "settings-model" { modelConfigExpanded = true }
                if shot == "settings-remote" { showRemoteDetail = true }
                if shot == "settings-font" { showNameFontPicker = true }
            }
        }
        .navigationDestination(isPresented: $showRemoteDetail) {
            RemoteControlDetailView()
                .environmentObject(store)
        }
        .navigationDestination(isPresented: $showNameFontPicker) {
            NameFontPickerView()
                .environmentObject(store)
        }
        // 用户 2026-10-14：设置页里改头像的入口删掉了 ——
        // 头像/昵称统一在「个人信息」页（抽屉底部头像行进入），所以这里不再需要相册选择器。
        .onChange(of: store.gateway.state) { _, state in
            if state.isConnected {
                store.refreshDefaultConfiguration()
            }
        }
        .alert(item: $pendingPermission) { option in
            Alert(
                title: Text("修改全局默认权限？"),
                message: Text(String(localized: "defaults.permission.confirm.body", defaultValue: "将新会话的默认权限改为“\(option.title)”。这会更新部署级设置，并同步影响 WebUI。")),
                primaryButton: .cancel(Text("取消")),
                secondaryButton: .default(Text("确认修改")) {
                    store.setDefaultPermission(option.id)
                }
            )
        }
    }
}

private struct DefaultConfigurationRow: View {
    let title: String
    let value: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct DefaultPermissionChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String

    init(_ option: GatewayPermissionOption) {
        id = option.value
        title = option.name
        description = option.description ?? option.name
    }
}

private struct AgentPresetSelectionView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pendingPreset: GatewayAgentPreset?

    private var isChangingDefault: Bool {
        store.defaultConfigurationLoadingKinds.contains("set-default")
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Agent 预设")
                        .font(.title2.bold())
                    Text("预设决定 Agent 使用的工具、提示词与能力。选择后只对新建会话生效。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

                if let error = store.agentPresetsLoadError {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                        Button("重试") { store.retryAgentPresets() }
                            .disabled(store.defaultConfigurationLoadingKinds.contains("agent-presets"))
                    }
                    .padding(.vertical, 12)
                }

                if store.defaultConfigurationLoadingKinds.contains("agent-presets") && store.agentPresets.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在读取 Agent 预设…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if store.agentPresets.isEmpty && store.agentPresetsLoadError == nil {
                    ContentUnavailableView(
                        "没有可用的 Agent 预设",
                        systemImage: "point.3.filled.connected.trianglepath.dotted",
                        description: Text("网关暂无可用预设，可下拉刷新。")
                    )
                    .padding(.vertical, 24)
                } else {
                    ForEach(store.agentPresets) { preset in
                        AgentPresetCard(
                            preset: preset,
                            isSelected: preset.id == store.agentPresetDefault,
                            isBusy: isChangingDefault
                        ) {
                            pendingPreset = preset
                        }
                    }
                }

                if store.agentPresetsAuthorable || store.agentPresetsHasDocument {
                    Label(presetCapabilityText, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Agent 预设")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            store.refreshDefaultConfiguration()
        }
        .task {
            if store.agentPresets.isEmpty {
                store.refreshDefaultConfiguration()
            }
        }
        .alert(item: $pendingPreset) { preset in
            Alert(
                title: Text("设为全局默认预设？"),
                message: Text(String(localized: "defaults.preset.confirm.body", defaultValue: "将“\(preset.displayName)”设为新会话的默认 Agent 预设。这会更新部署级设置，并同步影响 WebUI。")),
                primaryButton: .cancel(Text("取消")),
                secondaryButton: .default(Text("设为默认")) {
                    store.setDefaultAgentPreset(preset.id)
                }
            )
        }
    }

    private var presetCapabilityText: String {
        switch (store.agentPresetsAuthorable, store.agentPresetsHasDocument) {
        case (true, true): return String(localized: "服务端支持编写自定义预设，并提供预设配置文档。")
        case (true, false): return String(localized: "服务端支持编写自定义 Agent 预设。")
        case (false, true): return String(localized: "服务端提供 Agent 预设配置文档。")
        case (false, false): return ""
        }
    }
}

private struct AgentPresetCard: View {
    let preset: GatewayAgentPreset
    let isSelected: Bool
    let isBusy: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(preset.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(preset.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.1), in: Capsule())
                    Spacer()
                    if isSelected {
                        Text("当前使用")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black, in: Capsule())
                    }
                }

                Text(preset.displayDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if preset.broken == true {
                    Label("该预设存在配置错误，暂时不能设为默认值", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.primary : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isSelected && !isBusy && preset.broken != true)
        .opacity(preset.broken == true ? 0.68 : 1)
    }
}

private struct DefaultModelSelectionView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pendingChange: PendingDefaultModelChange?

    private var isBusy: Bool {
        store.defaultConfigurationLoadingKinds.contains("save-default-model")
    }
    private var modelGroups: [GatewayModelGroup] {
        store.anyModelCatalog?.groups ?? []
    }
    private var isLoadingCatalog: Bool {
        store.sessionControlLoadingKinds.contains("models") && modelGroups.isEmpty
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("默认模型")
                        .font(.title2.bold())
                    Text("为之后新建的会话设置默认模型与思考等级。这会更新部署级设置，同步影响 WebUI，运行中的会话保持启动时的配置。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

                if isLoadingCatalog {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在读取模型列表…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if modelGroups.isEmpty {
                    ContentUnavailableView(
                        "暂无可用模型",
                        systemImage: "cpu",
                        description: Text("未能读取到模型列表，请检查网关连接后下拉重试。")
                    )
                    .padding(.vertical, 24)
                } else {
                    ForEach(modelGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(group.models) { model in
                                DefaultModelCard(
                                    group: group,
                                    model: model,
                                    isSelected: isDefault(group: group, model: model),
                                    currentEffort: store.defaultModelSelection?.reasoningEffort,
                                    isBusy: isBusy,
                                    onSelectModel: { select(group: group, model: model) },
                                    onSelectEffort: { effort in selectEffort(effort, group: group, model: model) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("默认模型")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            store.ensureModelCatalogForDefaults()
        }
        .task {
            store.ensureModelCatalogForDefaults()
        }
        .alert(item: $pendingChange) { change in
            Alert(
                title: Text("修改默认模型？"),
                message: Text(String(localized: "defaults.model.confirm.body", defaultValue: "将新会话的默认模型改为“\(change.summary)”。这会更新部署级设置，并同步影响 WebUI。")),
                primaryButton: .cancel(Text("取消")),
                secondaryButton: .default(Text("确认修改")) {
                    store.saveDefaultModel(provider: change.provider, model: change.model, reasoningEffort: change.reasoningEffort)
                }
            )
        }
    }

    private func isDefault(group: GatewayModelGroup, model: GatewayModelItem) -> Bool {
        store.defaultModelSelection?.provider == group.id && store.defaultModelSelection?.model == model.id
    }

    private func select(group: GatewayModelGroup, model: GatewayModelItem) {
        let efforts = model.reasoning?.efforts ?? []
        let retainedEffort = store.defaultModelSelection?.reasoningEffort.flatMap { current in
            efforts.contains(where: { $0.id == current }) ? current : nil
        }
        let effortId = retainedEffort ?? model.reasoning?.defaultEffort
        pendingChange = PendingDefaultModelChange(
            provider: group.id,
            providerName: group.name,
            model: model.id,
            modelName: model.name,
            reasoningEffort: effortId,
            effortName: effortId.flatMap { id in efforts.first(where: { $0.id == id })?.name }
        )
    }

    private func selectEffort(_ effort: GatewayReasoningEffort, group: GatewayModelGroup, model: GatewayModelItem) {
        pendingChange = PendingDefaultModelChange(
            provider: group.id,
            providerName: group.name,
            model: model.id,
            modelName: model.name,
            reasoningEffort: effort.id,
            effortName: effort.name
        )
    }
}

private struct PendingDefaultModelChange: Identifiable {
    let id = UUID()
    let provider: String
    let providerName: String
    let model: String
    let modelName: String
    let reasoningEffort: String?
    let effortName: String?

    var summary: String {
        var text = "\(providerName) · \(modelName)"
        if let effortName { text += " · \(effortName)" }
        return text
    }
}

private struct DefaultModelCard: View {
    let group: GatewayModelGroup
    let model: GatewayModelItem
    let isSelected: Bool
    let currentEffort: String?
    let isBusy: Bool
    let onSelectModel: () -> Void
    let onSelectEffort: (GatewayReasoningEffort) -> Void

    private var efforts: [GatewayReasoningEffort] { model.reasoning?.efforts ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Text("当前使用")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black, in: Capsule())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !isBusy { onSelectModel() } }

            if !efforts.isEmpty {
                HStack(spacing: 8) {
                    Text("思考等级")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(efforts) { effort in
                        let isCurrentEffort = isSelected && effort.id == currentEffort
                        Button {
                            onSelectEffort(effort)
                        } label: {
                            Text(effort.name)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isCurrentEffort ? Color.primary : Color.secondary.opacity(0.12), in: Capsule())
                                .foregroundStyle(isCurrentEffort ? Color(uiColor: .systemBackground) : .primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.primary : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.5 : 1)
        }
        .opacity(isBusy ? 0.7 : 1)
    }
}

// MARK: - 主题二级页（用户 2026-10-13：外观里要有主题选项，主题名 = nana）

struct ThemePickerView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            ForEach(HestiaTheme.allCases) { theme in
                Button {
                    store.themeID = theme.rawValue
                } label: {
                    HStack(spacing: 12) {
                        // 主题色板预览：纸白 / 墨黑 / 一记赤红
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.paper)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.ink)
                                    .frame(width: 22, height: 22)
                                Circle()
                                    .fill(theme.red)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(theme.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.themeID == theme.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("主题")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 对话字体二级页（用户 2026-10-13：名字固定、可选的是「对话」字体）

struct NameFontPickerView: View {
    @EnvironmentObject private var store: AppStore

    /// 预览用的句子：用**对话正文**的口吻，而不是「Hestia」——
    /// 因为这 16 个候选现在的落点是消息正文。
    private let sample = "今天要做什么？"

    var body: some View {
        List {
            // 首行「系统默认」= 不套自定义字体（bodyFontID 置空）
            Button {
                store.bodyFontID = ""
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sample)
                            .font(.system(size: 17))
                            .foregroundStyle(.primary)
                        Text("系统默认")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.bodyFontID.isEmpty {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .buttonStyle(.plain)

            ForEach(HestiaNameFont.allCases) { font in
                Button {
                    store.bodyFontID = font.rawValue
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sample)
                                .font(font.font(size: 17))
                                .tracking(font.tracking * 0.6)
                                .foregroundStyle(.primary)
                            Text(font.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.bodyFontID == font.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("对话字体")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 豆包式设置行的图标块 + 远程连接二级页（用户 2026-10-11）

/// 圆角方形图标块：黑底白符号（深色模式自动反相），34×34、圆角 10。
/// 照豆包那种行结构 —— 每行最左边一个彩色/黑白图标块。
struct SettingsTile: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: ZhuTheme.radiusTile, style: .continuous)
                    .fill(Color.primary)
            )
    }
}

/// 「连接设置」二级页：地址 / 状态 / 连接 / Ping —— 从主设置页收进来的细节。
struct RemoteControlDetailView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section {
                TextField("ws://host:3081/ws/mobile", text: $store.endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                HStack {
                    ConnectionDot(state: store.gateway.state)
                    Text(store.gateway.state.label)
                    Spacer()
                    if let port = store.gateway.serverPort {
                        Text("Port \(port)").foregroundStyle(.secondary)
                    }
                }
                Button(store.gateway.state.isConnected
                       ? String(localized: "断开连接")
                       : String(localized: "连接")) {
                    if store.gateway.state.isConnected {
                        store.gateway.disconnect()
                    } else {
                        store.connect()
                    }
                }
                Button("Ping 网关") { store.gateway.ping() }
            } header: {
                Text("电脑端地址")
            } footer: {
                Text("填电脑端网关地址后可以远程用电脑端的会话与文件；和电脑端只是共用一颗大脑，不需要扫码。")
            }
        }
        .navigationTitle("连接设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
