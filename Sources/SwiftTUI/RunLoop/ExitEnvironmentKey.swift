
enum Exit {
    static let (stream, continuation): (AsyncStream<Void>, AsyncStream<Void>.Continuation) = {
        AsyncStream.makeStream()
    }()

    static func exit() {
        continuation.yield()
    }
}

extension EnvironmentValues {
    /// Used to shutdown the application.
    public var exit: @MainActor () -> Void {
        get { self[ExitEnvironmentKey.self] }
        set { self[ExitEnvironmentKey.self] = newValue }
    }

    private struct ExitEnvironmentKey: EnvironmentKey {
        static var defaultValue: @MainActor () -> Void = {
            Exit.continuation.yield()
        }
    }
}
