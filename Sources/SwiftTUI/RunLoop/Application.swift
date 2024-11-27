import Foundation
#if os(macOS)
import AppKit
#endif

@MainActor
public class Application {
    let node: Node
    let control: Control
    let parser: KeyParser
    var renderer: Renderer
    var window: Window { renderer.window }

    private var arrowKeyParser = KeyParser()

    private var invalidatedNodes: [Node] = []
    private var updateScheduled = false

    public convenience init<I: View>(
        rootView: @escaping @autoclosure () -> I
    ) {
        self.init(
            rootView: rootView(),
            renderer: TerminalRenderer(fileHandle: .standardOutput),
            parser: KeyParser(fileHandle: .standardInput)
        )
    }

    struct RootView<T: View>: View {
        let rootView: () -> T
        var body: some View {
            VStack {
                rootView()
            }
        }
    }

    init<I: View>(
        rootView: @escaping @autoclosure () -> I,
        renderer: Renderer,
        parser: KeyParser
    ) {
        self.node = Node(
            view: VStack { rootView() },
            parent: nil
        )

        // control(at: 0) is the implicit top-level VStackControl created in RootView
        self.control = node.control(at: 0)
        self.node.mergePreferences()

        self.parser = parser
        self.renderer = renderer
        self.renderer.window.addControl(self.control)
        self.renderer.window.firstResponder = self.control.firstSelectableElement
        self.renderer.window.firstResponder?.becomeFirstResponder()

        self.node.application = self
        self.renderer.application = self
    }

    private var sigwinch: AsyncStream<Void> {
        let stream = AsyncStream<Void>.makeStream()

        let sigWinChSource = LockIsolated(DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main))
        sigWinChSource.withValue { signal in
            signal.setEventHandler(
                qos: .userInitiated,
                flags: [],
                handler: { [continuation = stream.continuation] in
                    continuation.yield()
                }
            )
            signal.activate() 
        }

        stream.continuation.onTermination = { _ in
            sigWinChSource.withValue { $0.cancel() }
        }

        return stream.stream
    }

    func setup() {
        node.mergePreferences()
        control.layout(size: window.layer.frame.size)
        renderer.draw(rect: nil)
    }

    public func start() async throws {
        setup()

        let sigwinchTask = Task { @MainActor in
            for try await _ in sigwinch {
                self.handleWindowSizeChange()
            }
        }

        let keyInputTask = Task {
            for try await key in parser {
                if window.handle(key: key) {
                    continue
                }

                switch key {
                case Key(.tab):
                    if let next = window.firstResponder?.selectableElement(next: 0) {
                        becomeResponder(next)
                    }
                case Key(.tab, modifiers: .shift):
                    if let next = window.firstResponder?.selectableElement(prev: 0) {
                        becomeResponder(next)
                    }
                case Key(.down):
                    if let next = window.firstResponder?.selectableElement(below: 0) {
                        becomeResponder(next)
                    }
                case Key(.up):
                    if let next = window.firstResponder?.selectableElement(above: 0) {
                        becomeResponder(next)
                    }
                case Key(.right):
                    if let next = window.firstResponder?.selectableElement(rightOf: 0) {
                        becomeResponder(next)
                    }
                case Key(.left):
                    if let next = window.firstResponder?.selectableElement(leftOf: 0) {
                        becomeResponder(next)
                    }
                case Key(.char("d"), modifiers: .ctrl):
                    Exit.exit()
                default:
                    break
                }
            }

            Exit.exit()
        }

        for try await _ in Exit.stream {
            break
        }

        sigwinchTask.cancel()
        keyInputTask.cancel()
        renderer.stop()
    }

    private func becomeResponder(_ control: Control) {
        window.firstResponder?.resignFirstResponder()
        window.firstResponder = control
        window.firstResponder?.becomeFirstResponder()
    }

    func invalidateNode(_ node: Node) {
        invalidatedNodes.append(node)
        scheduleUpdate()
    }

    func scheduleUpdate() {
        if !updateScheduled {
            updateScheduled = true
            Task { @MainActor in self.update() }
        }
    }

    private func update() {
        updateScheduled = false

        for node in invalidatedNodes {
            node.update(using: node.view)
        }

        // TODO: Deal with the fact that a firstResponder (or its chain) may become unfocusable.
//        if window.firstResponder?.isFocusable == false {
//            window.firstResponder?.resignFirstResponder()
//            window.firstResponder = nil
//        }

        invalidatedNodes = []
        node.mergePreferences()

        control.layout(size: window.layer.frame.size)
        renderer.update()
    }

    private func handleWindowSizeChange() {
        MainActor.assumeIsolated {
            renderer.setSize()
            control.layer.invalidate()
            update()
        }
    }
}
