import Observation

@MainActor
public protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Value { get }
    static func reduce(value: inout Value, nextValue: () -> Value)
}

public extension View {
    func preference<K: PreferenceKey>(key: K.Type, value: K.Value) -> some View {
        _PreferenceView(content: self, type: key, value: value)
    }

    func onPreferenceChange<K: PreferenceKey>(
        _ key: K.Type = K.self,
        perform action: @escaping @MainActor (K.Value) -> Void
    ) -> some View where K.Value: Equatable {
        _PreferenceChangeView(content: self, type: key, action: action)
    }
}
//
///// Hashable wrapper for a metatype value.
//struct HashableType<T>: Hashable {
//
//  static func == (lhs: HashableType, rhs: HashableType) -> Bool {
//    return lhs.base == rhs.base
//  }
//
//  let base: T.Type
//
//  init(_ base: T.Type) {
//    self.base = base
//  }
//
//  func hash(into hasher: inout Hasher) {
//    hasher.combine(ObjectIdentifier(base))
//  }
//}

@MainActor
protocol PreferenceView {
    associatedtype Preference: PreferenceKey
    var type: Preference.Type { get }
    var value: Preference.Value { get }

    var preferenceKey: ObjectIdentifier { get }
}

@MainActor
protocol _PreferenceContainer: Observable {
    associatedtype Preference: PreferenceKey
    var value: Preference.Value { get set }
    var preferenceKey: ObjectIdentifier { get }
}

@MainActor
@Observable
final class PreferenceContainer<Preference: PreferenceKey>: _PreferenceContainer {
    @ObservationIgnored
    var preferenceKey: ObjectIdentifier { ObjectIdentifier(type) }

    @ObservationIgnored
    let type: Preference.Type

    var value: Preference.Value = Preference.defaultValue

    init(type: Preference.Type, value: Preference.Value = Preference.defaultValue) {
        self.type = type
        self.value = value
    }
}

private struct _PreferenceView<Content: View, P: PreferenceKey>: View, PrimitiveView, PreferenceView {
    let content: Content
    let type: P.Type
    let value: P.Value

    var preferenceKey: ObjectIdentifier {
        ObjectIdentifier(type)
    }

    init(content: Content, type: P.Type, value: P.Value) {
        self.content = content
        self.type = type
        self.value = value
    }

    static var size: Int? { Content.size }

    func buildNode(_ node: Node) {
        node.addNode(at: 0, Node(observing: content.view))
    }

    func updateNode(_ node: Node) {
        node.view = self
        node.children[0].update(using: content.view)
    }
}

private struct _PreferenceChangeView<Content: View, P: PreferenceKey>: View, PrimitiveView where P.Value: Equatable {

    let content: Content
    let type: P.Type
    let action: @MainActor (P.Value) -> Void
    @State private var value: P.Value = P.defaultValue

    static var size: Int? {
        Content.size
    }

    func observe(node: Node) {
        withObservationTracking {
            let (_, container) = node.preference[
                ObjectIdentifier(type)
            ]! as! (P.Type, PreferenceContainer<P>)

            self.value = container.value
        } onChange: {
            MainActor.assumeIsolated {
                let (_, container) = node.preference[
                    ObjectIdentifier(type)
                ]! as! (P.Type, PreferenceContainer<P>)

                if self.value != container.value {
                    action(container.value)
                }
                
                self.value = container.value
                observe(node: node)
            }
        }
    }

    func buildNode(_ node: Node) {
        setupStateProperties(node: node)
            
        node.preference[ObjectIdentifier(type)] = node.preference[
            ObjectIdentifier(type),
            default: (P.self, PreferenceContainer(type: type))
        ]

        observe(node: node)

        node.addNode(at: 0, Node(observing: content.view))
    }

    func updateNode(_ node: Node) {
        setupStateProperties(node: node)
        node.view = self
        node.children[0].update(using: content.view)
    }

}
