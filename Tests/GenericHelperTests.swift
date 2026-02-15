import XCTest
@testable import WhisperClip

final class GenericHelperTests: XCTestCase {
    func testNormalizedAXValueForInsertionStripsPlaceholderOnlyValue() {
        let normalized = GenericHelper.normalizedAXValueForInsertion(
            existingValue: "Ask for follow-up",
            placeholderValue: "Ask for follow-up"
        )

        XCTAssertEqual(normalized, "")
    }

    func testNormalizedAXValueForInsertionKeepsRealValue() {
        let normalized = GenericHelper.normalizedAXValueForInsertion(
            existingValue: "Real user text",
            placeholderValue: "Ask for follow-up"
        )

        XCTAssertEqual(normalized, "Real user text")
    }

    func testNormalizedAXValueForInsertionIgnoresCaseDifferences() {
        let normalized = GenericHelper.normalizedAXValueForInsertion(
            existingValue: "ask for follow-up",
            placeholderValue: "Ask For Follow-Up"
        )

        XCTAssertEqual(normalized, "")
    }

    func testNormalizedAXValueForInsertionStripsTrailingPlaceholderToken() {
        let normalized = GenericHelper.normalizedAXValueForInsertion(
            existingValue: "Already typed text\nAsk for follow-up",
            placeholderValue: "Ask for follow-up"
        )

        XCTAssertEqual(normalized, "Already typed text")
    }

    func testNormalizedAXValueForInsertionStripsLeadingPlaceholderToken() {
        let normalized = GenericHelper.normalizedAXValueForInsertion(
            existingValue: "Ask for follow-up\nDraft response",
            placeholderValue: "Ask for follow-up"
        )

        XCTAssertEqual(normalized, "Draft response")
    }

    func testNormalizedAXValueForInsertionPreservesLeadingSpaceAfterPlaceholder() {
        let normalized = GenericHelper.normalizedAXValueForInsertion(
            existingValue: "Ask for follow-up changes",
            placeholderValue: "Ask for follow-up"
        )

        XCTAssertEqual(normalized, " changes")
    }

    func testShouldUseAXSelectedTextInsertionDisablesCodexBundle() {
        XCTAssertFalse(GenericHelper.shouldUseAXSelectedTextInsertion(frontmostBundleIdentifier: "com.openai.codex"))
    }

    func testShouldUseAXSelectedTextInsertionAllowsOtherBundle() {
        XCTAssertTrue(GenericHelper.shouldUseAXSelectedTextInsertion(frontmostBundleIdentifier: "com.apple.TextEdit"))
    }

    func testNormalizedAXValueForKnownAppPlaceholdersStripsCodexMiddleToken() {
        let normalized = GenericHelper.normalizedAXValueForKnownAppPlaceholders(
            existingValue: "Hello, hello, hello Ask for follow-up changes",
            frontmostBundleIdentifier: "com.openai.codex"
        )

        XCTAssertEqual(normalized, "Hello, hello, hello changes")
    }

    func testNormalizedAXValueForKnownAppPlaceholdersLeavesNonCodexUntouched() {
        let normalized = GenericHelper.normalizedAXValueForKnownAppPlaceholders(
            existingValue: "Hello, hello, hello Ask for follow-up changes",
            frontmostBundleIdentifier: "com.apple.TextEdit"
        )

        XCTAssertEqual(normalized, "Hello, hello, hello Ask for follow-up changes")
    }

    func testShouldDiscardKnownPlaceholderResidueForCodexAtSelectionStart() {
        let shouldDiscard = GenericHelper.shouldDiscardKnownPlaceholderResidue(
            existingValue: "Ask for follow-up.changes",
            selection: CFRange(location: 0, length: 0),
            frontmostBundleIdentifier: "com.openai.codex"
        )

        XCTAssertTrue(shouldDiscard)
    }

    func testShouldNotDiscardKnownPlaceholderResidueForCodexWhenCaretNotAtStart() {
        let shouldDiscard = GenericHelper.shouldDiscardKnownPlaceholderResidue(
            existingValue: "Ask for follow-up.changes",
            selection: CFRange(location: 3, length: 0),
            frontmostBundleIdentifier: "com.openai.codex"
        )

        XCTAssertFalse(shouldDiscard)
    }

    func testRecordingCleanupSkipsDeletionWhenDisabled() throws {
        let recorder = AudioRecorder.shared
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("WhisperClipUnitTests/AutoDelete", isDirectory: true)
        let testFile = testDirectory.appendingPathComponent("recording-auto-delete-disabled.m4a")

        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: testFile.path, contents: Data("test-audio".utf8))

        let didDelete = recorder.cleanupOutputFileIfNeeded(for: testFile, forceDeleteEnabled: false)

        XCTAssertFalse(didDelete)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        try FileManager.default.removeItem(at: testDirectory)
    }

    func testRecordingCleanupDeletesWhenEnabled() throws {
        let recorder = AudioRecorder.shared
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("WhisperClipUnitTests/AutoDelete", isDirectory: true)
        let testFile = testDirectory.appendingPathComponent("recording-auto-delete-enabled.m4a")

        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: testFile.path, contents: Data("test-audio".utf8))

        let didDelete = recorder.cleanupOutputFileIfNeeded(for: testFile, forceDeleteEnabled: true)

        XCTAssertTrue(didDelete)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))

        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.removeItem(at: testDirectory)
        }
    }

    func testAES256EncryptionDecryption() throws {
        // Test data
        let originalData = "Hello, World!".data(using: .utf8)!
        let key = Data([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
                       0x17, 0x18, 0x19, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x30, 0x31, 0x32])

        // Encrypt
        let encryptedData = try GenericHelper.aesEncrypt(plaintext: originalData, keyData: key)

        // Verify encrypted data is different from original
        XCTAssertNotEqual(encryptedData, originalData)

        // Decrypt
        let decryptedData = try GenericHelper.aesDecrypt(sealedData: encryptedData, keyData: key)

        // Verify decrypted data matches original
        XCTAssertEqual(decryptedData, originalData)
    }

    func testAES256EncryptionDecryptionWithEmptyData() throws {
        let originalData = Data()
        let key = Data([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
                       0x17, 0x18, 0x19, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x30, 0x31, 0x32])

        let encryptedData = try GenericHelper.aesEncrypt(plaintext: originalData, keyData: key)
        let decryptedData = try GenericHelper.aesDecrypt(sealedData: encryptedData, keyData: key)

        XCTAssertEqual(decryptedData, originalData)
    }

    func testAES256EncryptionDecryptionWithLargeData() throws {
        // Create a large data block (1MB)
        let originalData = Data(count: 1024 * 1024)
        let key = Data([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
                       0x17, 0x18, 0x19, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x30, 0x31, 0x32])

        let encryptedData = try GenericHelper.aesEncrypt(plaintext: originalData, keyData: key)
        let decryptedData = try GenericHelper.aesDecrypt(sealedData: encryptedData, keyData: key)

        XCTAssertEqual(decryptedData, originalData)
    }

    func testAES256EncryptionDecryptionWithDifferentKeys() throws {
        let originalData = "Test Data".data(using: .utf8)!
        let key1 = Data([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
                        0x17, 0x18, 0x19, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x30, 0x31, 0x32])
        let key2 = Data([0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                        0x18, 0x19, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x30, 0x31, 0x32, 0x33])

        let encryptedData = try GenericHelper.aesEncrypt(plaintext: originalData, keyData: key1)

        // Attempt to decrypt with wrong key
        XCTAssertThrowsError(try GenericHelper.aesDecrypt(sealedData: encryptedData, keyData: key2))
    }
}
