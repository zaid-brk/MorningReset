import Foundation

// A tiny assertion adapter for Command Line Tools, which omit XCTest.
// test_core.py compiles the unchanged test methods with this adapter.
class XCTestCase {}
enum CheckResults {
    static var failures = 0
    static func fail(_ message: String, file: StaticString, line: UInt) {
        failures += 1
        print("FAIL \(file):\(line): \(message)")
    }
}
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                                  file: StaticString = #filePath, line: UInt = #line) {
    do { let lhs = try a(), rhs = try b(); if lhs != rhs { CheckResults.fail("\(lhs) != \(rhs)", file: file, line: line) } }
    catch { CheckResults.fail(error.localizedDescription, file: file, line: line) }
}
func XCTAssertNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                                     file: StaticString = #filePath, line: UInt = #line) {
    do { if try a() == b() { CheckResults.fail("Values are equal", file: file, line: line) } }
    catch { CheckResults.fail(error.localizedDescription, file: file, line: line) }
}
func XCTAssertTrue(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !value() { CheckResults.fail("Expected true", file: file, line: line) }
}
func XCTAssertFalse(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    if value() { CheckResults.fail("Expected false", file: file, line: line) }
}
func XCTAssertNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #filePath, line: UInt = #line) {
    if value() != nil { CheckResults.fail("Expected nil", file: file, line: line) }
}
func XCTAssertThrowsError<T>(_ body: @autoclosure () throws -> T, file: StaticString = #filePath,
                             line: UInt = #line, _ handler: (Error) -> Void = { _ in }) {
    do { _ = try body(); CheckResults.fail("Expected an error", file: file, line: line) }
    catch { handler(error) }
}
