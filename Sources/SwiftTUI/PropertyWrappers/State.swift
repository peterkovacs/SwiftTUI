import Foundation

@MainActor
@propertyWrapper
public struct State<T>: AnyState {
    public let initialValue: T

    public init(initialValue: T) {
        print("State.init")
        self.initialValue = initialValue
    }

    public init(wrappedValue: T) {
        print("State.init")
        self.initialValue = wrappedValue
    }

    /// @State variables can have a nonmutating setter, because they are just
    /// a reference to state stored in a Node.
    var valueReference = StateReference()

    public var wrappedValue: T {
        get {
            guard let node = valueReference.state,
                  let label = valueReference.label
            else {
                assertionFailure("Attempting to access @State variable before view is instantiated")
                return initialValue
            }
            if let value = node.state[label] {
                return value as! T
            }
            return initialValue
        }
        nonmutating set {
            guard let state = valueReference.state,
                  let label = valueReference.label
            else {
                assertionFailure("Attempting to modify @State variable before view is instantiated")
                return
            }
            state.state[label] = newValue
            state.node?.invalidate()
        }
    }

    public var projectedValue: Binding<T> {
        // Note: this works, but it is not as efficient as in SwiftUI.
        // In SwiftUI, Bindings can actively observe state. If you have a
        // @State variable in a view that is not directly used in the body,
        // but only in child views through @Bindings, updating the @Bindings
        // will only invalidate the child views.
        Binding<T>(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}

@MainActor
protocol AnyState {
    var valueReference: StateReference { get }
}

@MainActor
class StateReference {
    var state: Node.StateStorage?
    var label: String?
}
