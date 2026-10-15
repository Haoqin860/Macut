import AppKit
import ClipboardCore

enum DemoData {
    static func seed(at directory: URL) throws {
        let store = try HistoryStore(directory: directory)
        let samples = [
            ("一段好用的文字，值得随时找回。", "一段好用的文字，值得随时找回。\n\n把常用回复、灵感和临时笔记留在这里。复制之后，按快捷键就能再次找到。", "备忘录", "com.apple.Notes"),
            ("https://developer.apple.com/design/", "https://developer.apple.com/design/", "Safari", "com.apple.Safari"),
            ("设计里的分寸感", "设计里的分寸感\n\n让信息清楚，让动作顺手。\n留白是为了看清内容，动画是为了理解变化。\n\nMacut · 随手复制，随时找回", "文本编辑", "com.apple.TextEdit")
        ]
        for (index, sample) in samples.enumerated() {
            let capture = CapturedClip(kind: index == 1 ? .link : .text, title: sample.0, text: sample.1,
                                       sourceName: sample.2, sourceBundleID: sample.3,
                                       items: [[.init(type: "public.utf8-plain-text", data: Data(sample.1.utf8))]])
            try store.add(capture, now: Date().addingTimeInterval(-Double(600 + index * 900)))
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"), let data = try? Data(contentsOf: url) {
            let capture = CapturedClip(kind: .image, title: "Macut 图标设计.png", text: "",
                                       sourceName: "预览", sourceBundleID: "com.apple.Preview",
                                       items: [[.init(type: "public.png", data: data)]])
            try store.add(capture)
        }
    }
}
