import XCTest
@testable import RemindersSyncCore

final class ContainsClTagTests: XCTestCase {
    
    // MARK: - Test cases that should match #cl tag
    
    func testShouldMatch_ClTagAtStartOfString() {
        XCTAssertTrue(containsClTag("#cl"))
    }
    
    func testShouldMatch_ClTagWithTaskText() {
        XCTAssertTrue(containsClTag("task #cl"))
    }
    
    func testShouldMatch_ClTagInParentheses() {
        XCTAssertTrue(containsClTag("(#cl)"))
    }
    
    func testShouldMatch_ClTagWithPeriod() {
        XCTAssertTrue(containsClTag("#cl."))
    }
    
    func testShouldMatch_ClTagWithCommaAndMore() {
        XCTAssertTrue(containsClTag("do #cl, then …"))
    }
    
    func testShouldMatch_ClTagWithBrackets() {
        XCTAssertTrue(containsClTag("[#cl]"))
    }
    
    func testShouldMatch_ClTagWithCurlyBraces() {
        XCTAssertTrue(containsClTag("{#cl}"))
    }
    
    func testShouldMatch_ClTagWithQuotes() {
        XCTAssertTrue(containsClTag("\"#cl\""))
        XCTAssertTrue(containsClTag("'#cl'"))
        XCTAssertTrue(containsClTag("`#cl`"))
    }
    
    func testShouldMatch_ClTagWithVariousPunctuation() {
        XCTAssertTrue(containsClTag("#cl;"))
        XCTAssertTrue(containsClTag("#cl:"))
        XCTAssertTrue(containsClTag("#cl!"))
        XCTAssertTrue(containsClTag("#cl?"))
        XCTAssertTrue(containsClTag("#cl-"))
    }
    
    func testShouldMatch_ClTagAtEndOfString() {
        XCTAssertTrue(containsClTag("task #cl"))
    }
    
    func testShouldMatch_ClTagWithWhitespaceAround() {
        XCTAssertTrue(containsClTag(" #cl "))
        XCTAssertTrue(containsClTag("\t#cl\n"))
    }
    
    // MARK: - Test cases that should NOT match #cl tag
    
    func testShouldNotMatch_CleanupTag() {
        XCTAssertFalse(containsClTag("#cleanup"))
    }
    
    func testShouldNotMatch_DoubleHashCl() {
        XCTAssertFalse(containsClTag("##cl"))
    }
    
    func testShouldNotMatch_CloudTag() {
        XCTAssertFalse(containsClTag("task #cloud"))
    }
    
    func testShouldNotMatch_ClTagAsPartOfWord() {
        XCTAssertFalse(containsClTag("mycl#cl"))
        XCTAssertFalse(containsClTag("#clwork"))
        XCTAssertFalse(containsClTag("work#cl"))
    }
    
    func testShouldNotMatch_ClTagAsPartOfHashtag() {
        XCTAssertFalse(containsClTag("#cl123"))
        XCTAssertFalse(containsClTag("#clA"))
        XCTAssertFalse(containsClTag("#cl_tag"))
    }
    
    func testShouldNotMatch_MultipleHashesWithCl() {
        XCTAssertFalse(containsClTag("###cl"))
        XCTAssertFalse(containsClTag("####cl"))
    }
    
    func testShouldNotMatch_NoClTag() {
        XCTAssertFalse(containsClTag("task without tag"))
        XCTAssertFalse(containsClTag("#other"))
        XCTAssertFalse(containsClTag(""))
    }
    
    func testShouldNotMatch_CaseVariations() {
        XCTAssertFalse(containsClTag("#CL"))
        XCTAssertFalse(containsClTag("#Cl"))
        XCTAssertFalse(containsClTag("#cL"))
    }
    
    // MARK: - Edge cases and complex scenarios
    
    func testComplexScenarios() {
        // Multiple tags with #cl as standalone
        XCTAssertTrue(containsClTag("#work #cl #personal"))
        
        // #cl surrounded by other hashtags that should not match
        XCTAssertTrue(containsClTag("#cleanup (#cl) #cloud"))
        
        // Mixed case with valid #cl
        XCTAssertTrue(containsClTag("Task #CLEANUP and #cl tag"))
        
        // Multiple #cl tags
        XCTAssertTrue(containsClTag("#cl and #cl again"))
        
        // #cl with newlines
        XCTAssertTrue(containsClTag("task\n#cl\nmore"))
    }
    
    func testRealWorldTaskExamples() {
        // Realistic task examples that should match
        XCTAssertTrue(containsClTag("- [ ] Review code #cl"))
        XCTAssertTrue(containsClTag("- [x] Meeting prep (#cl)"))
        XCTAssertTrue(containsClTag("- [ ] Fix bug. #cl @john"))
        XCTAssertTrue(containsClTag("- [ ] Deploy to staging, #cl, then notify team"))
        
        // Realistic task examples that should NOT match
        XCTAssertFalse(containsClTag("- [ ] Clean up old files #cleanup"))
        XCTAssertFalse(containsClTag("- [ ] Upload to #cloud storage"))
        XCTAssertFalse(containsClTag("- [ ] Check ##cl documentation"))
        XCTAssertFalse(containsClTag("- [ ] Review #client requirements"))
    }
}