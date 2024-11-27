public extension View {
    /// When a child element has focus and does not handle a keyPress itself, the `action` method will be invoked whenever the specified `key` is pressed.
    ///
    /// Keys are normalized into their simplest format. There are some combinations that are impossible to recognize.
    ///
    /// - Parameters:
    ///   - key: The key combination to recognize.
    ///   - action: The method to invoke when the key combination is recongized.
    func onKeyPress(_ key: Key, action: @escaping () -> Void) -> some View {
        KeyPressView(content: self) { k in
            guard key == k else { return false }
            action()
            return true
        }
    }

    /// When a child element has focus and does not handle a keyPress itself, the `action` method will be invoked with the key that was pressed..
    ///
    /// Keys are normalized into their simplest format. If the `action` method returns `false` then `onKeyPress` methods  further up the view graph will be invoked.
    ///
    /// - Parameters:
    ///   - action: The method to invoke when a key combination is recongized. This method should return `true` if the key press has been handled.
    func onKeyPress(action: @escaping (Key) -> Bool) -> some View {
        KeyPressView(content: self, action: action)
    }
}

struct KeyPressView<Content: View>: View, PrimitiveView, ModifierView {
    let content: Content
    let action: (Key) -> Bool

    static var size: Int? { Content.size }

    func buildNode(_ node: Node) {
        node.addNode(at: 0, .init(view: content.view, parent: node))
    }

    func updateNode(_ node: Node) {
        node.view = self
        node.children[0].update(using: content.view)
    }

    func passControl(_ control: Control, node: Node) -> Control {
        if let parent = control.parent { return parent }
        let keyPressControl = KeyPressControl(
            action: action
        )

        keyPressControl.addSubview(control, at: 0)
        return keyPressControl
    }

    @MainActor class KeyPressControl: Control {
        let action: (Key) -> Bool

        init(action: @escaping (Key) -> Bool) {
            self.action = action
        }

        override func handle(key: Key) -> Bool {
            return action(key)
        }
    }
}
