import Foundation

public struct OptionalView<Wrapped: View>: View, PrimitiveView, GenericView {
    let content: Wrapped?

    static var size: Int? {
        if Wrapped.size == 0 { return 0 }
        return nil
    }

    func buildNode(_ node: Node) {
        if let content {
            node.addNode(at: 0, Node(view: content.view))
        }
    }

    func updateNode(_ node: Node) {
        let last = node.view as! Self
        node.view = self
        switch (last.content, content) {
        case (.none, .none):
            break
        case (.none, .some(let newValue)):
            node.addNode(at: 0, Node(view: newValue.view))
        case (.some, .none):
            node.removeNode(at: 0)
        case (.some, .some(let newValue)):
            node.children[0].update(using: newValue.view)
        }
    }
}
