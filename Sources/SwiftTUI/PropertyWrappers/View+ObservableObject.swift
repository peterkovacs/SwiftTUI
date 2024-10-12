import Observation

func observe<T>(node: Node,  _ changes: () -> T ) -> T {
    withObservationTracking(changes) {
        MainActor.assumeIsolated {
            node.root.application?.invalidateNode(node)
        }
    }
}
