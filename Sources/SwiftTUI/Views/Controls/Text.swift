import Foundation

public struct Text: View, PrimitiveView {
    private var text: String?
    
    private var attributedText: AttributedString?
    
    @Environment(\.foregroundColor) private var foregroundColor: Color
    @Environment(\.bold) private var bold: Bool
    @Environment(\.italic) private var italic: Bool
    @Environment(\.underline) private var underline: Bool
    @Environment(\.strikethrough) private var strikethrough: Bool
    
    public init(_ text: String) {
        self.text = text
    }
    
    public init(_ attributedText: AttributedString) {
        self.attributedText = attributedText
    }
    
    static var size: Int? { 1 }
    
    func buildNode(_ node: Node) {
        observe(node: node) {
            setupEnvironmentProperties(node: node)
            node.control = TextControl(
                text: text,
                attributedText: attributedText,
                foregroundColor: foregroundColor,
                bold: bold,
                italic: italic,
                underline: underline,
                strikethrough: strikethrough
            )
        }
    }
    
    func updateNode(_ node: Node) {
        observe(node: node) {
            setupEnvironmentProperties(node: node)
            node.view = self
            let control = node.control as! TextControl
            control.text = text
            control.attributedText = attributedText
            control.foregroundColor = foregroundColor
            control.bold = bold
            control.italic = italic
            control.underline = underline
            control.strikethrough = strikethrough
            control.layer.invalidate()
        }
    }
    
    private class TextControl: Control {
        var text: String?
        
        var attributedText: AttributedString?

        var foregroundColor: Color
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var strikethrough: Bool
        
        init(
            text: String?,
            attributedText: AttributedString?,
            foregroundColor: Color,
            bold: Bool,
            italic: Bool,
            underline: Bool,
            strikethrough: Bool
        ) {
            self.text = text
            self.attributedText = attributedText
            self.foregroundColor = foregroundColor
            self.bold = bold
            self.italic = italic
            self.underline = underline
            self.strikethrough = strikethrough
        }
        
        override func size(proposedSize: Size) -> Size {
            return Size(width: Extended(characterCount), height: 1)
        }
        
        override func cell(at position: Position) -> Cell? {
            guard position.line == 0 else { return nil }
            guard position.column < Extended(characterCount) else { return .init(char: " ") }

            if let attributedText {
                let characters = attributedText.characters
                let i = characters.index(characters.startIndex, offsetBy: position.column.intValue)
                let char = attributedText[i ..< characters.index(after: i)]
                let cellAttributes = CellAttributes(
                    bold: char.bold ?? bold,
                    italic: char.italic ?? italic,
                    underline: char.underline ?? underline,
                    strikethrough: char.strikethrough ?? strikethrough,
                    inverted: char.inverted ?? false
                )
                return Cell(
                    char: char.characters[char.startIndex],
                    foregroundColor: char.foregroundColor ?? foregroundColor,
                    backgroundColor: char.backgroundColor,
                    attributes: cellAttributes
                )
            }

            if let text {
                let cellAttributes = CellAttributes(
                    bold: bold,
                    italic: italic,
                    underline: underline,
                    strikethrough: strikethrough
                )
                return Cell(
                    char: text[text.index(text.startIndex, offsetBy: position.column.intValue)],
                    foregroundColor: foregroundColor,
                    attributes: cellAttributes
                )
            }

            return nil
        }
        
        private var characterCount: Int {
            if let attributedText {
                return attributedText.characters.count
            }
            return text?.count ?? 0
        }
    }
}
