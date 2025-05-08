import XCTest

/// A basic test class to verify that our test setup is working
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