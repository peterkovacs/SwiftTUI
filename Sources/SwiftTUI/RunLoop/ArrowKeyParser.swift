import Foundation

struct ArrowKeyParser {
    enum ArrowKey {
        case up
        case down
        case right
        case left
    }

    private var partial: Int = 0

    var arrowKey: ArrowKey?

    mutating func parse(character: Character) -> Bool {
        switch (partial, character) {
        case (0, "\u{1b}"):
            partial = 1
            return true
        case (1, "["):
            partial = 2
            return true
        case (2, "A"):
            arrowKey = .up
        case (2, "B"):
            arrowKey = .down
        case (2, "C"):
            arrowKey = .right
        case (2, "D"):
            arrowKey = .left
        default:
            arrowKey = nil
        }

        partial = 0
        return arrowKey != nil
    }

}
