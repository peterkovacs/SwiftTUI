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

    init(view: GenericView, parent: Node?) {
        self.parent = parent
        self.preference = [:]
        self.state = .init(node: self)
        self.view = view
        view.buildNode(self)
    }

    func update(using observing: GenericView) {
        observing.updateNode(self)
        self.view = observing
    }

    func invalidate() {
        root.application?.invalidateNode(self)
    }

    var root: Node { parent?.root ?? self }

    /// The total number of controls in the node.
    /// The node does not need to be fully built for the size to be computed.
    var size: Int {
        if let size = type(of: view).size { return size }
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

    // MARK: - Changing nodes

    func addNode(at index: Int, _ node: Node) {
        children.insert(node, at: index)

        for i in index ..< children.count {
            children[i].index = i
        }

        for i in 0 ..< node.size {
            insertControl(at: node.offset + i)
        }
    }

    func replaceNode(at index: Int, with node: Node) {
        removeNode(at: index)
        addNode(at: index, node)
    }

    func removeNode(at index: Int) {
        for i in (0 ..< children[index].size).reversed() {
            removeControl(at: children[index].offset + i)
        }

        children[index].parent = nil
        children.remove(at: index)
        for i in index ..< children.count {
            children[i].index = i
        }
    }

    // MARK: - Container data source

    func control(at offset: Int) -> Control {
        // If looking for control 0 and we have a control, then we're at the right place.
        if offset == 0, let control = self.control { return control }

        var i = 0
        for child in children {
            let size = child.size

            // if offset - i is within this child, then we're in the right place.
            if (offset - i) < size {

                // Recurse: Find the (offset - i)th control in the child node.
                let control = child.control(at: offset - i)

                // Here we've got the correct child control.
                // If this node represents a modifier view, then we want to build a
                // control that contains the child control and return that.
                if let modifier = self.view as? ModifierView {
                    return modifier.passControl(control, node: self)
                }

                // Otherwise, we return the child control directly.
                return control
            }

            // Skip over this child's controls, incrementing by its size.
            i += size
        }

        fatalError("Out of bounds: A child reported a size that does not match the number of controls it contains.")
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
