import Foundation
#if os(macOS)
import AppKit
#endif

struct RootView<T: View>: View {
    let rootView: () -> T
    let exit: @Sendable () -> Void

    var body: some View {
        VStack {
            rootView()
        }
        .environment(\.exit, exit)
    }
}

@MainActor
public class Application {
    let node: Node
    let window: Window
    let control: Control
    let renderer: Renderer

    private var arrowKeyParser = KeyParser()

    private var invalidatedNodes: [Node] = []
    private var updateScheduled = false

    private var exit: (
        stream: AsyncStream<Void>,
        continuation: AsyncStream<Void>.Continuation
    )


    public init<I: View>(
        rootView: @escaping @autoclosure () -> I,
        fileHandle: FileHandle = .standardOutput
    ) {
        self.exit = AsyncStream.makeStream()

        self.node = Node(
            node: ComposedView(
                view: RootView(
                    rootView: rootView,
                    exit: { [continuation = exit.continuation] in
                        continuation.finish()
                    }
                )
            )
        )

        node.build()

        // Implicit top-level VStackControl
        control = node.control(at: 0)
        node.mergePreferences()

        window = Window()
        window.addControl(control)

        window.firstResponder = control.firstSelectableElement
        window.firstResponder?.becomeFirstResponder()

        renderer = Renderer(layer: window.layer, fileHandle: fileHandle)
        window.layer.renderer = renderer

        node.application = self
        renderer.application = self
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
        updateWindowSize()
        node.mergePreferences()
        control.layout(size: window.layer.frame.size)
        renderer.draw()
    }

    public func start() async throws {
        setup()

        let sigwinchTask = Task { @MainActor in
            for try await _ in sigwinch {
                self.handleWindowSizeChange()
            }
        }

        let keyInputTask = Task {
            for try await key in KeyParser() {
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
                    exit.continuation.finish()
                default:
                    break
                }
            }
        }

        for try await _ in exit.stream {
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

        if window.firstResponder?.firstSelectableElement !== window.firstResponder {
            window.firstResponder?.resignFirstResponder()
        }

        invalidatedNodes = []
        node.mergePreferences()

        control.layout(size: window.layer.frame.size)
        renderer.update()
    }

    private func handleWindowSizeChange() {
        MainActor.assumeIsolated {
            updateWindowSize()
            control.layer.invalidate()
            update()
        }
    }

    func updateWindowSize() {
        var size = winsize()
        guard ioctl(
            renderer.fileHandle.fileDescriptor, UInt(TIOCGWINSZ), &size
        ) == 0,
              size.ws_col > 0, size.ws_row > 0 else {
            assertionFailure("Could not get window size")
            return
        }
        window.layer.frame.size = Size(width: Extended(Int(size.ws_col)), height: Extended(Int(size.ws_row)))
        renderer.setCache()
    }
}
