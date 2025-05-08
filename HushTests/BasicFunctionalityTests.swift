import XCTest
import Testing // Swift 6 Testing framework

/// A basic test class to verify that our test setup is working with XCTest
class BasicFunctionalityTests: XCTestCase {
    
    func testBasicFunctionality() {
        // A simple test that should always pass
        XCTAssertTrue(true, "True should be true")
        XCTAssertFalse(false, "False should be false")
        XCTAssertEqual(2 + 2, 4, "Basic math should work")
    }
    
    func testOptionalUnwrapping() {
        // Test optional unwrapping
        let optionalValue: Int? = 42
        XCTAssertNotNil(optionalValue, "Optional value should not be nil")
        
        if let unwrapped = optionalValue {
            XCTAssertEqual(unwrapped, 42, "Unwrapped value should equal 42")
        } else {
            XCTFail("Failed to unwrap optional value")
        }
    }
    
    func testArrayOperations() {
        // Test basic array operations
        var array = [1, 2, 3]
        
        XCTAssertEqual(array.count, 3, "Array should have 3 elements")
        
        array.append(4)
        XCTAssertEqual(array.count, 4, "Array should have 4 elements after append")
        XCTAssertEqual(array.last, 4, "Last element should be 4")
        
        array.removeFirst()
        XCTAssertEqual(array.first, 2, "First element should now be 2")
    }
    
    func testStringManipulation() {
        // Test string operations
        let string = "Hello, World!"
        
        XCTAssertTrue(string.contains("Hello"), "String should contain 'Hello'")
        XCTAssertFalse(string.contains("Goodbye"), "String should not contain 'Goodbye'")
        
        let uppercased = string.uppercased()
        XCTAssertEqual(uppercased, "HELLO, WORLD!", "Uppercased string should match")
        
        let lowercased = string.lowercased()
        XCTAssertEqual(lowercased, "hello, world!", "Lowercased string should match")
    }
    
    func testAsync() async {
        // Test asynchronous functionality
        let result = await asyncOperation()
        XCTAssertEqual(result, 42, "Async operation should return 42")
    }
    
    private func asyncOperation() async -> Int {
        // Simulate an asynchronous operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return 42
    }
}

// Swift 6 Testing Framework demo
@Suite("Basic Swift Testing Demo")
struct BasicTestingSuite {
    
    @Test("Basic functionality with Swift Testing")
    func testBasicFunctionality() {
        // This test uses Swift 6's #expect macro instead of XCTest assertions
        #expect(true)
        #expect(!false)
        #expect(2 + 2 == 4)
    }
    
    @Test("Optional handling with Swift Testing")
    func testOptionalHandling() {
        let optionalValue: Int? = 42
        
        // Swift Testing's #expect provides better diagnostics for optionals
        #expect(optionalValue != nil)
        
        // Swift Testing's #require macro will automatically unwrap optionals
        let unwrapped = try #require(optionalValue)
        #expect(unwrapped == 42)
    }
    
    @Test("Array operations with Swift Testing")
    func testArrayOperations() {
        var array = [1, 2, 3]
        
        #expect(array.count == 3)
        #expect(array.contains(2))
        
        array.append(4)
        #expect(array.count == 4)
        #expect(array.last == 4)
        
        let removed = array.removeFirst()
        #expect(removed == 1)
        #expect(array.first == 2)
    }
    
    // Swift Testing supports parameterized tests
    @Test("String operations", arguments: [
        ("Hello, World!", "HELLO, WORLD!", "hello, world!"),
        ("Swift 6", "SWIFT 6", "swift 6"),
        ("Testing", "TESTING", "testing")
    ])
    func testStringOperations(original: String, uppercased: String, lowercased: String) {
        #expect(original.uppercased() == uppercased)
        #expect(original.lowercased() == lowercased)
    }
    
    @Test("Async operations with Swift Testing")
    func testAsyncOperation() async throws {
        let result = await asyncOperation()
        #expect(result == 42)
    }
    
    // Showcase Swift 6's count(where:) functionality
    @Test("New count(where:) method")
    func testCountWhere() {
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        
        let evenCount = numbers.count { $0 % 2 == 0 }
        #expect(evenCount == 5)
        
        let oddCount = numbers.count { $0 % 2 != 0 }
        #expect(oddCount == 5)
        
        let greaterThanFiveCount = numbers.count { $0 > 5 }
        #expect(greaterThanFiveCount == 5)
    }
    
    private func asyncOperation() async -> Int {
        // Simulate an asynchronous operation
        try? await Task.sleep(for: .milliseconds(100)) // using Swift 6's Task.sleep with Duration
        return 42
    }
} 