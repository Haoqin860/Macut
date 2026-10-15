import AppKit
import Combine

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String

    static let standard = Shortcut(keyCode: 9, modifiers: 768, label: "⌘⇧V")
}

final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var shortcut: Shortcut { didSet { save(shortcut, key: "shortcut") } }
    @Published var historyLimit: Int { didSet { defaults.set(historyLimit, forKey: "historyLimit") } }
    @Published var retentionDays: Int { didSet { defaults.set(retentionDays, forKey: "retentionDays") } }
    @Published var maxStorageMB: Int { didSet { defaults.set(maxStorageMB, forKey: "maxStorageMB") } }
    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: "autoPaste") } }
    @Published var showPreview: Bool { didSet { defaults.set(showPreview, forKey: "showPreview") } }
    @Published var excludedApps: String { didSet { defaults.set(excludedApps, forKey: "excludedApps") } }
    @Published var appearance: String { didSet { defaults.set(appearance, forKey: "appearance") } }

    var excludedBundleIDs: Set<String> {
        Set(excludedApps.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["historyLimit": 500, "retentionDays": 30, "maxStorageMB": 512,
                                     "autoPaste": true, "showPreview": true, "appearance": "system",
                                     "excludedApps": "com.1password.1password\ncom.agilebits.onepassword7\ncom.bitwarden.desktop"])
        shortcut = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .standard
        historyLimit = defaults.integer(forKey: "historyLimit")
        retentionDays = defaults.integer(forKey: "retentionDays")
        maxStorageMB = defaults.integer(forKey: "maxStorageMB")
        autoPaste = defaults.bool(forKey: "autoPaste")
        showPreview = defaults.bool(forKey: "showPreview")
        excludedApps = defaults.string(forKey: "excludedApps") ?? ""
        appearance = defaults.string(forKey: "appearance") ?? "system"
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
