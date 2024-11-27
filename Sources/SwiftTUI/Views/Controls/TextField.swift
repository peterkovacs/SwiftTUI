import Foundation

public struct TextField: View, PrimitiveView {
    public let placeholder: String?
    public let text: Binding<String>
    public let onSubmit: (String) -> Void

    @Environment(\.placeholderColor) private var placeholderColor: Color

    public init(
        _ text: Binding<String>,
        placeholder: String? = nil,
        onSubmit: @escaping (String) -> Void
    ) {
        self.text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    static var size: Int? { 1 }

    func buildNode(_ node: Node) {
        setupEnvironmentProperties(node: node)
        node.control = TextFieldControl(
            text: text,
            placeholder: placeholder ?? "",
            placeholderColor: placeholderColor,
            action: onSubmit
        )
    }

    func updateNode(_ node: Node) {
        setupEnvironmentProperties(node: node)
        node.view = self

        let control = node.control as! TextFieldControl
        control.action = onSubmit
        control.placeholder = placeholder ?? ""
        control.placeholderColor = placeholderColor
    }

    class TextFieldControl: Control {
        @Binding var text: String
        var placeholder: String
        var placeholderColor: Color
        var action: (String) -> Void

        var cursorPosition: String.Index

        init(
            text: Binding<String>,
            placeholder: String,
            placeholderColor: Color,
            action: @escaping (String) -> Void
        ) {
            self.placeholder = placeholder
            self.placeholderColor = placeholderColor
            self.action = action
            self._text = text
            self.cursorPosition = text.wrappedValue.endIndex
        }

        override func size(proposedSize: Size) -> Size {
            return Size(width: Extended(max(text.count, placeholder.count)) + 1, height: 1)
        }

        private func word(before: String.Index) -> String.Index {
            if cursorPosition != text.startIndex {
                guard let endOfWord = text[..<cursorPosition].lastIndex(where: { $0.isNumber || $0.isLetter })
                else { return text.startIndex }

                guard let startOfWord = text[..<endOfWord]
                    .lastIndex(where: { !$0.isNumber && !$0.isLetter })
                else { return text.startIndex }

                return text.index(after: startOfWord)
            }

            return text.startIndex
        }

        private func word(after: String.Index) -> String.Index {
            if cursorPosition != text.endIndex {
                let next = text.index(after: cursorPosition)

                guard let endOfWord = text[next...].firstIndex(where: { !$0.isNumber && !$0.isLetter })
                else { return text.endIndex }

                guard let startOfWord = text[endOfWord...].firstIndex(where: { $0.isNumber || $0.isLetter })
                else { return text.endIndex }

                return startOfWord
            }

            return text.endIndex
        }


        override func handle(key: Key) -> Bool {
            if !text.indices.contains(cursorPosition) {
                cursorPosition = text.endIndex
            }

            switch(key) {
            case Key(.tab), Key(.tab, modifiers: .shift):
                return false

            case Key(.enter):
                action(text)
                self.text = ""
                self.cursorPosition = text.startIndex
                layer.invalidate()
                return true

            case Key(.backspace):
                if !text.isEmpty, cursorPosition != text.startIndex {
                    cursorPosition = text.index(before: cursorPosition)
                    text.remove(at: cursorPosition)
                    layer.invalidate()
                }
                return true

            case Key(.delete):
                if !text.isEmpty, cursorPosition != text.startIndex {
                    cursorPosition = text.index(before: cursorPosition)
                    text.remove(at: cursorPosition)
                    layer.invalidate()
                }
                return true

            case Key(.left), Key("b", modifiers: .ctrl):
                if cursorPosition != text.startIndex {
                    cursorPosition = text.index(before: cursorPosition)
                    layer.invalidate()
                    return true
                }

            case Key(.left, modifiers: .ctrl), Key(.left, modifiers: .alt):
                if cursorPosition != text.startIndex {
                    cursorPosition = word(before: cursorPosition)
                    layer.invalidate()
                    return true
                }

            case Key(.right, modifiers: .ctrl), Key(.right, modifiers: .alt):
                if cursorPosition != text.endIndex {
                    cursorPosition = word(after: cursorPosition)
                    layer.invalidate()
                    return true
                }

            case Key(.right), Key("f", modifiers: .ctrl):
                if cursorPosition != text.endIndex {
                    cursorPosition = text.index(after: cursorPosition)
                    layer.invalidate()
                    return true
                }

            case Key("k", modifiers: .ctrl):
                if cursorPosition != text.endIndex {
                    text.removeSubrange(cursorPosition...)
                    layer.invalidate()
                }
                return true

            case Key("w", modifiers: .ctrl):
                // If there is a whitespace characters to our left, skip over
                // to find the first non-alpha-numeric
                if cursorPosition != text.startIndex {
                    let startOfWord = word(before: cursorPosition)
                    text.removeSubrange(startOfWord..<cursorPosition)
                    cursorPosition = startOfWord

                    layer.invalidate()
                    return true
                }
                return true


            case Key("u", modifiers: .ctrl):
                if !text.isEmpty {
                    text = ""
                    cursorPosition = text.endIndex
                    layer.invalidate()
                }
                return true

            case Key("a", modifiers: .ctrl):
                if cursorPosition != text.endIndex {
                    cursorPosition = text.startIndex
                    layer.invalidate()
                }
                return true

            case Key("e", modifiers: .ctrl):
                if cursorPosition != text.endIndex {
                    cursorPosition = text.endIndex
                    layer.invalidate()
                }
                return true

            case _ where key.modifiers.isEmpty && !key.isControl:

                if case .char(let value) = key.key {
                    text.insert(.init(value), at: cursorPosition)
                    cursorPosition = text.index(after: cursorPosition)
                    layer.invalidate()
                    return true
                }

            default:
                break
            }

            return false
        }

        override func cell(at position: Position) -> Cell? {
            guard position.line == 0 else { return nil }
            if text.isEmpty {
                if position.column.intValue < placeholder.count {
                    let showUnderline = (position.column.intValue == 0) && isFirstResponder
                    let char = placeholder[placeholder.index(placeholder.startIndex, offsetBy: position.column.intValue)]
                    return Cell(
                        char: char,
                        foregroundColor: placeholderColor,
                        attributes: CellAttributes(underline: showUnderline)
                    )
                }
                return .init(char: " ")
            }
            if isFirstResponder, position.column.intValue == text.count, cursorPosition == text.endIndex {
                return Cell(char: " ", attributes: CellAttributes(underline: true))
            }
            guard position.column.intValue < text.count else { return .init(char: " ") }

            let index = text.index(text.startIndex, offsetBy: position.column.intValue)
            return Cell(char: text[index], attributes: .init(underline: isFirstResponder && index == cursorPosition))
        }

        override var selectable: Bool { true }

        override func becomeFirstResponder() {
            super.becomeFirstResponder()
            layer.invalidate()
        }

        override func resignFirstResponder() {
            super.resignFirstResponder()
            layer.invalidate()
        }
    }
}

extension EnvironmentValues {
    public var placeholderColor: Color {
        get { self[PlaceholderColorEnvironmentKey.self] }
        set { self[PlaceholderColorEnvironmentKey.self] = newValue }
    }
}

private struct PlaceholderColorEnvironmentKey: EnvironmentKey {
    static var defaultValue: Color { .default }
}
