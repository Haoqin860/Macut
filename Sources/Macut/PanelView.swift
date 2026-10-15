import AppKit
import ClipboardCore
import SwiftUI

enum MacutStyle {
    static let accent = Color(red: 0.16, green: 0.49, blue: 0.47)
    static let muted = Color.secondary
}

struct PanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            search
            filters
            Divider().opacity(0.65)
            if let error = model.storageError {
                ContentUnavailableView("历史记录暂不可用", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(error))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.isLoading {
                ProgressView("正在读取历史…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.visibleRecords.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    historyList
                        .frame(width: preferences.showPreview ? 360 : nil)
                    if preferences.showPreview {
                        Divider().opacity(0.6)
                        DetailPreview(model: model, record: model.selectedRecord)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            if let message = model.message {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(MacutStyle.accent)
                    Text(message).font(.system(size: 12)).lineLimit(2)
                    Spacer(minLength: 0)
                    Button { model.message = nil } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                        .buttonStyle(.plain).accessibilityLabel("关闭提示")
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(MacutStyle.accent.opacity(0.08))
            }
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        .tint(MacutStyle.accent)
        .preferredColorScheme(preferences.appearance == "light" ? .light : preferences.appearance == "dark" ? .dark : nil)
        .onAppear { searchFocused = true; model.loadPreview(model.selectedRecord) }
        .onChange(of: model.panelSession) { searchFocused = true }
        .onChange(of: model.query) { model.normalizeSelection() }
        .onChange(of: model.filter) { model.normalizeSelection() }
        .onChange(of: model.selectedID) { model.loadPreview(model.selectedRecord) }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "square.on.square")
                .font(.system(size: 16, weight: .medium)).foregroundStyle(MacutStyle.accent)
            Text("Macut").font(.system(size: 14, weight: .semibold))
            Text("随手复制，随时找回").font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            if model.paused {
                Label("已暂停", systemImage: "pause.circle.fill").font(.system(size: 11)).foregroundStyle(.orange)
            }
            Text(preferences.shortcut.label)
                .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
            Menu {
                Button(model.paused ? "继续记录" : "暂停记录") { model.paused.toggle() }
                Button(preferences.showPreview ? "收起预览" : "展开预览") {
                    preferences.showPreview.toggle()
                }
                Divider()
                Button("设置…") { model.onSettingsRequested?() }
                Button("退出 Macut") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 14))
                    .frame(width: 26, height: 24).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("更多操作")
        }
        .padding(.horizontal, 21).padding(.top, 17).padding(.bottom, 14)
    }

    private var search: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .regular)).foregroundStyle(.secondary)
            TextField("搜索文字、链接或来源应用…", text: $model.query)
                .textFieldStyle(.plain).font(.system(size: 17))
                .focused($searchFocused)
                .accessibilityIdentifier("clipboard-search")
            if !model.query.isEmpty {
                Button { model.query = ""; searchFocused = true } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }.buttonStyle(.plain).accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 15).frame(height: 49)
        .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.primary.opacity(0.07)))
        .padding(.horizontal, 18)
    }

    private var filters: some View {
        HStack(spacing: 5) {
            ForEach(ClipFilter.allCases, id: \.self) { filter in
                Button {
                    model.filter = filter
                    searchFocused = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: filter.symbol).font(.system(size: 11))
                        Text(filter.rawValue).font(.system(size: 12, weight: model.filter == filter ? .semibold : .regular))
                    }
                    .foregroundStyle(model.filter == filter ? MacutStyle.accent : Color.secondary)
                    .padding(.horizontal, 12).frame(height: 29)
                    .background(model.filter == filter ? MacutStyle.accent.opacity(0.11) : .clear, in: Capsule())
                    .contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(model.filter == filter ? .isSelected : [])
            }
            Spacer(minLength: 0)
            Text("\(model.visibleRecords.count) 条")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(model.visibleRecords) { record in
                        HistoryRow(model: model, record: record, selected: model.selectedID == record.id)
                            .id(record.id)
                            .onTapGesture(count: 2) {
                                model.selectedID = record.id
                                model.pasteSelected()
                            }
                            .onTapGesture { model.selectedID = record.id; searchFocused = true }
                            .contextMenu {
                                Button("粘贴") { model.onPasteRequested?(record, false) }
                                if record.kind == .text || record.kind == .link {
                                    Button("粘贴为纯文本") { model.onPasteRequested?(record, true) }
                                }
                                Button(record.isFavorite ? "取消收藏" : "收藏") { model.toggleFavorite(record) }
                                Divider()
                                Button("删除", role: .destructive) { model.delete(record) }
                            }
                    }
                }.padding(9)
            }
            .onChange(of: model.selectedID) { _, id in
                if let id { proxy.scrollTo(id, anchor: nil) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: model.query.isEmpty ? (model.filter == .favorite ? "star" : "square.on.square") : "magnifyingglass")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(MacutStyle.accent.opacity(0.7))
                .frame(width: 78, height: 78)
                .background(MacutStyle.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
            Text(emptyTitle).font(.system(size: 17, weight: .medium))
            Text(emptyDescription).font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(5)
            if model.query.isEmpty && model.filter == .all {
                HStack(spacing: 7) {
                    KeyCap(text: "⌘C")
                    Text("复制内容").font(.system(size: 11)).foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                    KeyCap(text: preferences.shortcut.label)
                    Text("随时找回").font(.system(size: 11)).foregroundStyle(.secondary)
                }.padding(.top, 5)
            }
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        if !model.query.isEmpty { return "没有找到匹配的内容" }
        if model.filter == .favorite { return "把常用内容留在这里" }
        if model.filter == .image { return "复制一张图片试试" }
        return "你的下一次复制，会留在这里"
    }

    private var emptyDescription: String {
        if !model.query.isEmpty { return "试试更短的关键词，或切换内容类型。" }
        if model.filter == .favorite { return "点击记录旁的星标，收藏常用文字和图片。" }
        return "文字、图片和链接，自动保存在这台 Mac。\n按 Esc 收起，需要时再呼出。"
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.6)
            HStack(spacing: 13) {
                HStack(spacing: 5) { KeyCap(text: "↑↓"); Text("选择") }
                HStack(spacing: 5) { KeyCap(text: "↩"); Text(preferences.autoPaste && model.accessibilityGranted ? "粘贴" : "复制") }
                if preferences.showPreview {
                    HStack(spacing: 5) { KeyCap(text: "⌘↩"); Text("纯文本") }
                        .opacity(model.selectedRecord?.kind == .image || model.selectedRecord?.kind == .files ? 0.35 : 1)
                }
                Spacer(minLength: 0)
                if !model.accessibilityGranted && preferences.autoPaste {
                    Button("启用自动粘贴") { model.requestAccessibility() }
                        .buttonStyle(.plain).foregroundStyle(MacutStyle.accent)
                }
                Button { model.onSettingsRequested?() } label: {
                    Image(systemName: "gearshape").font(.system(size: 13))
                }.buttonStyle(.plain).help("设置（⌘,）").accessibilityLabel("设置")
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
            .padding(.horizontal, 19).frame(height: 43)
        }
    }
}

struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 5).frame(height: 19)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.09)))
    }
}

struct HistoryRow: View {
    @ObservedObject var model: AppModel
    let record: ClipRecord
    let selected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail
                .frame(width: 45, height: 45)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text(record.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    .foregroundStyle(.primary)
                if record.kind == .text && record.text.contains("\n") {
                    Text(record.text.split(separator: "\n").dropFirst().joined(separator: " "))
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 4) {
                    SourceIcon(bundleID: record.sourceBundleID).frame(width: 12, height: 12)
                    Text(record.sourceName).lineLimit(1)
                    Text("·")
                    Text(record.lastUsedAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                        .lineLimit(1)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Button { model.toggleFavorite(record) } label: {
                Image(systemName: record.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12)).foregroundStyle(record.isFavorite ? MacutStyle.accent : .secondary.opacity(0.5))
                    .frame(width: 24, height: 30).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(record.isFavorite ? "取消收藏" : "收藏")
        }
        .padding(.horizontal, 10).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? MacutStyle.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(record.title)，\(record.sourceName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var thumbnail: some View {
        if record.hasImagePreview, let image = model.thumbnail(record) {
            Image(nsImage: image).resizable().scaledToFill().frame(width: 45, height: 45).clipped()
        } else {
            Image(systemName: record.kind.symbol).font(.system(size: 21, weight: .light))
                .foregroundStyle(record.kind == .link ? Color.blue.opacity(0.75) : MacutStyle.accent.opacity(0.8))
        }
    }
}

struct SourceIcon: View {
    let bundleID: String?
    private static var cache: [String: NSImage] = [:]
    private var icon: NSImage? {
        guard let bundleID else { return nil }
        if let cached = Self.cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        Self.cache[bundleID] = image
        return image
    }
    var body: some View {
        if let icon { Image(nsImage: icon).resizable().scaledToFit().accessibilityHidden(true) }
        else { Image(systemName: "app").resizable().scaledToFit().foregroundStyle(.tertiary).accessibilityHidden(true) }
    }
}

extension ClipKind {
    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .files: return "doc"
        }
    }
    var label: String {
        switch self {
        case .text: return "文字"
        case .link: return "链接"
        case .image: return "图片"
        case .files: return "文件"
        }
    }
}

struct DetailPreview: View {
    @ObservedObject var model: AppModel
    let record: ClipRecord?

