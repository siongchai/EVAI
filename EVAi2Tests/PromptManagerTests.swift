import XCTest
@testable import EVAi2

final class PromptManagerTests: XCTestCase {
    override func tearDown() {
        PromptManager.restoreDefault()
        super.tearDown()
    }

    func testDefaultPromptIsUsedWhenNoOverride() {
        PromptManager.restoreDefault()
        XCTAssertTrue(PromptManager.isUsingDefaultPrompt)
        XCTAssertFalse(PromptManager.effectivePrompt.isEmpty)
    }

    func testCustomPromptOverridePersists() {
        PromptManager.saveCustomPrompt("Custom extraction prompt")
        XCTAssertFalse(PromptManager.isUsingDefaultPrompt)
        XCTAssertEqual(PromptManager.customPromptOverride, "Custom extraction prompt")
        XCTAssertEqual(PromptManager.effectivePrompt, "Custom extraction prompt")
    }
}
