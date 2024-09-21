import Foundation

extension Color: View, PrimitiveView {
    static var size: Int? { 1 }
    
    func buildNode(_ node: Node) {
        withObservationTracking {
            node.control = ColorControl(color: self)
        } onChange: { @MainActor in
            node.root.application?.invalidateNode(node)
        }
    }
    
    func updateNode(_ node: Node) {
        withObservationTracking {
            let last = node.view as! Self
            node.view = self
            if self != last {
                let control = node.control as! ColorControl
                control.color = self
                control.layer.invalidate()
            }
        } onChange: { @MainActor in
            node.root.application?.invalidateNode(node)
        }
    }
    
    private class ColorControl: Control {
        var color: Color
        
        init(color: Color) {
            self.color = color
        }
        
        override func cell(at position: Position) -> Cell? {
            Cell(char: " ", backgroundColor: color)
        }
    }
}
