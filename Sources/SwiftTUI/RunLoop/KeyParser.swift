import Foundation
@preconcurrency import Parsing

public struct Key: Sendable, Equatable {
    public let key: Value
    public let modifiers: Modifiers

    init(_ key: Value, modifiers: Modifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    public enum Value: Sendable, Hashable, ExpressibleByExtendedGraphemeClusterLiteral {
        public init(extendedGraphemeClusterLiteral value: Character) {
            self = .char(value.unicodeScalars.first!)
        }
        
        public init(unicodeScalarLiteral value: UnicodeScalar) {
            self = .char(value)
        }
        
        public typealias ExtendedGraphemeClusterLiteralType = Character

        public typealias UnicodeScalarLiteralType = UnicodeScalar

        case char(Unicode.Scalar)
        case up, down, left, right
        case home, end, pageUp, pageDown
        case delete, insert, backspace
        case escape, enter
        case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16, f17, f18, f19, f20

        // MARK: Key Aliases
        static let tab: Self   = .char(.init(9))
        static let space: Self = .char(.init(32))
    }

    public struct Modifiers: Sendable, OptionSet {
        public let rawValue: Int

        public static let shift = Self(rawValue: 1 << 0)
        public static let ctrl = Self(rawValue: 1 << 1)
        public static let alt = Self(rawValue: 1 << 2)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

public actor KeyParser: AsyncSequence {
    enum State {
        case initial
        case escapeSequence(String, Task<Void, Error>)
    }

    var state: State = .initial

    public init() {
        self.state = .initial
    }

    // MARK: AsyncSequence

    public typealias Element = Key
    public nonisolated func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(owner: self)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let owner: KeyParser
        var iter: AsyncThrowingMapSequence<AsyncThrowingStream<Key, Error>, Key>.AsyncIterator? = nil

        init(owner: KeyParser) {
            self.owner = owner
        }

        public mutating func next() async throws -> Key? {
            if iter == nil {
                iter = await owner.parse().makeAsyncIterator()
            }

            return try await iter?.next()
        }
    }

    // MARK: Parse Input

    private nonisolated var bytes: AsyncThrowingStream<UInt8, Error> {
        let stream = AsyncThrowingStream<UInt8, Error>.makeStream()

        FileHandle.standardInput.readabilityHandler = { (fileHandle) in
            for byte in fileHandle.availableData {
                stream.continuation.yield(byte)
            }
        }

        stream.continuation.onTermination = { _ in
            FileHandle.standardInput.readabilityHandler = nil
        }

        return stream.stream
    }

    func parse() -> AsyncThrowingMapSequence<AsyncThrowingStream<Key, Error>, Key> {
        let stream = AsyncThrowingStream<Key, Error>.makeStream()
        let task = Task {
            do {
                try await parse(continuation: stream.continuation)
            } catch {
                stream.continuation.finish(throwing: error)
            }
        }

        stream.continuation.onTermination = { _ in
            task.cancel()
        }

        return stream.stream.map(translate)
    }

    nonisolated func translate(_ key: Key) -> Key {
        switch key {
        case Key(.char(.init(0))):   .init(.char("@"),  modifiers: .ctrl)
        case Key(.char(.init(1))):   .init(.char("a"),  modifiers: .ctrl)
        case Key(.char(.init(2))):   .init(.char("b"),  modifiers: .ctrl)
        case Key(.char(.init(3))):   .init(.char("c"),  modifiers: .ctrl)
        case Key(.char(.init(4))):   .init(.char("d"),  modifiers: .ctrl)
        case Key(.char(.init(5))):   .init(.char("e"),  modifiers: .ctrl)
        case Key(.char(.init(6))):   .init(.char("f"),  modifiers: .ctrl)
        case Key(.char(.init(7))):   .init(.char("g"),  modifiers: .ctrl)
        case Key(.char(.init(8))):   .init(.char("h"),  modifiers: .ctrl)
        case Key(.char(.init(9))):   .init(.char("i"),  modifiers: .ctrl)
        case Key(.char(.init(10))):  .init(.char("j"),  modifiers: .ctrl)
        case Key(.char(.init(11))):  .init(.char("k"),  modifiers: .ctrl)
        case Key(.char(.init(12))):  .init(.char("l"),  modifiers: .ctrl)
        case Key(.char(.init(13))):  .init(.enter)
        case Key(.char(.init(14))):  .init(.char("n"),  modifiers: .ctrl)
        case Key(.char(.init(15))):  .init(.char("o"),  modifiers: .ctrl)
        case Key(.char(.init(16))):  .init(.char("p"),  modifiers: .ctrl)
        case Key(.char(.init(17))):  .init(.char("q"),  modifiers: .ctrl) // not working?
        case Key(.char(.init(18))):  .init(.char("r"),  modifiers: .ctrl)
        case Key(.char(.init(19))):  .init(.char("s"),  modifiers: .ctrl) // not working?
        case Key(.char(.init(20))):  .init(.char("t"),  modifiers: .ctrl)
        case Key(.char(.init(21))):  .init(.char("u"),  modifiers: .ctrl)
        case Key(.char(.init(22))):  .init(.char("v"),  modifiers: .ctrl)
        case Key(.char(.init(23))):  .init(.char("w"),  modifiers: .ctrl)
        case Key(.char(.init(24))):  .init(.char("x"),  modifiers: .ctrl)
        case Key(.char(.init(25))):  .init(.char("y"),  modifiers: .ctrl)
        case Key(.char(.init(26))):  .init(.char("z"),  modifiers: .ctrl) // sigstp
        case Key(.char(.init(27))):  .init(.escape)
        case Key(.char(.init(28))):  .init(.char("\\"), modifiers: .ctrl)
        case Key(.char(.init(29))):  .init(.char("]"),  modifiers: .ctrl)
        case Key(.char(.init(30))):  .init(.char("^"),  modifiers: .ctrl)
        case Key(.char(.init(31))):  .init(.char("_"),  modifiers: .ctrl)
        case Key(.char(.init(127))): .init(.backspace)
        default: key
        }
    }

    nonisolated static private let mapping: [String: Key] = [
        // //    Arrow keys
        "\u{1b}[A": Key(.up),
        "\u{1b}[B": Key(.down),
        "\u{1b}[C": Key(.right),
        "\u{1b}[D": Key(.left),
        "\u{1b}[1;2A": Key(.up, modifiers: .shift),
        "\u{1b}[1;2B": Key(.down, modifiers: .shift),
        "\u{1b}[1;2C": Key(.right, modifiers: .shift),
        "\u{1b}[1;2D": Key(.left, modifiers: .shift),
        "\u{1b}[OA":   Key(.up, modifiers: .shift),    // DECCKM
        "\u{1b}[OB":   Key(.down, modifiers: .shift),  // DECCKM
        "\u{1b}[OC":   Key(.right, modifiers: .shift), // DECCKM
        "\u{1b}[OD":   Key(.left, modifiers: .shift),  // DECCKM
        "\u{1b}[a":    Key(.up, modifiers: .shift),    // urxvt
        "\u{1b}[b":    Key(.down, modifiers: .shift),  // urxvt
        "\u{1b}[c":    Key(.right, modifiers: .shift), // urxvt
        "\u{1b}[d":    Key(.left, modifiers: .shift),  // urxvt
        "\u{1b}[1;3A": Key(.up, modifiers: .alt),
        "\u{1b}[1;3B": Key(.down, modifiers: .alt),
        "\u{1b}[1;3C": Key(.right, modifiers: .alt),
        "\u{1b}[1;3D": Key(.left, modifiers: .alt),

        "\u{1b}[1;4A": Key(.up, modifiers: [.shift, .alt]),
        "\u{1b}[1;4B": Key(.down, modifiers: [.shift, .alt]),
        "\u{1b}[1;4C": Key(.right, modifiers: [.shift, .alt]),
        "\u{1b}[1;4D": Key(.left, modifiers: [.shift, .alt]),

        "\u{1b}[1;5A": Key(.up, modifiers: .ctrl),
        "\u{1b}[1;5B": Key(.down, modifiers: .ctrl),
        "\u{1b}[1;5C": Key(.right, modifiers: .ctrl),
        "\u{1b}[1;5D": Key(.left, modifiers: .ctrl),
        "\u{1b}[Oa":   Key(.up, modifiers: [.ctrl, .alt]),    // urxvt
        "\u{1b}[Ob":   Key(.down, modifiers: [.ctrl, .alt]),  // urxvt
        "\u{1b}[Oc":   Key(.right, modifiers: [.ctrl, .alt]), // urxvt
        "\u{1b}[Od":   Key(.left, modifiers: [.ctrl, .alt]),  // urxvt
        "\u{1b}[1;6A": Key(.up, modifiers: [.ctrl, .shift]),
        "\u{1b}[1;6B": Key(.down, modifiers: [.ctrl, .shift]),
        "\u{1b}[1;6C": Key(.right, modifiers: [.ctrl, .shift]),
        "\u{1b}[1;6D": Key(.left, modifiers: [.ctrl, .shift]),
        "\u{1b}[1;7A": Key(.up, modifiers: [.ctrl, .alt]),
        "\u{1b}[1;7B": Key(.down, modifiers: [.ctrl, .alt]),
        "\u{1b}[1;7C": Key(.right, modifiers: [.ctrl, .alt]),
        "\u{1b}[1;7D": Key(.left, modifiers: [.ctrl, .alt]),
        "\u{1b}[1;8A": Key(.up, modifiers: [.ctrl, .shift, .alt]),
        "\u{1b}[1;8B": Key(.down, modifiers: [.ctrl, .shift, .alt]),
        "\u{1b}[1;8C": Key(.right, modifiers: [.ctrl, .shift, .alt]),
        "\u{1b}[1;8D": Key(.left, modifiers: [.ctrl, .shift, .alt]),

        // Miscellaneous keys
        "\u{1b}[Z": Key(.tab, modifiers: .shift),

        "\u{1b}[2~":   Key(.insert),
        "\u{1b}[3;2~": Key(.insert),                   // differ

        "\u{1b}[3~":   Key(.delete),
        "\u{1b}[3;3~": Key(.delete),                   // differ
        "\u{1b}[3;5~": Key(.delete, modifiers: .ctrl), // differ

        "\u{1b}[5~":   Key(.pageUp),
        "\u{1b}[5;3~": Key(.pageUp, modifiers: .alt),
        "\u{1b}[5;5~": Key(.pageUp, modifiers: .ctrl),
        "\u{1b}[5^":   Key(.pageUp, modifiers: .ctrl), // urxvt
        "\u{1b}[5;7~": Key(.pageUp, modifiers: [.ctrl, .alt]),

        "\u{1b}[6~":   Key(.pageDown),
        "\u{1b}[6;3~": Key(.pageDown, modifiers: .alt),
        "\u{1b}[6;5~": Key(.pageDown, modifiers: .ctrl),
        "\u{1b}[6^":   Key(.pageDown, modifiers: .ctrl), // urxvt
        "\u{1b}[6;7~": Key(.pageDown, modifiers: [.ctrl, .alt]),

        "\u{1b}[1~":   Key(.home),
        "\u{1b}[H":    Key(.home),                     // xterm, lxterm
        "\u{1b}[1;3H": Key(.home, modifiers: .alt),          // xterm, lxterm
        "\u{1b}[1;5H": Key(.home, modifiers: .ctrl),                 // xterm, lxterm
        "\u{1b}[1;7H": Key(.home, modifiers: [.ctrl, .alt]),      // xterm, lxterm
        "\u{1b}[1;2H": Key(.home, modifiers: .shift),                // xterm, lxterm
        "\u{1b}[1;4H": Key(.home, modifiers: [.shift, .alt]),     // xterm, lxterm
        "\u{1b}[1;6H": Key(.home, modifiers: [.ctrl, .shift]),            // xterm, lxterm
        "\u{1b}[1;8H": Key(.home, modifiers: [.ctrl, .shift, .alt]), // xterm, lxterm

        "\u{1b}[4~":   Key(.end),
        "\u{1b}[F":    Key(.end),                     // xterm, lxterm
        "\u{1b}[1;3F": Key(.end, modifiers: .alt),          // xterm, lxterm
        "\u{1b}[1;5F": Key(.end, modifiers: .ctrl),                 // xterm, lxterm
        "\u{1b}[1;7F": Key(.end, modifiers: [.ctrl, .alt]),      // xterm, lxterm
        "\u{1b}[1;2F": Key(.end, modifiers: .shift),                // xterm, lxterm
        "\u{1b}[1;4F": Key(.end, modifiers: [.shift, .alt]),     // xterm, lxterm
        "\u{1b}[1;6F": Key(.end, modifiers: [.ctrl, .shift]),            // xterm, lxterm
        "\u{1b}[1;8F": Key(.end, modifiers: [.ctrl, .shift, .alt]), // xterm, lxterm

        "\u{1b}[7~": Key(.home),          // urxvt
        "\u{1b}[7^": Key(.home, modifiers: .ctrl),      // urxvt
        "\u{1b}[7$": Key(.home, modifiers: .shift),     // urxvt
        "\u{1b}[7@": Key(.home, modifiers: [.ctrl, .shift]), // urxvt

        "\u{1b}[8~": Key(.end),          // urxvt
        "\u{1b}[8^": Key(.end, modifiers: .ctrl),      // urxvt
        "\u{1b}[8$": Key(.end, modifiers: .shift),     // urxvt
        "\u{1b}[8@": Key(.end, modifiers: [.ctrl, .shift]), // urxvt

        // Function keys, Linux console
        "\u{1b}[[A": Key(.f1), // linux console
        "\u{1b}[[B": Key(.f2), // linux console
        "\u{1b}[[C": Key(.f3), // linux console
        "\u{1b}[[D": Key(.f4), // linux console
        "\u{1b}[[E": Key(.f5), // linux console

        // Function keys, X11
        "\u{1b}OP": Key(.f1), // vt100, xterm
        "\u{1b}OQ": Key(.f2), // vt100, xterm
        "\u{1b}OR": Key(.f3), // vt100, xterm
        "\u{1b}OS": Key(.f4), // vt100, xterm

        "\u{1b}[1;3P": Key(.f1, modifiers: .alt), // vt100, xterm
        "\u{1b}[1;3Q": Key(.f2, modifiers: .alt), // vt100, xterm
        "\u{1b}[1;3R": Key(.f3, modifiers: .alt), // vt100, xterm
        "\u{1b}[1;3S": Key(.f4, modifiers: .alt), // vt100, xterm

        "\u{1b}[11~": Key(.f1), // urxvt
        "\u{1b}[12~": Key(.f2), // urxvt
        "\u{1b}[13~": Key(.f3), // urxvt
        "\u{1b}[14~": Key(.f4), // urxvt
        "\u{1b}[15~": Key(.f5), // vt100, xterm, also urxvt

        "\u{1b}[17~": Key(.f6),  // vt100, xterm, also urxvt
        "\u{1b}[18~": Key(.f7),  // vt100, xterm, also urxvt
        "\u{1b}[19~": Key(.f8),  // vt100, xterm, also urxvt
        "\u{1b}[20~": Key(.f9),  // vt100, xterm, also urxvt
        "\u{1b}[21~": Key(.f10), // vt100, xterm, also urxvt

        "\u{1b}[23~": Key(.f11), // vt100, xterm, also urxvt
        "\u{1b}[24~": Key(.f12), // vt100, xterm, also urxvt
        "\u{1b}[25~": Key(.f13), // vt100, xterm, also urxvt
        "\u{1b}[26~": Key(.f14), // vt100, xterm, also urxvt

        "\u{1b}[28~": Key(.f15), // vt100, xterm, also urxvt
        "\u{1b}[29~": Key(.f16), // vt100, xterm, also urxvt

        "\u{1b}[31~": Key(.f17),
        "\u{1b}[32~": Key(.f18),
        "\u{1b}[33~": Key(.f19),
        "\u{1b}[34~": Key(.f20),

        "\u{1b}[1;2P": Key(.f13),
        "\u{1b}[1;2Q": Key(.f14),
        "\u{1b}[1;2R": Key(.f15),
        "\u{1b}[1;2S": Key(.f16),

        "\u{1b}[15;2~": Key(.f17),
        "\u{1b}[17;2~": Key(.f18),
        "\u{1b}[18;2~": Key(.f19),
        "\u{1b}[19;2~": Key(.f20),

        "\u{1b}[15;3~": Key(.f5, modifiers: .alt), // vt100, xterm, also urxvt
        "\u{1b}[17;3~": Key(.f6, modifiers: .alt),  // vt100, xterm
        "\u{1b}[18;3~": Key(.f7, modifiers: .alt),  // vt100, xterm
        "\u{1b}[19;3~": Key(.f8, modifiers: .alt),  // vt100, xterm
        "\u{1b}[20;3~": Key(.f9, modifiers: .alt),  // vt100, xterm
        "\u{1b}[21;3~": Key(.f10, modifiers: .alt), // vt100, xterm

        "\u{1b}[23;3~": Key(.f11, modifiers: .alt), // vt100, xterm
        "\u{1b}[24;3~": Key(.f12, modifiers: .alt), // vt100, xterm
        "\u{1b}[25;3~": Key(.f13, modifiers: .alt), // vt100, xterm
        "\u{1b}[26;3~": Key(.f14, modifiers: .alt), // vt100, xterm

        "\u{1b}[28;3~": Key(.f15, modifiers: .alt), // vt100, xterm
        "\u{1b}[29;3~": Key(.f16, modifiers: .alt), // vt100, xterm

        // Powershell sequences.
        "\u{1b}OA": Key(.up),
        "\u{1b}OB": Key(.down),
        "\u{1b}OC": Key(.right),
        "\u{1b}OD": Key(.left),
    ]

    // All possible valid prefixes of escape sequences.
    nonisolated static private let prefixes = { () -> Set<String> in
        var result = Set<String>()
        for m in mapping.keys {
            var p = ""
            for c in m.dropLast() {
                p.append(String(c))
                result.insert(p)
            }
        }

        return result
    }()

    private func parse(continuation: AsyncThrowingStream<Key, Error>.Continuation) async throws {
        func timeout(yielding: String) -> Task<Void, Error> {
            return Task {
                try await Task.sleep(for: .milliseconds(30))

                if !Task.isCancelled, case .escapeSequence = state {
                    state = .initial
                    yield(string: yielding)
                }
            }
        }

        func yield(character: Unicode.Scalar) {
            continuation.yield(Key(.char(character)))
        }

        func yield(string: String) {
            for char in string.unicodeScalars { yield(character: char) }
        }

        for try await character in bytes.unicodeScalars {
            switch (state, character) {
            case (.initial, "\u{1b}" as Unicode.Scalar):
                // We received an escape (^[) character, we need to wait a small amount of time for the next character to come in
                // before we emit an escape key that was received.
                state = .escapeSequence(String(character), timeout(yielding: String(character)))

            case (.initial, _):
                yield(character: character)

            case (.escapeSequence(var prefix, let task), let chr):
                task.cancel()
                prefix.append(String(chr))

                if Self.prefixes.contains(prefix) {
                    state = .escapeSequence(prefix, timeout(yielding: prefix))
                } else if let key = Self.mapping[prefix] {
                    state = .initial
                    continuation.yield(key)
                } else {
                    state = .initial
                    yield(string: prefix)
                }
            }
        }

    }
}
