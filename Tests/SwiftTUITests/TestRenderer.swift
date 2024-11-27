@testable import SwiftTUI

class TestRenderer: Renderer {
    var cache: CellGrid<Cell?>
    var window: Window
    var layer: Layer { window.layer }
    var size: Size
    weak var application: Application?

    init(size: Size) {
        self.window = Window()
        self.cache = .init(repeating: nil, size: size)
        self.size = size
        self.window.layer.renderer = self
        self.window.layer.frame.size = size
    }

    func setSize() {
        layer.frame.size = size
        cache = .init(repeating: nil, size: size)
    }
    
    func scheduleUpdate() {
        application?.scheduleUpdate()
    }
    
    func update() {
        if let invalidated = layer.invalidated {
            draw(rect: invalidated)
            layer.invalidated = nil
        }
    }
    
    func draw(rect: Rect? = nil) {
        if rect == nil { layer.invalidated = nil }
        let rect = rect ?? Rect(position: .zero, size: layer.frame.size)
        guard rect.size.width > 0, rect.size.height > 0 else {
            assertionFailure("Trying to draw in empty rect")
            return
        }

        for line in rect.minLine.intValue...rect.maxLine.intValue {
            for column in rect.minColumn.intValue...rect.maxColumn.intValue {
                let position = Position(column: Extended(column), line: Extended(line))
                cache[position] = layer.cell(at: position)
            }
        }
    }
    
    func stop() {
        // noop
    }

    var description: String {
        draw(rect: nil)
        return cache.map { $0?.char ?? " " }.description
    }
}
