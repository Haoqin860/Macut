import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// All access is serialized by the caller. Payloads live separately from searchable metadata.
public final class HistoryStore {
    public private(set) var records: [ClipRecord] = []
    public let directory: URL
    private let fm = FileManager.default
    private var indexURL: URL { directory.appendingPathComponent("history.json") }
    private var blobsURL: URL { directory.appendingPathComponent("Blobs", isDirectory: true) }

    public init(directory: URL) throws {
        self.directory = directory
        try fm.createDirectory(at: blobsURL, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        if fm.fileExists(atPath: indexURL.path) {
            records = try JSONDecoder().decode([ClipRecord].self, from: Data(contentsOf: indexURL))
        }
        // Interrupted writes can leave unreferenced payload folders; the index is authoritative.
        let known = Set(records.map { $0.id.uuidString })
        for url in try fm.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil) {
            if !known.contains(url.lastPathComponent) { try? fm.removeItem(at: url) }
        }
    }

    public func payloadURL(for record: ClipRecord, fileName: String) -> URL {
        blobsURL.appendingPathComponent(record.id.uuidString).appendingPathComponent(fileName)
    }

    @discardableResult
    public func add(_ capture: CapturedClip, now: Date = Date()) throws -> ClipRecord {
        var digest = SHA256()
        for (index, item) in capture.items.enumerated() {
            digest.update(data: Data("item:\(index)".utf8))
            for rep in item.sorted(by: { $0.type < $1.type }) {
                digest.update(data: Data("\(rep.type.utf8.count):\(rep.type):\(rep.data.count):".utf8))
                digest.update(data: rep.data)
            }
        }
        let fingerprint = digest.finalize().map { String(format: "%02x", $0) }.joined()
        if let index = records.firstIndex(where: { $0.fingerprint == fingerprint }) {
            var updated = records
            updated[index].lastUsedAt = now
            if capture.kind == .files, let source = imageFileSource(for: updated[index]) {
                let folder = blobsURL.appendingPathComponent(updated[index].id.uuidString)
                makeThumbnail(source, record: &updated[index], folder: folder)
            }
            try commit(updated)
            return records[index]
        }
        let id = UUID()
        let folder = blobsURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        do {
            var size = 0
            var stored: [[ClipRepresentation]] = []
            for (itemIndex, item) in capture.items.enumerated() {
                var representations: [ClipRepresentation] = []
                for (repIndex, rep) in item.enumerated() {
                    let name = "\(itemIndex)-\(repIndex).data"
                    try rep.data.write(to: folder.appendingPathComponent(name), options: .atomic)
                    size += rep.data.count
                    representations.append(ClipRepresentation(type: rep.type, fileName: name))
                }
                stored.append(representations)
            }
            var record = ClipRecord(id: id, kind: capture.kind, title: capture.title,
                                    text: capture.text, sourceName: capture.sourceName,
                                    sourceBundleID: capture.sourceBundleID, capturedAt: now,
                                    lastUsedAt: now, isFavorite: false, fingerprint: fingerprint,
                                    items: stored, byteCount: size)
            if capture.kind == .image,
               let image = capture.items.flatMap({ $0 }).first(where: {
                   $0.type == "public.png" || $0.type == "public.tiff"
               }) {
                makeThumbnail(image.data, record: &record, folder: folder)
            } else if capture.kind == .files, let source = imageFileSource(for: record) {
                makeThumbnail(source, record: &record, folder: folder)
            }
            try commit(records + [record])
            return record
        } catch {
            try? fm.removeItem(at: folder)
            throw error
        }
    }

    public func setFavorite(_ id: UUID, value: Bool) throws {
        var updated = records
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[index].isFavorite = value
        try commit(updated)
    }

    /// Repairs earlier file-only entries without altering their IDs, favorites or paste payloads.
    public func restoreImageFilePreviews() throws {
        var updated = records
        var changed = false
        for index in updated.indices where updated[index].kind == .files && updated[index].thumbnailName == nil {
            guard let source = imageFileSource(for: updated[index]) else { continue }
            let folder = blobsURL.appendingPathComponent(updated[index].id.uuidString)
            makeThumbnail(source, record: &updated[index], folder: folder)
            changed = changed || updated[index].thumbnailName != nil
        }
        if changed { try commit(updated) }
    }

