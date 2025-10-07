import XCTest
@testable import RemindersSyncCore

final class ObsidianURLTests: XCTestCase {
    func testObsidianURLPercentEncodesSpaces() throws {
        let task = ObsidianTask(
            id: UUID().uuidString,
            text: "Example task",
            dueDate: nil,
            filePath: "Projects/Weekly Notes.md",
            vaultPath: "/Users/example/My Vault",
            isCompleted: false
        )
        guard let url = task.obsidianURL else {
            XCTFail("Expected obsidian URL to be produced")
            return
        }
        let absoluteString = url.absoluteString
        XCTAssertFalse(absoluteString.contains(" "), "URL should not contain raw spaces: \(absoluteString)")
        XCTAssertTrue(absoluteString.contains("%20"), "URL should percent-encode spaces: \(absoluteString)")
        XCTAssertEqual(url.scheme, "obsidian")
        XCTAssertEqual(url.host, "open")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let vaultValue = components?.queryItems?.first(where: { $0.name == "vault" })?.value
        let fileValue = components?.queryItems?.first(where: { $0.name == "file" })?.value
        XCTAssertEqual(vaultValue, "My Vault")
        XCTAssertEqual(fileValue, "Projects/Weekly Notes.md")
    }
    
    func testObsidianURLEncodesReservedCharacters() throws {
        let task = ObsidianTask(
            id: UUID().uuidString,
            text: "Example task",
            dueDate: nil,
            filePath: "Areas/Finance/Statement #1 (Draft).md",
            vaultPath: "/Users/example/My Vault",
            isCompleted: false
        )
        guard let url = task.obsidianURL else {
            XCTFail("Expected obsidian URL to be produced")
            return
        }
        let absoluteString = url.absoluteString
        XCTAssertFalse(absoluteString.contains("#"), "URL should encode fragment character: \(absoluteString)")
        XCTAssertTrue(absoluteString.contains("%23"), "URL should percent-encode #: \(absoluteString)")
        XCTAssertEqual(url.scheme, "obsidian")
        XCTAssertEqual(url.host, "open")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let fileValue = components?.queryItems?.first(where: { $0.name == "file" })?.value
        XCTAssertEqual(fileValue, "Areas/Finance/Statement #1 (Draft).md")
    }
}
