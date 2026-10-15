import Foundation

public enum ClipKind: String, Codable, CaseIterable {
    case text, link, image, files
}

public struct ClipRepresentation: Codable, Equatable {
    public let type: String
    public let fileName: String
}

public struct ClipRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let kind: ClipKind
    public let title: String
    public let text: String
    public let sourceName: String
    public let sourceBundleID: String?
    public let capturedAt: Date
    public var lastUsedAt: Date
    public var isFavorite: Bool
    public let fingerprint: String
    public let items: [[ClipRepresentation]]
    public let byteCount: Int
    public var thumbnailName: String?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var imageByteCount: Int?
    public var previewName: String?

    /// An image file can retain its file-reference paste semantics while displaying as an image.
    public var hasImagePreview: Bool { kind == .image || thumbnailName != nil }

    public func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        let content = "\(title)\n\(text)\n\(sourceName)"
        return terms.allSatisfy { content.localizedStandardContains(String($0)) }
    }
}

public struct CapturedRepresentation {
    public let type: String
    public let data: Data

    public init(type: String, data: Data) {
        self.type = type
        self.data = data
    }
}

public struct CapturedClip {
    public let kind: ClipKind
    public let title: String
    public let text: String
    public let sourceName: String
    public let sourceBundleID: String?
    public let items: [[CapturedRepresentation]]

    public init(kind: ClipKind, title: String, text: String, sourceName: String,
                sourceBundleID: String?, items: [[CapturedRepresentation]]) {
        self.kind = kind
        self.title = title
        self.text = text
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.items = items
    }
}
