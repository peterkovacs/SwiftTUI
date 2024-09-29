import Foundation
#if os(macOS)
import AppKit
#endif
import Combine

@MainActor
public class Application {
    private let node: Node
    private let window: Window
    private let control: Control
    private let renderer: Renderer

    private var arrowKeyParser = KeyParser()

    private var invalidatedNodes: [Node] = []
    private var updateScheduled = false

    public init<I: View>(rootView: I) {
        node = Node(
            view: VStack(
                content: rootView
                    .environment(\.exit, Application.stop)
            ).view
        )
        node.build()

        control = node.control!

        window = Window()
        window.addControl(control)

        window.firstResponder = control.firstSelectableElement
        window.firstResponder?.becomeFirstResponder()

        renderer = Renderer(layer: window.layer)
        window.layer.renderer = renderer

        node.application = self
        renderer.application = self
    }

    private var cancellables = Set<AnyCancellable>()

    private var sigwinch: AsyncStream<Void> {
        let stream = AsyncStream<Void>.makeStream()

        let sigWinChSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
        sigWinChSource.setEventHandler(
            qos: .userInitiated,
            flags: [],
            handler: { [continuation = stream.continuation] in
                continuation.yield()
            }
        )
        sigWinChSource.activate()

        cancellables.insert(
            .init {
                sigWinChSource.cancel()
            }
        )

        return stream.stream
    }

    private func setup() {
        setInputMode()
        updateWindowSize()
        control.layout(size: window.layer.frame.size)
        renderer.draw()
    }

    public func start() async throws {
        setup()

        Task { @MainActor in
            for try await _ in sigwinch {
                self.handleWindowSizeChange()
            }
        }

        for try await key in await KeyParser() {
            if window.firstResponder?.handle(key: key) == true {
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
                Self.stop()
            default:
                break
            }
        }
    }

    private static var terminalAttributes: termios?
    public func setInputMode() {
        var tattr = termios()
        tcgetattr(STDIN_FILENO, &tattr)

        if Self.terminalAttributes == nil {
            Self.terminalAttributes = tattr
        }

        //   ECHO: Stop the terminal from displaying pressed keys.
        // ICANON: Disable canonical ("cooked") input mode. Allows us to read inputs
        //         byte-wise instead of line-wise.
        //   ISIG: Disable signals for Ctrl-C (SIGINT) and Ctrl-Z (SIGTSTP), so we
        //         can handle them as "normal" escape sequences.
        // IEXTEN: Disable input preprocessing. This allows us to handle Ctrl-V,
        //         which would otherwise be intercepted by some terminals.
        tattr.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)

        //   IXON: Disable software control flow. This allows us to handle Ctrl-S
        //         and Ctrl-Q.
        //  ICRNL: Disable converting carriage returns to newlines. Allows us to
        //         handle Ctrl-J and Ctrl-M.
        // BRKINT: Disable converting sending SIGINT on break conditions. Likely has
        //         no effect on anything remotely modern.
        //  INPCK: Disable parity checking. Likely has no effect on anything
        //         remotely modern.
        // ISTRIP: Disable stripping the 8th bit of characters. Likely has no effect
        //         on anything remotely modern.
        tattr.c_iflag &= ~tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)

        // Disable output processing. Common output processing includes prefixing
        // newline with a carriage return.
        tattr.c_oflag &= ~tcflag_t(OPOST)

        // Set the character size to 8 bits per byte. Likely has no effect on
        // anything remotely modern.
        tattr.c_cflag &= ~tcflag_t(CS8)

        // from <termios.h>
        // #define VMIN            16      /* !ICANON */
        // #define VTIME           17      /* !ICANON */
        tattr.c_cc.16 = 0
        tattr.c_cc.17 = 0

        tcsetattr(STDIN_FILENO, TCSAFLUSH, &tattr);
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
            Task { self.update() }
        }
    }

    private func update() {
        updateScheduled = false

        for node in invalidatedNodes {
            node.update(using: node.view)
        }
        invalidatedNodes = []

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

    private func updateWindowSize() {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0,
              size.ws_col > 0, size.ws_row > 0 else {
            assertionFailure("Could not get window size")
            return
        }
        window.layer.frame.size = Size(width: Extended(Int(size.ws_col)), height: Extended(Int(size.ws_row)))
        renderer.setCache()
    }

    private static func stop() {
        MainActor.assumeIsolated {
            write(EscapeSequence.disableAlternateBuffer)
            write(EscapeSequence.showCursor)

            if var attributes = Self.terminalAttributes {
                tcsetattr(STDIN_FILENO, TCSAFLUSH, &attributes);
                // Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
            }

            exit(0)
        }
    }
}
