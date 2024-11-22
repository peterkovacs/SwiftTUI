public extension View {
    func task(_ action: @escaping () async -> Void) -> some View {
        return TaskView(content: self, action: action)
    }
}

private struct TaskView<Content: View>: View, PrimitiveView, ModifierView {
    let content: Content
    let action: () async -> Void

    static var size: Int? { Content.size }

    func buildNode(_ node: Node) {
        node.addNode(at: 0, Node(node: content.view))
    }

    func updateNode(_ node: Node) {
        node.view = self
        node.children[0].update(using: content.view)
    }

    func passControl(_ control: Control, node: Node) -> Control {
        if let taskControl = control.parent { return taskControl }
        let taskControl = TaskControl(action: action)
        taskControl.addSubview(control, at: 0)
        return taskControl
    }

    @MainActor private class TaskControl: Control {
        var action: () async -> Void
        var task: Task<Void, Never>? = nil

        init(action: @escaping () async -> Void) {
            self.action = action
            self.task = nil
        }

        deinit {
            task?.cancel()
        }

        override func size(proposedSize: Size) -> Size {
            children[0].size(proposedSize: proposedSize)
        }

        override func layout(size: Size) {
            super.layout(size: size)
            children[0].layout(size: size)

            if task == nil {
                task = Task { [action] in await action() }
            }
        }
    }
}
