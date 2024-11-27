import Foundation

@MainActor
public struct GeometryReader<Content: View>: View, PrimitiveView {
    let content: (Size) -> Content

    public init(@ViewBuilder content: @escaping (Size) -> Content) {
        self.content = content
    }

    @State private var geometry: Size = Size(width: 1, height: 1)

    static var size: Int? { 1 }

    func buildNode(_ node: Node) {
        setupStateProperties(node: node)
        let control = GeometryReaderControl(geometry: _geometry)
        let child = Node(view: VStack(content: content(geometry)), parent: node)

        control.addSubview(child.control(at: 0), at: 0)
        node.addNode(at: 0, child)
        node.control = control
    }

    func updateNode(_ node: Node) {
        setupStateProperties(node: node)
        node.view = self
        node.children[0].update(using: VStack(content: content(geometry)))
    }

    @MainActor
    private class GeometryReaderControl: Control {
        let geometry: State<Size>

        init(geometry: State<Size>) {
            self.geometry = geometry
        }

        override func size(proposedSize: Size) -> Size {
            return proposedSize
        }

        override func layout(size: Size) {
            super.layout(size: size)
            self.children[0].layout(size: size)
            if geometry.wrappedValue != size {
                geometry.wrappedValue = size
            }
        }
    }
}
