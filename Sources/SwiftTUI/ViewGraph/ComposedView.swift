import Foundation

/// This wraps a composed (user-defined) view, so that it can be used in a view graph node.
@MainActor
struct ComposedView<I: View>: GenericView {
    let view: I
    
    func buildNode(_ node: Node) {
        view.setupStateProperties(node: node)
        view.setupEnvironmentProperties(node: node)
        
        withObservationTracking {
            node.addNode(at: 0, Node(view: view.body.view))
        } onChange: { @MainActor in
            node.root.application?.invalidateNode(node)
        }
        
    }
    
    func updateNode(_ node: Node) {
        withObservationTracking {
            view.setupStateProperties(node: node)
            view.setupEnvironmentProperties(node: node)
            node.view = self
            
            node.children[0].update(using: view.body.view)
        } onChange: { @MainActor in
            node.root.application?.invalidateNode(node)
        }
    }
    
    static var size: Int? {
        I.Body.size
    }
}
