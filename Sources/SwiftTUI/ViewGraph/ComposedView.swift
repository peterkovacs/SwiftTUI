import Foundation

/// This wraps a composed (user-defined) view, so that it can be used in a view graph node.
@MainActor
struct ComposedView<I: View>: GenericView {
    let view: I
    
    func buildNode(_ node: Node) {
        view.setupStateProperties(node: node)
        view.setupEnvironmentProperties(node: node)

        let child = withObservationTracking {
            Node(view: view.body.view, parent: node)
        } onChange: {
            MainActor.assumeIsolated {
                node.invalidate()
            }
        }

        node.addNode(at: 0, child)
    }
    
    func updateNode(_ node: Node) {
        view.setupStateProperties(node: node)
        view.setupEnvironmentProperties(node: node)
        node.view = self

        let newView = withObservationTracking {
            view.body.view
        } onChange: {
            MainActor.assumeIsolated {
                node.invalidate()
            }
        }

        node.children[0].update(using: newView)
    }
    
    static var size: Int? {
        I.Body.size
    }
}
