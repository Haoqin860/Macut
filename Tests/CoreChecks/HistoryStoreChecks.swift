import Foundation
import ClipboardCore
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

final class HistoryStoreChecks {
    var directory: URL!
    var store: HistoryStore!

    func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("MacutTests-\(UUID())")
        store = try HistoryStore(directory: directory)
    }

    func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func capture(_ text: String, kind: ClipKind = .text, extra: [CapturedRepresentation] = []) -> CapturedClip {
        CapturedClip(kind: kind, title: String(text.prefix(80)), text: text, sourceName: "测试应用",
                     sourceBundleID: "app.macut.tests",
                     items: [[.init(type: "public.utf8-plain-text", data: Data(text.utf8))] + extra])
    }

    func testDeduplicationPreservesFavoriteAndOriginalCaptureDate() throws {
        let first = try store.add(capture("你好，Macut"), now: Date(timeIntervalSince1970: 100))
        try store.setFavorite(first.id, value: true)
        let second = try store.add(capture("你好，Macut"), now: Date(timeIntervalSince1970: 200))
        try checkEqual(first.id, second.id)
        try checkEqual(store.records.count, 1)
        try checkTrue(second.isFavorite)
        try checkEqual(second.capturedAt.timeIntervalSince1970, 100)
        try checkEqual(second.lastUsedAt.timeIntervalSince1970, 200)
    }

    func testRichRepresentationsRoundTripWithoutLosingOriginalBytes() throws {
        let html = Data("<strong>原格式</strong>".utf8)
        let record = try store.add(capture("原格式", extra: [.init(type: "public.html", data: html)]))
        let reloaded = try HistoryStore(directory: directory)
        try checkEqual(reloaded.records, [record])
        let rep = try require(record.items.first?.first(where: { $0.type == "public.html" }))
        try checkEqual(try Data(contentsOf: reloaded.payloadURL(for: record, fileName: rep.fileName)), html)
        let different = try store.add(capture("原格式", extra: [.init(type: "public.html", data: Data("<em>原格式</em>".utf8))]))
        try checkNotEqual(record.id, different.id)
    }

    func testItemBoundariesAndFileOrderArePreserved() throws {
        let first = CapturedRepresentation(type: "public.file-url", data: Data("file:///tmp/a.png".utf8))
        let second = CapturedRepresentation(type: "public.file-url", data: Data("file:///tmp/b.png".utf8))
        let capture = CapturedClip(kind: .files, title: "2 个文件", text: "/tmp/a.png\n/tmp/b.png",
                                   sourceName: "Finder", sourceBundleID: "com.apple.finder", items: [[first], [second]])
        let record = try store.add(capture)
        try checkEqual(record.items.count, 2)
        try checkEqual(try Data(contentsOf: store.payloadURL(for: record, fileName: record.items[1][0].fileName)), second.data)
    }

    func testPruningProtectsFavoritesAndKeepsNewestOrdinaryRecords() throws {
        let old = try store.add(capture("老记录"), now: Date(timeIntervalSince1970: 10))
        try store.setFavorite(old.id, value: true)
        _ = try store.add(capture("中间记录"), now: Date(timeIntervalSince1970: 20))
        let newest = try store.add(capture("最新记录"), now: Date(timeIntervalSince1970: 30))
        try store.prune(limit: 1, maxBytes: 100000, retentionDays: 0)
        try checkEqual(Set(store.records.map(\.id)), [old.id, newest.id])
    }

    func testFavoriteBytesCountTowardCapacity() throws {
        let favorite = try store.add(capture(String(repeating: "a", count: 100)))
        try store.setFavorite(favorite.id, value: true)
        _ = try store.add(capture("b"))
        try store.prune(limit: 500, maxBytes: 100, retentionDays: 0)
        try checkEqual(store.records.map(\.id), [favorite.id])
    }

    func testTimeRetentionUsesLastUsageAndDoesNotDeleteFavorites() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        _ = try store.add(capture("过期"), now: now.addingTimeInterval(-8 * 86400))
        let favorite = try store.add(capture("过期但收藏"), now: now.addingTimeInterval(-8 * 86400))
        try store.setFavorite(favorite.id, value: true)
        let fresh = try store.add(capture("新内容"), now: now)
        try store.prune(limit: 100, maxBytes: 100000, retentionDays: 7, now: now)
        try checkEqual(Set(store.records.map(\.id)), [favorite.id, fresh.id])
    }

    func testDeleteRemovesPayloadAndIndexEntry() throws {
        let record = try store.add(capture("待删除"))
        let payload = store.payloadURL(for: record, fileName: record.items[0][0].fileName)
        try checkTrue(FileManager.default.fileExists(atPath: payload.path))
        try store.remove([record.id])
        try checkFalse(FileManager.default.fileExists(atPath: payload.path))
        try checkTrue(try HistoryStore(directory: directory).records.isEmpty)
    }

    func testFailedCommitLeavesExistingHistoryAndNoOrphanedPayload() throws {
        let record = try store.add(capture("原有内容"))
        let index = directory.appendingPathComponent("history.json")
        try FileManager.default.removeItem(at: index)
        try FileManager.default.createDirectory(at: index, withIntermediateDirectories: false)
        try checkThrows(try store.add(capture("不能保存的内容")))
        try checkEqual(store.records, [record])
        let folders = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("Blobs"), includingPropertiesForKeys: nil)
        try checkEqual(folders.count, 1)
    }

    func testCorruptIndexIsReportedWithoutOverwritingIt() throws {
        let corrupted = Data("not-json".utf8)
        let index = directory.appendingPathComponent("history.json")
        try corrupted.write(to: index)
        try checkThrows(try HistoryStore(directory: directory))
        try checkEqual(try Data(contentsOf: index), corrupted)
    }

    func testSearchHandlesChineseMultipleTermsAndCase() throws {
        let record = try store.add(capture("Macut 医学研究 备忘"))
        try checkTrue(record.matches("医学 macut"))
        try checkTrue(record.matches("测试应用 备忘"))
        try checkFalse(record.matches("医学 没有的词"))
        try checkTrue(record.matches("  "))
    }

    func testImageThumbnailIsBoundedAndOriginalPayloadIsIntact() throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try require(CGContext(data: nil, width: 1600, height: 1000, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: colorSpace,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1000))
        let data = NSMutableData()
        let destination = try require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try require(context.makeImage()), nil)
        try checkTrue(CGImageDestinationFinalize(destination))
        let original = data as Data
        let capture = CapturedClip(kind: .image, title: "图片", text: "", sourceName: "测试", sourceBundleID: nil,
                                   items: [[.init(type: "public.png", data: original)]])
        let record = try store.add(capture)
        try checkEqual(record.pixelWidth, 1600)
        try checkEqual(record.pixelHeight, 1000)
        let thumbURL = store.payloadURL(for: record, fileName: try require(record.thumbnailName))
        let thumb = try require(CGImageSourceCreateWithURL(thumbURL as CFURL, nil))
        let props = try require(CGImageSourceCopyPropertiesAtIndex(thumb, 0, nil) as? [CFString: Any])
        try checkAtMost(try require(props[kCGImagePropertyPixelWidth] as? Int), 640)
        try checkEqual(try Data(contentsOf: store.payloadURL(for: record, fileName: record.items[0][0].fileName)), original)
    }

    private func makeImageFile(name: String) throws -> URL {
        let context = try require(CGContext(data: nil, width: 48, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 48, height: 32))
        let url = directory.appendingPathComponent(name)
        let destination = try require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try require(context.makeImage()), nil)
        try checkTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func fileCapture(_ urls: [URL]) -> CapturedClip {
        CapturedClip(kind: .files, title: urls.first?.lastPathComponent ?? "文件", text: urls.map(\.path).joined(separator: "\n"),
                     sourceName: "测试应用", sourceBundleID: "app.macut.tests",
                     items: urls.map { [.init(type: "public.file-url", data: Data($0.absoluteString.utf8))] })
    }

    func testCopiedImageFileGetsPreviewWithoutChangingPastePayload() throws {
        let url = try makeImageFile(name: "example image.png")
        let record = try store.add(fileCapture([url]))
        try checkEqual(record.kind, .files)
        try checkTrue(record.hasImagePreview)
        try checkEqual(record.pixelWidth, 48)
        try checkEqual(record.pixelHeight, 32)
        try checkEqual(record.items[0].map(\.type), ["public.file-url"])
        try checkEqual(try Data(contentsOf: store.payloadURL(for: record, fileName: record.items[0][0].fileName)), Data(url.absoluteString.utf8))
    }

    func testExtensionlessImageCacheFileIsRecognizedByContents() throws {
        let url = try makeImageFile(name: "opaque-cache-file")
        let record = try store.add(fileCapture([url]))
        try checkTrue(record.hasImagePreview)
        try checkEqual(record.pixelWidth, 48)
        try checkEqual(store.imageFileURL(for: record), url)
    }

    func testExistingFileHistoryBackfillsPreviewAndPreservesFavorites() throws {
        let url = try makeImageFile(name: "existing.png")
        let record = try store.add(fileCapture([url]))
        try store.setFavorite(record.id, value: true)
        let index = directory.appendingPathComponent("history.json")
        var rows = try require(JSONSerialization.jsonObject(with: Data(contentsOf: index)) as? [[String: Any]])
        rows[0].removeValue(forKey: "thumbnailName")
        try JSONSerialization.data(withJSONObject: rows).write(to: index, options: .atomic)
        let migrated = try HistoryStore(directory: directory)
        try checkFalse(migrated.records[0].hasImagePreview)
        try migrated.restoreImageFilePreviews()
        try checkTrue(migrated.records[0].hasImagePreview)
        try checkTrue(migrated.records[0].isFavorite)
        try checkEqual(migrated.records[0].id, record.id)
        try checkEqual(migrated.records[0].items, record.items)
    }

    func testMissingNonImageAndMultipleFilesStayOrdinaryFiles() throws {
        let missing = directory.appendingPathComponent("missing.png")
        try checkFalse(try store.add(fileCapture([missing])).hasImagePreview)
        let text = directory.appendingPathComponent("note.txt")
        try Data("ordinary text".utf8).write(to: text)
        try checkFalse(try store.add(fileCapture([text])).hasImagePreview)
        let image = try makeImageFile(name: "multi.png")
        let multiple = try store.add(fileCapture([image, text]))
        try checkFalse(multiple.hasImagePreview)
        try checkEqual(multiple.items.count, 2)
    }

    func testImageFileThumbnailSurvivesSourceRemoval() throws {
        let url = try makeImageFile(name: "temporary.png")
        let record = try store.add(fileCapture([url]))
        let thumbnail = store.payloadURL(for: record, fileName: try require(record.thumbnailName))
        try FileManager.default.removeItem(at: url)
        let reloaded = try HistoryStore(directory: directory)
        try reloaded.restoreImageFilePreviews()
        try checkTrue(reloaded.records[0].hasImagePreview)
        try checkTrue(try Data(contentsOf: thumbnail).count > 0)
        let preview = store.payloadURL(for: record, fileName: try require(record.previewName))
        try checkTrue(CGImageSourceCreateWithURL(preview as CFURL, nil) != nil)
    }

    func testAuthorizedPreviewRejectsUnrelatedFileAndPreservesPayload() throws {
        let original = try makeImageFile(name: "selected.png")
        let unrelated = try makeImageFile(name: "unrelated.png")
        let record = try store.add(fileCapture([original]))
        try checkThrows(try store.restoreImageFilePreview(record.id, authorizedURL: unrelated))
        try store.restoreImageFilePreview(record.id, authorizedURL: original)
        try checkEqual(store.records[0].items, record.items)
        try checkTrue(store.records[0].previewName != nil)
    }
}
