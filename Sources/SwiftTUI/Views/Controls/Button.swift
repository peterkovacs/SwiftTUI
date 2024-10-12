import Foundation

public struct Button<Label: View>: View, PrimitiveView {
    let label: VStack<Label>
    let hover: @MainActor () -> Void
    let action: @MainActor () -> Void

    public init(action: @escaping @MainActor () -> Void, hover: @escaping @MainActor () -> Void = {}, @ViewBuilder label: () -> Label) {
        self.label = VStack(content: label())
        self.action = action
        self.hover = hover
    }
    
    public init(_ text: String, hover: @escaping @MainActor () -> Void = {}, action: @escaping @MainActor () -> Void) where Label == Text {
        self.label = VStack(content: Text(text))
        self.action = action
        self.hover = hover
    }
    
    static var size: Int? { 1 }
    
    func buildNode(_ node: Node) {
        node.addNode(at: 0, Node(observing: label.view))
        let control = ButtonControl(action: action, hover: hover)
        control.label = node.children[0].control(at: 0)
        control.addSubview(control.label, at: 0)
        node.control = control
    }
    
    func updateNode(_ node: Node) {
        node.view = self
        node.children[0].update(using: label.view)
    }
    
    private class ButtonControl: Control {
        var action: @Sendable @MainActor () -> Void
        var hover: @Sendable @MainActor () -> Void
        var label: Control!
        weak var buttonLayer: ButtonLayer?
        
        init(action: @escaping @MainActor () -> Void, hover: @escaping @MainActor () -> Void) {
            self.action = action
            self.hover = hover
        }
        
        override func size(proposedSize: Size) -> Size {
            return label.size(proposedSize: proposedSize)
        }
        
        override func layout(size: Size) {
            super.layout(size: size)
            self.label.layout(size: size)
        }
        
        override func handle(key: Key) -> Bool {
            switch(key.key) {
            case .enter, .space:
                action()
                return true
            default:
                // TODO: Any other keys to handle here?
                break
            }

            return false
        }
        
        override var selectable: Bool { true }
        
        override func becomeFirstResponder() {
            super.becomeFirstResponder()
            buttonLayer?.highlighted = true
            hover()
            layer.invalidate()
        }
        
        override func resignFirstResponder() {
            super.resignFirstResponder()
            buttonLayer?.highlighted = false
            layer.invalidate()
        }
        
        override func makeLayer() -> Layer {
            let layer = ButtonLayer()
            self.buttonLayer = layer
            return layer
        }
    }
    
    private class ButtonLayer: Layer {
        var highlighted = false
        
        override func cell(at position: Position) -> Cell? {
            var cell = super.cell(at: position)
            if highlighted {
                cell?.attributes.inverted.toggle()
            }
            return cell
        }
    }
}
