import Foundation
import IntegraCore

public struct TestFailure {
    public let testName: String
    public let message: String
    public let file: String
    public let line: Int
}

public class TestContext {
    public static var currentTestName: String = ""
    public static var failures: [TestFailure] = []
    public static var totalTestsRun: Int = 0
    public static var totalPassed: Int = 0
    
    public static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual != expected {
            let msg = message.isEmpty ? "Expected '\(expected)', but got '\(actual)'" : "\(message) (Expected '\(expected)', got '\(actual)')"
            failures.append(TestFailure(testName: currentTestName, message: msg, file: file, line: line))
        }
    }
    
    public static func assertTrue(_ condition: Bool, _ message: String = "Expected true, got false", file: String = #file, line: Int = #line) {
        if !condition {
            failures.append(TestFailure(testName: currentTestName, message: message, file: file, line: line))
        }
    }
    
    public static func assertFalse(_ condition: Bool, _ message: String = "Expected false, got true", file: String = #file, line: Int = #line) {
        if condition {
            failures.append(TestFailure(testName: currentTestName, message: message, file: file, line: line))
        }
    }
    
    public static func assertNil(_ value: Any?, _ message: String = "Expected nil", file: String = #file, line: Int = #line) {
        if value != nil {
            failures.append(TestFailure(testName: currentTestName, message: message, file: file, line: line))
        }
    }
    
    public static func assertNotNil(_ value: Any?, _ message: String = "Expected non-nil", file: String = #file, line: Int = #line) {
        if value == nil {
            failures.append(TestFailure(testName: currentTestName, message: message, file: file, line: line))
        }
    }
    
    public static func assertLessThanOrEqual<T: Comparable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual > expected {
            let msg = message.isEmpty ? "Expected \(actual) <= \(expected)" : "\(message) (\(actual) > \(expected))"
            failures.append(TestFailure(testName: currentTestName, message: msg, file: file, line: line))
        }
    }
    
    public static func runTest(suite: String, name: String, block: () throws -> Void) {
        currentTestName = "[\(suite)] \(name)"
        totalTestsRun += 1
        let failuresBefore = failures.count
        
        do {
            try block()
        } catch {
            failures.append(TestFailure(testName: currentTestName, message: "Threw uncaught error: \(error)", file: #file, line: #line))
        }
        
        if failures.count == failuresBefore {
            totalPassed += 1
            print("  ✔︎ \(currentTestName)")
        } else {
            print("  ✖ FAIL: \(currentTestName)")
        }
    }
    
    @MainActor
    public static func runAsyncTest(suite: String, name: String, block: () async throws -> Void) async {
        currentTestName = "[\(suite)] \(name)"
        totalTestsRun += 1
        let failuresBefore = failures.count
        
        do {
            try await block()
        } catch {
            failures.append(TestFailure(testName: currentTestName, message: "Threw uncaught error: \(error)", file: #file, line: #line))
        }
        
        if failures.count == failuresBefore {
            totalPassed += 1
            print("  ✔︎ \(currentTestName)")
        } else {
            print("  ✖ FAIL: \(currentTestName)")
        }
    }
}
