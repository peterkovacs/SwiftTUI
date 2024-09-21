//#if os(macOS)
//import Foundation
//import Combine
//
//extension View {
//    func setupObservedObjectProperties(node: Node) {
//        for (label, value) in Mirror(reflecting: self).children {
//            if let label, let observedObject = value as? AnyObservedObject {
//                node.subscriptions[label] = observedObject.subscribe {
//                    node.root.application?.invalidateNode(node)
//                }
//            }
//        }
//    }
//}
//#endif

import Observation

extension View {
    func observe<T>(node: Node,  _ changes: () -> T ) {
        withObservationTracking(changes) { @MainActor in
            node.root.application?.invalidateNode(node)
        }
    }
}
