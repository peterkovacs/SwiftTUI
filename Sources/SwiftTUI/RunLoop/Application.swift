import Foundation
#if os(macOS)
import AppKit
#endif

@MainActor
public class Application {
    private let node: Node
    private let window: Window
    private let control: Control
    private let renderer: Renderer

    private var arrowKeyParser = KeyParser()

    private var invalidatedNodes: [Node] = []
    private var updateScheduled = false
    private var parser: KeyParser

    public init<I: View>(rootView: I) {
        self.parser = KeyParser()

        node = Node(view: VStack(content: rootView).view)
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

    private func setup() {
        //        let stdInSource = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
        //        stdInSource.setEventHandler(
        //            qos: .default,
        //            flags: [],
        //            handler: self.handleInput
        //        )
        //        stdInSource.activate()
        //        self.stdInSource = stdInSource

//        let sigWinChSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
//        sigWinChSource.setEventHandler(
//            qos: .default,
//            flags: [],
//            handler: self.handleWindowSizeChange
//        )
//        sigWinChSource.activate()
//
//        signal(SIGINT, SIG_IGN)
//        let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
//        sigIntSource.setEventHandler(
//            qos: .default,
//            flags: [],
//            handler: self.stop
//        )
//        sigIntSource.activate()

        setInputMode()
        updateWindowSize()
        control.layout(size: window.layer.frame.size)
        renderer.draw()
    }

    public func start() async throws {
        setup()

        for try await key in await parser {
            switch key {
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
            case .ctrlD:
                stop()
            default:
                if case .char(let value) = key.key {
                    await { @MainActor in
                        window.firstResponder?.handleEvent(.init(value))
                    }()
                }
            }
            //            if key == .down {
            //                if let next = window.firstResponder?.selectableElement(below: 0) {
            //                    becomeResponder(next)
            //                }
            //            } else if key == .up {
            //                if let next = window.firstResponder?.selectableElement(above: 0) {
            //                    becomeResponder(next)
            //                }
            //            } else if key == .right {
            //                if let next = window.firstResponder?.selectableElement(rightOf: 0) {
            //                    becomeResponder(next)
            //                }
            //            } else if key == .left {
            //                if let next = window.firstResponder?.selectableElement(leftOf: 0) {
            //                    becomeResponder(next)
            //                }
            //            }
            //        } else if char == ASCII.EOT {
            //            stop()
            //        } else {
            //            MainActor.assumeIsolated {
            //                window.firstResponder?.handleEvent(char)
            //            }
            //
            //        }
        }
    }

    private var originalTattr: termios = .init()
    private func setInputMode() {
        tcgetattr(STDIN_FILENO, &originalTattr)
        var tattr = originalTattr

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

//    private func handleInput() async throws {
//
////        for char in string {
////            // Replace this with a better Focus system.
////            if arrowKeyParser.parse(character: char) {
////                guard let key = arrowKeyParser.arrowKey else { continue }
////                arrowKeyParser.arrowKey = nil
////                if key == .down {
////                    if let next = window.firstResponder?.selectableElement(below: 0) {
////                        becomeResponder(next)
////                    }
////                } else if key == .up {
////                    if let next = window.firstResponder?.selectableElement(above: 0) {
////                        becomeResponder(next)
////                    }
////                } else if key == .right {
////                    if let next = window.firstResponder?.selectableElement(rightOf: 0) {
////                        becomeResponder(next)
////                    }
////                } else if key == .left {
////                    if let next = window.firstResponder?.selectableElement(leftOf: 0) {
////                        becomeResponder(next)
////                    }
////                }
////            } else if char == ASCII.EOT {
////                stop()
////            } else {
////                MainActor.assumeIsolated {
////                    window.firstResponder?.handleEvent(char)
////                }
////            }
////        }
//    }

    func invalidateNode(_ node: Node) {
        invalidatedNodes.append(node)
        scheduleUpdate()
    }

    func scheduleUpdate() {
        if !updateScheduled {
            Task { self.update() }
            updateScheduled = true
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

    private func stop() {
        MainActor.assumeIsolated {
            renderer.stop()
            resetInputMode() // Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
            exit(0)
        }
    }

    /// Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
    private func resetInputMode() {
        // Reset ECHO and ICANON values:
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTattr);
    }

}