    var body: some View {
        if let record {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(record.kind == .files && record.hasImagePreview ? "图片文件" : record.kind.label,
                          systemImage: record.hasImagePreview ? "photo" : record.kind.symbol)
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.toggleFavorite(record) } label: {
                        Image(systemName: record.isFavorite ? "star.fill" : "star")
                    }.help("收藏（⌘P）").accessibilityLabel("收藏此条内容")
                    Button { model.onPasteRequested?(record, false) } label: {
                        Image(systemName: "doc.on.doc")
                    }.help("使用此条内容（↩）").accessibilityLabel("使用此条内容")
                }
                .buttonStyle(.borderless).font(.system(size: 13))
                .padding(.horizontal, 20).frame(height: 48)
                if record.hasImagePreview {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11).fill(.primary.opacity(0.025))
                        if let image = model.previewImage {
                            Image(nsImage: image).resizable().scaledToFit().padding(8)
                        } else if model.previewLoading { ProgressView() }
                        else { Label("预览不可用", systemImage: "photo.badge.exclamationmark").foregroundStyle(.secondary) }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 16)
                    .onTapGesture { model.onPreviewRequested?() }
                    .help("点击放大预览")
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        Text(record.text.isEmpty ? record.title : record.text)
                            .font(record.kind == .files ? .system(size: 12, design: .monospaced) : .system(size: 13))
                            .lineSpacing(5).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 22).padding(.bottom, 20)
                        if record.kind == .files && record.items.flatMap({ $0 }).filter({ $0.type == "public.file-url" }).count == 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("若这是图片，原文件可能受系统访问限制或已不可用。可选择原图片以生成本地预览。")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                                Button("选择原图片以允许预览…") { model.authorizeImageFilePreview(record) }
                                    .font(.system(size: 11))
                            }.padding(.horizontal, 22).padding(.bottom, 18)
                        }
                    }
                    .id(record.id)
                    Spacer(minLength: 0)
                }
                Divider().padding(.horizontal, 20).opacity(0.6)
                VStack(alignment: .leading, spacing: 7) {
                    Text(record.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    HStack(spacing: 5) {
                        SourceIcon(bundleID: record.sourceBundleID).frame(width: 12, height: 12)
                        Text(record.sourceName)
                        Text("·")
                        Text(ByteCountFormatter.string(fromByteCount: Int64(record.imageByteCount ?? record.byteCount), countStyle: .file))
                        if let width = record.pixelWidth, let height = record.pixelHeight {
                            Text("· \(width) × \(height)")
                        }
                    }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    Text(record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }.padding(20)
            }
            .background(.background.opacity(0.28))
        } else {
            Color.clear
        }
    }
}
