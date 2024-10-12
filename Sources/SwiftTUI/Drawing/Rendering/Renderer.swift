import Foundation

@MainActor
class Renderer {
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

    init(layer: Layer) {
        self.layer = layer
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
    }
}

internal func write(_ str: String) {
    str.withCString { _ = write(STDOUT_FILENO, $0, strlen($0)) }
}
