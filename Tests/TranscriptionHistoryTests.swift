import XCTest
@testable import WhisperClip

@MainActor
final class TranscriptionHistoryTests: XCTestCase {
    private var originalSaveToHistorySetting = DefaultSettings.saveTranscriptionsToHistory

    override func setUp() {
        super.setUp()
        originalSaveToHistorySetting = SettingsStore.shared.saveTranscriptionsToHistory
        TranscriptionHistory.shared.clearAll()
    }

    override func tearDown() {
        TranscriptionHistory.shared.clearAll()
        SettingsStore.shared.saveTranscriptionsToHistory = originalSaveToHistorySetting
        super.tearDown()
    }

    func testAddDoesNotPersistWhenHistorySettingIsDisabled() {
        SettingsStore.shared.saveTranscriptionsToHistory = false

        TranscriptionHistory.shared.add(text: "private transcript", source: .microphone)

        XCTAssertTrue(TranscriptionHistory.shared.items.isEmpty)
    }

    func testAddPersistsWhenHistorySettingIsEnabled() {
        SettingsStore.shared.saveTranscriptionsToHistory = true

        TranscriptionHistory.shared.add(text: "saved transcript", source: .microphone)

        XCTAssertEqual(TranscriptionHistory.shared.items.count, 1)
        XCTAssertEqual(TranscriptionHistory.shared.items.first?.text, "saved transcript")
    }

    func testHistoryKeepsOnlyFiveMostRecentItems() {
        SettingsStore.shared.saveTranscriptionsToHistory = true

        for index in 0..<8 {
            TranscriptionHistory.shared.add(text: "transcript \(index)", source: .microphone)
        }

        XCTAssertEqual(TranscriptionHistory.shared.items.count, 5)
        XCTAssertEqual(TranscriptionHistory.shared.items.first?.text, "transcript 7")
        XCTAssertEqual(TranscriptionHistory.shared.items.last?.text, "transcript 3")
    }

    func testPrivacyDefaultDisablesHistoryStorage() {
        XCTAssertFalse(DefaultSettings.saveTranscriptionsToHistory)
    }

    func testFocusedTextBoxOutputDefaultIsEnabled() {
        XCTAssertTrue(DefaultSettings.autoPasteToFocusedTextInput)
    }
}
