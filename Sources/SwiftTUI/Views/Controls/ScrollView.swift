import Foundation

/// Automatically scrolls to the currently active control. The content needs to contain controls
/// such as buttons to scroll to.
public struct ScrollView<Content: View>: View, PrimitiveView {
    let content: VStack<Content>

    public init(@ViewBuilder _ content: () -> Content) {
        self.content = VStack(content: content())
    }

    static var size: Int? { 1 }

    func buildNode(_ node: Node) {
        node.addNode(at: 0, Node(view: content.view))
        let control = ScrollControl()
        control.contentControl = node.children[0].control(at: 0)
        control.addSubview(control.contentControl, at: 0)
        node.control = control
    }

    func updateNode(_ node: Node) {
        node.view = self
        node.children[0].update(using: content.view)
    }

    // TODO: This is a perfect place to extend Focus control and only handle keys when focused. At the moment, not sure this will work at all since it doesn't have focus.
    // When the scroll view has focus, then it should be scrollable using the standard keys
    //
    private class ScrollControl: Control {
        var contentControl: Control!
        var contentOffset: Extended = 0
        var contentSize: Size = .zero

        override func handle(key: Key) -> Bool {
            switch key {
            case .init(.up):
                if contentOffset > -contentSize.height { return false }
                contentOffset -= 1
                return true

            case .init(.down):
                if contentOffset < contentSize.height { return false }
                contentOffset += 1
                return true

            case .init("p", modifiers: .ctrl):
                if contentOffset - layer.frame.size.height / 2 > -contentSize.height { return false }
                contentOffset -= layer.frame.size.height / 2
                return true

            case .init("n", modifiers: .ctrl):
                if contentOffset + layer.frame.size.height / 2 > contentSize.height { return false }
                contentOffset += layer.frame.size.height / 2
                return true

            case .init(.pageUp):
                if contentOffset - layer.frame.size.height > -contentSize.height { return false }
                contentOffset -= layer.frame.size.height - 1
                return true
                
            case .init(.pageDown):
                if contentOffset  + layer.frame.size.height < contentSize.height { return false }
                contentOffset += layer.frame.size.height - 1
                return true

            case .init(.home):
                if contentOffset > -contentSize.height { return false }
                contentOffset = -contentSize.height
                return true
                
            case .init(.end):
                if contentOffset < contentSize.height - layer.frame.size.height { return false }
                contentOffset = contentSize.height - layer.frame.size.height
                return true

            default:
                return false
            }
        }

        override func layout(size: Size) {
            super.layout(size: size)
            // TODO: What about contents that are very wide?
            contentSize = contentControl.size(proposedSize: .zero)
            contentControl.layout(size: contentSize)
            contentControl.layer.frame.position.line = -contentOffset
        }

        override func scroll(to position: Position) {
            let destination = position.line - contentControl.layer.frame.position.line
            guard layer.frame.size.height > 0 else { return }
            if contentOffset > destination {
                contentOffset = destination
            } else if contentOffset < destination - layer.frame.size.height + 1 {
                contentOffset = destination - layer.frame.size.height + 1
            }
        }
    }
}
