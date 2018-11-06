import XCTest
@testable import Logger

/**
 Extension for Unit Tests
 */
extension Logger {
    func test_clearLogs() {
        let fm: FileManager = FileManager.default
            // Remove the directory containing all logs.
        try? fm.removeItem(at: baseURL as URL)
    }
}

class LoggerTests: XCTestCase {
    let message: String = "Sample log message\n"
    var logger: Logger = Logger()

    override func setUp() {
        super.setUp()
        logger = Logger()
    }

    override func tearDown() {
        super.tearDown()
        logger.test_clearLogs()
    }

    func testEmptyLog() {
        logger.test_clearLogs()
        XCTAssertTrue(logger.logData() == nil, "Must be nil.")
    }

    func testLogFileURL() {
        XCTAssertNotNil(Logger.shared.logFileURL, "Must not be nil.")
    }

    func testWriteLog() {
        let expectedLength: Int = MemoryLayout.size(ofValue: message)
        logger.log(message: message)
        let length: Int = MemoryLayout.size(ofValue: logger.logData()!)
        XCTAssertTrue(length == expectedLength, "Must be equal.")
    }

    // Adds about 1 second to the unit test time.
    func testWritePerformance() {
        self.measure {
            for count in 0...1000 {
                self.logger.log(message: "Sample log message \(count)")
            }
        }
    }

    static var allTests = [
        ("testEmptyLog", testEmptyLog),
        ("testLogFileURL", testLogFileURL),
        ("testWriteLog", testWriteLog)
    ]

}
