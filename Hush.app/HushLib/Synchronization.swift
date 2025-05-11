import Foundation

/// A namespace for our synchronization utilities, to avoid conflicts with system types
public enum Synchronization {
    /// Memory ordering options for atomics
    public enum MemoryOrdering {
        /// Most relaxed memory ordering
        case relaxed
        /// Acquire memory ordering
        case acquire
        /// Release memory ordering
        case release
        /// Acquire-release memory ordering
        case acquireRelease
        /// Most strict memory ordering
        case sequentiallyConsistent
    }
    
    /// A thread-safe wrapper for a value
    /// Mark as @unchecked Sendable to allow safe use across actor boundaries
    public final class Atomic<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var _value: T
        
        /// Initialize with a value
        public init(_ value: T) {
            self._value = value
        }
        
        /// Store a new value with memory ordering
        public func store(_ newValue: T, ordering: MemoryOrdering) {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
        
        /// Load the current value with memory ordering
        public func load(ordering: MemoryOrdering) -> T {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        
        /// Atomically modify the value
        public func modify<R>(_ body: (inout T) -> R) -> R {
            lock.lock()
            defer { lock.unlock() }
            return body(&_value)
        }
    }
} 