    public func restoreImageFilePreview(_ id: UUID, authorizedURL: URL) throws {
        guard let index = records.firstIndex(where: { $0.id == id }),
              let original = imageFileURL(for: records[index]),
              original.standardizedFileURL == authorizedURL.standardizedFileURL,
              let source = CGImageSourceCreateWithURL(authorizedURL as CFURL, nil) else {
            throw CocoaError(.fileReadNoPermission)
        }
        var updated = records
        let folder = blobsURL.appendingPathComponent(id.uuidString)
        makeThumbnail(source, record: &updated[index], folder: folder)
        guard updated[index].thumbnailName != nil else { throw CocoaError(.fileReadCorruptFile) }
        try commit(updated)
    }

    public func imageFileURL(for record: ClipRecord) -> URL? {
        let refs = record.items.flatMap { $0 }.filter { $0.type == "public.file-url" }
        guard refs.count == 1,
              let data = try? Data(contentsOf: payloadURL(for: record, fileName: refs[0].fileName)),
              let value = String(data: data, encoding: .utf8),
              let url = URL(string: value), url.isFileURL,
              url.host == nil || url.host == "" || url.host == "localhost" else { return nil }
        return url
    }

    private func imageFileSource(for record: ClipRecord) -> CGImageSource? {
        guard let url = imageFileURL(for: record),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, let size = values.fileSize,
              size > 0, size <= 64 * 1024 * 1024 else { return nil }
        // ImageIO probes bytes, so extensionless image cache files also work.
        return CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
    }

    public func touch(_ id: UUID) throws {
        var updated = records
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[index].lastUsedAt = Date()
        try commit(updated)
    }

    public func remove(_ ids: Set<UUID>) throws {
        let deleted = records.filter { ids.contains($0.id) }
        try commit(records.filter { !ids.contains($0.id) })
        for record in deleted {
            try? fm.removeItem(at: blobsURL.appendingPathComponent(record.id.uuidString))
        }
    }

    public func prune(limit: Int, maxBytes: Int, retentionDays: Int, now: Date = Date()) throws {
        let ordered = records.sorted { $0.lastUsedAt > $1.lastUsedAt }
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86400)
        var count = 0
        // Favorites are protected but count toward the total storage budget.
        var bytes = ordered.filter(\.isFavorite).reduce(0) { $0 + $1.byteCount }
        var removeIDs = Set<UUID>()
        for record in ordered where !record.isFavorite {
            if count >= limit || bytes + record.byteCount > maxBytes ||
                (retentionDays > 0 && record.lastUsedAt < cutoff) {
                removeIDs.insert(record.id)
            } else {
                count += 1
                bytes += record.byteCount
            }
        }
        if !removeIDs.isEmpty { try remove(removeIDs) }
    }

    private func commit(_ updated: [ClipRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(updated).write(to: indexURL, options: .atomic)
        records = updated
    }

    private func makeThumbnail(_ data: Data, record: inout ClipRecord, folder: URL) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        makeThumbnail(source, record: &record, folder: folder)
    }

    private func makeThumbnail(_ source: CGImageSource, record: inout ClipRecord, folder: URL) {
        guard let type = CGImageSourceGetType(source),
              UTType(type as String)?.conforms(to: .image) == true else { return }
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            record.pixelWidth = props[kCGImagePropertyPixelWidth] as? Int
            record.pixelHeight = props[kCGImagePropertyPixelHeight] as? Int
        }
        if record.kind == .files, let url = imageFileURL(for: record),
           let values = try? url.resourceValues(forKeys: [.fileSizeKey]) {
            record.imageByteCount = values.fileSize
        }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceThumbnailMaxPixelSize: 640,
                                      kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let dest = CGImageDestinationCreateWithURL(folder.appendingPathComponent("thumbnail.png") as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        if CGImageDestinationFinalize(dest) { record.thumbnailName = "thumbnail.png" }
        if record.kind == .files {
            var largeOptions = options
            largeOptions[kCGImageSourceThumbnailMaxPixelSize] = 1800
            if let large = CGImageSourceCreateThumbnailAtIndex(source, 0, largeOptions as CFDictionary),
               let output = CGImageDestinationCreateWithURL(folder.appendingPathComponent("image-preview.png") as CFURL,
                                                            UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(output, large, nil)
                if CGImageDestinationFinalize(output) { record.previewName = "image-preview.png" }
            }
        }
    }
}
