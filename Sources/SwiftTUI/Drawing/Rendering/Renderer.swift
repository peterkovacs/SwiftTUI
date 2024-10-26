import Foundation

@MainActor
class Renderer {
    var fileHandle: FileHandle
    var layer: Layer

    /// Even though we only redraw invalidated parts of the screen, terminal
    /// drawing is currently still slow, as it involves moving the cursor
    /// position and printing a character there.
    /// This cache stores the screen content to see if printing is necessary.
    private var cache: [[Cell?]] = []

    /// The current cursor position, which might need to be updated before
    /// printing.
    private var currentPosition: Position = .zero {
        didSet {
            if oldValue != currentPosition {
                write(EscapeSequence.moveTo(currentPosition))
            }
        }
    }

    private var currentForegroundColor: Color? = nil {
        didSet {
            if oldValue != currentForegroundColor {
                write((currentForegroundColor ?? .default).foregroundEscapeSequence)
            }
        }
    }
    private var currentBackgroundColor: Color? = nil {
        didSet {
            if oldValue != currentBackgroundColor {
                write((currentBackgroundColor ?? .default).backgroundEscapeSequence)
            }
        }
    }

    private var currentAttributes = CellAttributes() {
        didSet {
            if oldValue.bold != currentAttributes.bold {
                write(currentAttributes.bold
                      ? EscapeSequence.enableBold
                      : EscapeSequence.disableBold)
            }
            if oldValue.italic != currentAttributes.italic {
                write(currentAttributes.italic
                      ? EscapeSequence.enableItalic
                      : EscapeSequence.disableItalic)
            }
            if oldValue.underline != currentAttributes.underline {
                write(currentAttributes.underline
                      ? EscapeSequence.enableUnderline
                      : EscapeSequence.disableUnderline)
            }
            if oldValue.strikethrough != currentAttributes.strikethrough {
                write(currentAttributes.strikethrough
                      ? EscapeSequence.enableStrikethrough
                      : EscapeSequence.disableStrikethrough)
            }
            if oldValue.inverted != currentAttributes.inverted {
                write(currentAttributes.inverted
                      ? EscapeSequence.enableInverted
                      : EscapeSequence.disableInverted)
            }
        }
    }

    weak var application: Application?

    init(layer: Layer, fileHandle: FileHandle = .standardOutput) {
        self.layer = layer
        self.fileHandle = fileHandle
        setCache()
        setup()
    }

    /// Draw only the invalidated part of the layer.
    func update() {
        if let invalidated = layer.invalidated {
            draw(rect: invalidated)
            layer.invalidated = nil
        }
    }

    func setCache() {
        cache = .init(repeating: .init(repeating: nil, count: layer.frame.size.width.intValue), count: layer.frame.size.height.intValue)
    }

    /// Draw a specific area, or the entire layer if the area is nil.
    func draw(rect: Rect? = nil) {
        if rect == nil { layer.invalidated = nil }
        let rect = rect ?? Rect(position: .zero, size: layer.frame.size)
        guard rect.size.width > 0, rect.size.height > 0 else {
            assertionFailure("Trying to draw in empty rect")
            return
        }
        for line in rect.minLine.intValue ... rect.maxLine.intValue {
            for column in rect.minColumn.intValue ... rect.maxColumn.intValue {
                let position = Position(column: Extended(column), line: Extended(line))
                if let cell = layer.cell(at: position) {
                    drawPixel(cell, at: Position(column: Extended(column), line: Extended(line)))
                }
            }
        }
    }

    private func drawPixel(_ cell: Cell, at position: Position) {
        guard position.column >= 0, position.line >= 0, position.column < layer.frame.size.width, position.line < layer.frame.size.height else {
            return
        }
        if cache[position.line.intValue][position.column.intValue] != cell {
            cache[position.line.intValue][position.column.intValue] = cell

            self.currentPosition = position
            self.currentForegroundColor = cell.foregroundColor
            self.currentBackgroundColor = cell.backgroundColor
            self.currentAttributes = cell.attributes

            write(String(cell.char))
            self.currentPosition.column += 1
        }
    }

    private func setup() {
        write(EscapeSequence.enableAlternateBuffer)
        write(EscapeSequence.clearScreen)
        write(EscapeSequence.moveTo(currentPosition))
        write(EscapeSequence.hideCursor)

        setInputMode()
    }

    func stop() {
        write(EscapeSequence.disableAlternateBuffer)
        write(EscapeSequence.showCursor)

        if var terminalAttributes {
            tcsetattr(fileHandle.fileDescriptor, TCSAFLUSH, &terminalAttributes);
            // Fix for: https://github.com/rensbreur/SwiftTUI/issues/25
        }
    }

    var terminalAttributes: termios?
    private func setInputMode() {
        var tattr = termios()
        tcgetattr(fileHandle.fileDescriptor, &tattr)

        if terminalAttributes == nil {
            terminalAttributes = tattr
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

        tcsetattr(fileHandle.fileDescriptor, TCSAFLUSH, &tattr);
    }


    func write(_ str: String) {
        let cStr = str.utf8CString
        cStr.withUnsafeBufferPointer { ptr in
            _ = unistd.write(fileHandle.fileDescriptor, ptr.baseAddress, ptr.count)
        }
    }
}
