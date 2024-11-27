public struct CellGrid<Element> {
    var elements: [Element]
    public var size: Size

    public init(
        repeating element: Element,
        size: Size
    ) {
        self.elements = .init(repeating: element, count: size.width.intValue * size.height.intValue)
        self.size = size
    }

    init<Seq: Sequence>(
        _ input: Seq,
        size: Size
    ) where Seq.Element == Element {
        self.elements = Array(input)
        self.size = size

        assert(size.width.intValue * size.height.intValue == elements.count)
    }

    public func isValid(_ coord: Position) -> Bool {
        return (
            coord.column < size.width &&
            coord.column >= 0 &&

            coord.line < size.height &&
            coord.line >= 0
        )
    }

    public subscript(_ coord: Position) -> Element {
        _read {
            let p = coord
            assert(isValid(coord), "coordinate out of bounds")
            yield elements[(p.line * size.width + p.column).intValue]
        }

        _modify {
            let p = coord
            yield &elements[(p.line * size.width + p.column).intValue]
        }
    }
}

extension CellGrid: Sequence {
    public struct CoordinateIterator: Sequence, IteratorProtocol {
        let size: Size
        var coordinate: Position

        public mutating func next() -> Position? {
            if coordinate.column >= size.width {
                coordinate = .init(column: 0, line: coordinate.line + 1) }
            if coordinate.line >= size.height { return nil }
            defer { coordinate.column += 1 }

            return coordinate
        }
    }

    public struct RowIterator: Sequence, IteratorProtocol {
        let size: Size
        var coordinate: Position

        public mutating func next() -> Position? {
            if coordinate.column >= size.width { return nil }
            defer { coordinate.column += 1 }

            return coordinate
        }
    }

    public struct ColumnIterator: Sequence, IteratorProtocol {
        let size: Size
        var coordinate: Position

        public mutating func next() -> Position? {
            if coordinate.line >= size.height { return nil }
            defer { coordinate.line += 1 }

            return coordinate
        }
    }

    public struct Iterator: IteratorProtocol {
        let grid: CellGrid
        var iterator: CoordinateIterator

        public mutating func next() -> Element? {
            guard let coordinate = iterator.next() else { return nil }
            return grid[ coordinate ]
        }
    }

    public func makeIterator() -> Iterator {
        .init(grid: self, iterator: indices)
    }

    public var indices: CoordinateIterator {
        return CoordinateIterator(size: size, coordinate: .zero)
    }

    public func map<U>(_ f: (Element) throws -> U) rethrows -> CellGrid<U> {
        return try CellGrid<U>(elements.map(f), size: size)
    }

    public func flatMap<U>(_ f: (Element) throws -> U?) rethrows -> CellGrid<U>? {
        let elements = try self.elements.compactMap(f)
        guard elements.count == self.elements.count else { return nil }
        return CellGrid<U>(elements, size: size)
    }
}


extension CellGrid: Equatable where Element: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        guard lhs.size == rhs.size else { return false }
        return lhs.elementsEqual(rhs)
    }
}

extension CellGrid: CustomStringConvertible where Element: CustomStringConvertible {
    public var description: String {
        var result = ""

        for y in 0..<size.height.intValue {
            for x in 0..<size.width.intValue {
                result.append(self[.init(column: Extended(x), line: Extended(y))].description)
            }

            result.append("\n")
        }

        return result
    }
}

extension CellGrid: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(
            indices.map { self[$0] }
        )
    }
}
