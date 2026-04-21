import XCTest
@testable import MathInk

final class InkCommandTests: XCTestCase {
    func testParsesRedPen() {
        let command = InkCommand.parse("red pen")

        XCTAssertEqual(command?.tool, .pen)
        XCTAssertEqual(command?.color, .red)
    }

    func testParsesBluePencil() {
        let command = InkCommand.parse("blue pencil")

        XCTAssertEqual(command?.tool, .pencil)
        XCTAssertEqual(command?.color, .blue)
    }

    func testParsesYellowMarker() {
        let command = InkCommand.parse("yellow marker")

        XCTAssertEqual(command?.tool, .marker)
        XCTAssertEqual(command?.color, .yellow)
    }

    func testParsesEraserCommands() {
        XCTAssertEqual(InkCommand.parse("eraser")?.tool, .eraser)
        XCTAssertEqual(InkCommand.parse("please erase this")?.tool, .eraser)
    }

    func testRejectsUnknownCommands() {
        XCTAssertNil(InkCommand.parse("switch to something cool"))
        XCTAssertNil(InkCommand.parse("blue"))
    }
}
