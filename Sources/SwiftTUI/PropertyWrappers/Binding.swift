import Foundation

@MainActor
@propertyWrapper
public struct Binding<T> {
    let get: @MainActor () -> T
    let set: @MainActor (T) -> Void

    public init(get: @escaping @MainActor () -> T, set: @escaping @MainActor (T) -> Void) {
        self.get = get
        self.set = set
    }

    public var wrappedValue: T {
        get { get() }
        nonmutating set { set(newValue) }
    }

    public var projectedValue: Binding<T> { self }
}
