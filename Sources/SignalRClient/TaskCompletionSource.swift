import Foundation

class TaskCompletionSource<T> {
    private var resoler: ((T) -> Void)?
    private var rejector: ((Error) -> Void)?

    public func setup() async throws -> T {
        async let t = try withCheckedThrowingContinuation { continuation in 
                var resolved: Bool = false
                resoler = { param in
                    if (resolved) {
                        return
                    }
                    resolved = true
                    continuation.resume(returning: param)
                }
                rejector = { error in
                    if (resolved) {
                        return
                    }
                    resolved = true
                    continuation.resume(throwing: error)
                }
            }
        return try await t
    }

    public func resolve(_ value: T) {
        resoler?(value)
    }

    public func reject(_ error: Error) {
        rejector?(error)
    }
}


