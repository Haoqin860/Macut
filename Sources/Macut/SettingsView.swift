import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var model: AppModel
    var changeShortcut: (Shortcut) -> Bool
    @State private var recording = false
    @State private var shortcutError: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmClear = false

    var body: some View {
        TabView {
            general.tabItem { Label("通用", systemImage: "slider.horizontal.3") }
            storage.tabItem { Label("历史记录", systemImage: "clock.arrow.circlepath") }
            privacy.tabItem { Label("隐私", systemImage: "hand.raised") }
        }
        .padding(18).frame(width: 550, height: 460)
        .tint(MacutStyle.accent)
        .preferredColorScheme(preferences.appearance == "light" ? .light : preferences.appearance == "dark" ? .dark : nil)
        .onDisappear { model.applyRetention() }
        .alert("清空历史记录？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { model.clearHistory() }
        } message: { Text("删除所有未收藏的记录和图片文件。已收藏的内容会保留。") }
    }

    private var general: some View {
        Form {
            Section {
                HStack {
                    Text("呼出面板")
                    Spacer()
                    Button(recording ? "请按下快捷键…" : preferences.shortcut.label) {
                        recording.toggle(); shortcutError = nil
                    }.frame(minWidth: 125)
                    if preferences.shortcut != .standard {
                        Button("恢复默认") { applyShortcut(.standard) }.font(.caption)
                    }
                }
                if recording {
                    Text("按住 ⌘、⌥ 或 ⌃ 再按一个键；Esc 取消。")
                        .font(.caption).foregroundStyle(.secondary)
                    KeyRecorder(isRecording: recording) { shortcut in
                        recording = false
                        if let shortcut { applyShortcut(shortcut) }
                    }.frame(width: 1, height: 1)
                }
                if let shortcutError { Text(shortcutError).font(.caption).foregroundStyle(.red) }
                Toggle("登录时启动 Macut", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                            loginError = SMAppService.mainApp.status == .requiresApproval ? "请在系统设置 → 通用 → 登录项中允许 Macut。" : nil
                        } catch {
                            loginError = "未能更新登录项：\(error.localizedDescription)"
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.secondary) }
            } header: { Text("随时呼出") }

            Section {
                Toggle("选中后自动粘贴到原应用", isOn: $preferences.autoPaste)
                Toggle("显示右侧预览", isOn: $preferences.showPreview)
                Picker("外观", selection: $preferences.appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            } header: { Text("使用体验") }

            Text("⌘1–9 快速使用前九条  ·  ⌘P 收藏  ·  ⌘⌫ 删除\n空搜索时按空格放大图片，Tab 切换分类。")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(5)
        }.formStyle(.grouped)
    }

    private var storage: some View {
        Form {
            Section {
                LabeledContent("已保存", value: "\(model.records.count) 条 · \(ByteCountFormatter.string(fromByteCount: Int64(model.totalBytes), countStyle: .file))")
                Picker("普通历史上限", selection: $preferences.historyLimit) {
                    ForEach([100, 300, 500, 1000, 3000], id: \.self) { Text("\($0) 条").tag($0) }
                }.onChange(of: preferences.historyLimit) { model.applyRetention() }
                Picker("未使用记录保留", selection: $preferences.retentionDays) {
                    Text("7 天").tag(7)
                    Text("30 天").tag(30)
                    Text("90 天").tag(90)
                    Text("不限时间").tag(0)
                }.onChange(of: preferences.retentionDays) { model.applyRetention() }
                Picker("内容容量上限", selection: $preferences.maxStorageMB) {
                    Text("128 MB").tag(128)
                    Text("512 MB").tag(512)
                    Text("1 GB").tag(1024)
                    Text("2 GB").tag(2048)
                }.onChange(of: preferences.maxStorageMB) { model.applyRetention() }
            } header: { Text("自动整理") }

            Section {
                Text("收藏始终保留；收藏内容占用容量超过上限时，不再保留新的普通历史。单次超过 64 MB 的复制会跳过记录。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("打开存储文件夹") { NSWorkspace.shared.open(model.dataDirectory) }
                    Spacer()
                    Button("清空普通历史…", role: .destructive) { confirmClear = true }
                }
            }
        }.formStyle(.grouped)
    }

    private var privacy: some View {
        Form {
            Section {
                Label("剪贴板内容只保存在这台 Mac", systemImage: "internaldrive")
                Text("无账号、无云同步、无遥测。自动跳过带有密码或临时标记的剪贴板内容；未标记的敏感文字仍可能被记录。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("暂停记录新内容", isOn: $model.paused)
            } header: { Text("本地保存") }

            Section {
                HStack {
                    Label(model.accessibilityGranted ? "辅助功能已授权" : "辅助功能未授权",
                          systemImage: model.accessibilityGranted ? "checkmark.circle.fill" : "keyboard")
                    Spacer()
                    Button("前往授权") { model.requestAccessibility() }
                }
                Text("授权用于把选中内容自动粘贴回原应用。呼出面板与记录历史不依赖这项授权。")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("自动粘贴") }

            Section {
                TextEditor(text: $preferences.excludedApps)
                    .font(.system(size: 11, design: .monospaced)).frame(height: 66)
                HStack {
                    Text("每行一个应用 Bundle ID").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("选择应用…") { chooseExcludedApp() }
                }
            } header: { Text("不记录这些应用") }
        }.formStyle(.grouped)
    }

    private func applyShortcut(_ shortcut: Shortcut) {
        if shortcut == preferences.shortcut { return }
        if changeShortcut(shortcut) { shortcutError = nil }
        else { shortcutError = "这个快捷键无法注册，原快捷键仍然可用。请换一个组合。" }
    }

    private func chooseExcludedApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "排除此应用"
        if panel.runModal() == .OK {
            var excluded = preferences.excludedBundleIDs
            for url in panel.urls {
                if let id = Bundle(url: url)?.bundleIdentifier { excluded.insert(id) }
            }
            preferences.excludedApps = excluded.sorted().joined(separator: "\n")
        }
    }
}
