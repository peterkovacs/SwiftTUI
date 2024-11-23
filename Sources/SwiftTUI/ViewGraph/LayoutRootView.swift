import Foundation

/// Stacks and lists are layout roots. A layout root is responsible for setting
/// up and handling changes in the controls in the view. Because view graph
/// nodes aren't fully built when they are created, it can also do that lazily.
@MainActor
protocol LayoutRootView {
    func insertControl(at index: Int, node: Node)
    func removeControl(at index: Int, node: Node)
}

extension LayoutRootView {
    func insertControl(at index: Int, node: Node) {
        node.control?.addSubview(node.children[0].control(at: index), at: index)
    }

    func removeControl(at index: Int, node: Node) {
        node.control?.removeSubview(at: index)
    }
}
