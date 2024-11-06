import Foundation
#if os(macOS)
import Combine
#endif



/// The node of a view graph.
///
/// The view graph is the runtime representation of the views in an application.
/// Every view corresponds to a node. If a view is used in multiple places, in
/// each of the places it is used it will have a seperate node.
///
/// Once (a part of) the node tree is built, views can update the node tree, as
/// long as their type match. This is done by the views themselves.
///
/// Note that the control tree more closely resembles the layout hierarchy,
/// because structural views (ForEach, etc.) have their own node.
@MainActor
final class Node {
    var view: (any GenericView)!

    final class StateStorage {
        var state: [String: Any] = [:]
        weak var node: Node?

        init(state: [String : Any] = [:], node: Node) {
            self.state = state
            self.node = node
        }
    }

    var state: StateStorage!
    var environment: ((inout EnvironmentValues) -> Void)?
    var preference: [
        AnyHashable: (any PreferenceKey.Type, any _PreferenceContainer)
    ]

    var control: Control?
    weak var application: Application?

    /// For modifiers only, references to the controls
    var controls: WeakSet<Control>?

    private(set) weak var parent: Node?
    private(set) var children: [Node] = []

    private(set) var index: Int = 0

    private(set) var built = false

    init(observing: @autoclosure () -> GenericView) {
        self.preference = [:]
        self.state = .init(node: self)
        self.view = withObservationTracking(observing) { [weak self] in
            guard let self else { return }

            MainActor.assumeIsolated {
                invalidate()
            }
        }
    }

    func update(using observing: @autoclosure () -> GenericView) {
        build()

        let view = withObservationTracking(observing) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                invalidate()
            }
        }
        view.updateNode(self)
        self.view = view
    }

    func invalidate() {
        root.application?.invalidateNode(self)
    }

    var root: Node { parent?.root ?? self }

    /// The total number of controls in the node.
    /// The node does not need to be fully built for the size to be computed.
    var size: Int {
        if let size = type(of: view).size { return size }
        build()
        return children.map(\.size).reduce(0, +)
    }

    /// The number of controls in the parent node _before_ the current node.
    private var offset: Int {
        var offset = 0
        for i in 0 ..< index {
            offset += parent?.children[i].size ?? 0
        }
        return offset
    }

    func build() {
        if !built {
            self.view.buildNode(self)
            built = true
            if let container = view as? LayoutRootView {
                container.loadData(node: self)
            }
        }
    }

    // MARK: - Changing nodes

    func addNode(at index: Int, _ node: Node) {
        guard node.parent == nil else { fatalError("Node is already in tree") }
        children.insert(node, at: index)
        node.parent = self
        for i in index ..< children.count {
            children[i].index = i
        }
        if built {
            for i in 0 ..< node.size {
                insertControl(at: node.offset + i)
            }
        }
    }

    func removeNode(at index: Int) {
        if built {
            for i in (0 ..< children[index].size).reversed() {
                removeControl(at: children[index].offset + i)
            }
        }
        children[index].parent = nil
        children.remove(at: index)
        for i in index ..< children.count {
            children[i].index = i
        }
    }

    // MARK: - Container data source

    func control(at offset: Int) -> Control {
        build()
        if offset == 0, let control = self.control { return control }
        var i = 0
        for child in children {
            let size = child.size
            if (offset - i) < size {
                let control = child.control(at: offset - i)
                if let modifier = self.view as? ModifierView {
                    return modifier.passControl(control, node: self)
                }
                return control
            }
            i += size
        }
        fatalError("Out of bounds")
    }

    // MARK: - Container changes

    private func insertControl(at offset: Int) {
        if let container = view as? LayoutRootView {
            container.insertControl(at: offset, node: self)
            return
        }
        parent?.insertControl(at: offset + self.offset)
    }

    private func removeControl(at offset: Int) {
        if let container = view as? LayoutRootView {
            container.removeControl(at: offset, node: self)
            return
        }
        parent?.removeControl(at: offset + self.offset)
    }

    // MARK: Preference Merge
    func mergePreferences() {
        children.forEach { $0.mergePreferences() }

        // any preference set by this node should override any preference set by child nodes.
        // child nodes should start with the `defaultValue` and then merge sibling children into a single value.
        var preference = children.reduce(into: [:] as [AnyHashable: (any PreferenceKey.Type, any _PreferenceContainer)]) { partialResult, node in
            @MainActor func merge<T: PreferenceKey>(
                key: T.Type,
                container newValue: Any
            ) {
                // container is not the one we want to keep.
                // we want to keep the one that is in `partialResult`.
                let newValue = newValue as! PreferenceContainer<T>
                let (key, existingValue) = partialResult[
                    newValue.preferenceKey,
                    default: (newValue.type, PreferenceContainer(type: newValue.type))
                ] as! (T.Type,  PreferenceContainer<T>)

                var value = existingValue.value
                T.reduce(value: &value) {
                    newValue.value
                }

                existingValue.value = value
                partialResult[newValue.preferenceKey] = (key, existingValue)
            }

            node.preference.forEach { (key, value) in
                merge(
                    key: value.0,
                    container: value.1
                )
            }
        }

        if let view = view as? any PreferenceView {
            func unwrap<T: PreferenceView>(view: T) -> (any PreferenceKey.Type, any _PreferenceContainer){
                let container = preference[
                    view.preferenceKey,
                    default: (
                        view.type,
                        PreferenceContainer(type: view.type)
                    )
                ] as! (T.Preference.Type, PreferenceContainer<T.Preference>)

                container.1.value = view.value
                return container
            }

            preference[view.preferenceKey] = unwrap(view: view)
        }

        preference.forEach { (key, value) in
            @MainActor func unwrap<T: PreferenceKey>(
                key: T.Type,
                container newValue: Any
            ) {
                let newValue = newValue as! PreferenceContainer<T>
                let (key, existingValue) = self.preference[
                    newValue.preferenceKey,
                    default: (newValue.type, PreferenceContainer(type: newValue.type))
                ] as! (T.Type,  PreferenceContainer<T>)

                existingValue.value = newValue.value
                self.preference[newValue.preferenceKey] = (key, existingValue)
            }

            unwrap(key: value.0, container: value.1)
        }
    }

}
