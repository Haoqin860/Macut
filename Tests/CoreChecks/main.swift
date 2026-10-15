import Foundation

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

func checkEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) throws {
    guard lhs == rhs else { throw CheckFailure(description: "\(file):\(line): values differ") }
}
func checkNotEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) throws {
    guard lhs != rhs else { throw CheckFailure(description: "\(file):\(line): values unexpectedly equal") }
}
func checkTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) throws {
    guard value else { throw CheckFailure(description: "\(file):\(line): expected true") }
}
func checkFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) throws {
    try checkTrue(!value, file: file, line: line)
}
func checkAtMost<T: Comparable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) throws {
    try checkTrue(lhs <= rhs, file: file, line: line)
}
func require<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value else { throw CheckFailure(description: "\(file):\(line): unexpected nil") }
    return value
}
func checkThrows<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) throws {
    do { _ = try expression() } catch { return }
    throw CheckFailure(description: "\(file):\(line): expected an error")
}

let checks = HistoryStoreChecks()
let cases: [(String, () throws -> Void)] = [
    ("deduplication and favorites", checks.testDeduplicationPreservesFavoriteAndOriginalCaptureDate),
    ("rich text lossless round trip", checks.testRichRepresentationsRoundTripWithoutLosingOriginalBytes),
    ("multiple file item boundaries", checks.testItemBoundariesAndFileOrderArePreserved),
    ("count pruning and favorite protection", checks.testPruningProtectsFavoritesAndKeepsNewestOrdinaryRecords),
    ("storage budget includes favorites", checks.testFavoriteBytesCountTowardCapacity),
    ("time retention", checks.testTimeRetentionUsesLastUsageAndDoesNotDeleteFavorites),
    ("payload and index deletion", checks.testDeleteRemovesPayloadAndIndexEntry),
    ("failed write rollback", checks.testFailedCommitLeavesExistingHistoryAndNoOrphanedPayload),
    ("corrupt index preservation", checks.testCorruptIndexIsReportedWithoutOverwritingIt),
    ("Chinese and multi-term search", checks.testSearchHandlesChineseMultipleTermsAndCase),
    ("image thumbnail and original bytes", checks.testImageThumbnailIsBoundedAndOriginalPayloadIsIntact),
    ("image file preview preserves file paste", checks.testCopiedImageFileGetsPreviewWithoutChangingPastePayload),
    ("extensionless image file preview", checks.testExtensionlessImageCacheFileIsRecognizedByContents),
    ("existing history preview migration", checks.testExistingFileHistoryBackfillsPreviewAndPreservesFavorites),
    ("missing, ordinary and multiple file handling", checks.testMissingNonImageAndMultipleFilesStayOrdinaryFiles),
    ("image thumbnail survives source removal", checks.testImageFileThumbnailSurvivesSourceRemoval),
    ("authorized preview rejects unrelated files", checks.testAuthorizedPreviewRejectsUnrelatedFileAndPreservesPayload)
]
var failures = 0
for (name, check) in cases {
    do {
        try checks.setUpWithError()
        try check()
        print("PASS \(name)")
    } catch {
        failures += 1
        print("FAIL \(name): \(error)")
    }
    do { try checks.tearDownWithError() } catch { print("Cleanup: \(error)"); failures += 1 }
}
print("\(cases.count - failures)/\(cases.count) checks passed")
exit(failures == 0 ? 0 : 1)
