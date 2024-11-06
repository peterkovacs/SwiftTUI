import Foundation
import CUnicode

public struct Key: Sendable, Equatable {
    public let key: Value
    public let modifiers: Modifiers

    init(_ key: Value, modifiers: Modifiers = []) {
        self.key = key
        self.modifiers = modifiers
        self.normalize()
    }

    public enum Value: Sendable, Hashable, ExpressibleByUnicodeScalarLiteral {
        public init(unicodeScalarLiteral value: UnicodeScalar) {
            self = .char(value)
        }

        public typealias ExtendedGraphemeClusterLiteralType = Character

        public typealias UnicodeScalarLiteralType = UnicodeScalar

        case char(Unicode.Scalar)
        case up, down, left, right
        case home, end, pageUp, pageDown
        case insert, backspace
        case f1,  f2,  f3,  f4,  f5,  f6,  f7,  f8,  f9,  f10,
             f11, f12, f13, f14, f15, f16, f17, f18, f19, f20


        // MARK: Key Aliases
        static let nul: Self     = "\u{0}"
        static let soh: Self     = "\u{1}"
        static let stx: Self     = "\u{2}"
        static let etx: Self     = "\u{3}"
        static let eot: Self     = "\u{4}"
        static let enq: Self     = "\u{5}"
        static let ack: Self     = "\u{6}"
        static let bel: Self     = "\u{7}"
        static let bs: Self      = "\u{8}"
        static let tab: Self     = "\u{9}"
        static let newLine: Self = "\u{a}"
        static let vt: Self      = "\u{b}"
        static let np: Self      = "\u{c}"
        static let enter: Self   = "\u{d}"
        static let so: Self      = "\u{e}"
        static let si: Self      = "\u{f}"
        static let dle: Self     = "\u{10}"
        static let dc1: Self     = "\u{11}"
        static let dc2: Self     = "\u{12}"
        static let dc3: Self     = "\u{13}"
        static let dc4: Self     = "\u{14}"
        static let nak: Self     = "\u{15}"
        static let syn: Self     = "\u{16}"
        static let etb: Self     = "\u{17}"
        static let can: Self     = "\u{18}"
        static let em: Self      = "\u{19}"
        static let sub: Self     = "\u{1a}"
        static let escape: Self  = "\u{1b}"
        static let fs: Self      = "\u{1c}"
        static let gs: Self      = "\u{1d}"
        static let rs: Self      = "\u{1e}"
        static let us: Self      = "\u{1f}"
        static let space: Self   = " "
        static let delete: Self  = "\u{7f}"
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

    var isControl: Bool {
        switch key {
        case .nul, .soh, .stx, .etx, .eot, .enq, .ack, .bel, .bs, .tab, .newLine,
             .vt, .np, .enter, .so, .si, .dle, .dc1, .dc2, .dc3, .dc4, .nak,
             .syn, .etb, .can, .em, .sub, .fs, .gs, .rs, .us, .delete:
            return true
        default:
            return false
        }
    }

    private mutating func normalize() {
        switch (key, modifiers) {
        case ("@", .ctrl):     self = .init("\u{0}")
        case ("a", .ctrl):     self = .init("\u{1}")
        case ("b", .ctrl):     self = .init("\u{2}")
        case ("c", .ctrl):     self = .init("\u{3}")
        case ("d", .ctrl):     self = .init("\u{4}")
        case ("e", .ctrl):     self = .init("\u{5}")
        case ("f", .ctrl):     self = .init("\u{6}")
        case ("g", .ctrl):     self = .init("\u{7}")
        case ("h", .ctrl):     self = .init("\u{8}")
        case ("i", .ctrl):     self = .init("\u{9}")
        case ("j", .ctrl):     self = .init("\u{a}")
        case ("k", .ctrl):     self = .init("\u{b}")
        case ("l", .ctrl):     self = .init("\u{c}")
        case ("m", .ctrl):     self = .init("\u{d}")
        case ("n", .ctrl):     self = .init("\u{e}")
        case ("o", .ctrl):     self = .init("\u{f}")
        case ("p", .ctrl):     self = .init("\u{10}")
        case ("q", .ctrl):     self = .init("\u{11}")
        case ("r", .ctrl):     self = .init("\u{12}")
        case ("s", .ctrl):     self = .init("\u{13}")
        case ("t", .ctrl):     self = .init("\u{14}")
        case ("u", .ctrl):     self = .init("\u{15}")
        case ("v", .ctrl):     self = .init("\u{16}")
        case ("w", .ctrl):     self = .init("\u{17}")
        case ("x", .ctrl):     self = .init("\u{18}")
        case ("y", .ctrl):     self = .init("\u{19}")
        case ("z", .ctrl):     self = .init("\u{1a}")
        case ("[", .ctrl):     self = .init("\u{1b}")
        case ("\\", .ctrl):    self = .init("\u{1c}")
        case ("]", .ctrl):     self = .init("\u{1d}")
        case ("^", .ctrl):     self = .init("\u{1e}")
        case ("_", .ctrl):     self = .init("\u{1f}")
        case ("?", .ctrl):     self = .init("\u{7f}")
        default: break
        }
    }
}

public actor KeyParser: AsyncSequence {
    enum State {
        case initial
        case escapeSequence(String, Task<Void, Error>)
    }

    var state: State = .initial
    var fileHandle: FileHandle

    public init(fileHandle: consuming FileHandle = .standardInput) {
        self.state = .initial
        self.fileHandle = fileHandle
    }

    // MARK: AsyncSequence

    public typealias Element = Key
    public nonisolated func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(owner: self)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let owner: KeyParser
        var iter: AsyncThrowingStream<Key, Error>.AsyncIterator? = nil

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
    private var bytes: AsyncThrowingStream<UInt8, Error> {
        AsyncThrowingStream<UInt8, Error> { [fileHandle] continuation in
            fileHandle.readabilityHandler = { (fileHandle) in
                for byte in fileHandle.availableData {
                    continuation.yield(byte)
                }
            }

            continuation.onTermination = { termination in
                fileHandle.readabilityHandler = nil
            }
        }
    }

    enum DecodingError: Error {
        case invalidUTF8Encoding
    }

    // Normally you could just do `bytes.asyncScalars`, but since
    // this is only available on macOS, implementing our own.
    private var unicodeScalars: AsyncThrowingStream<Unicode.Scalar, Error> {
        let stream = AsyncThrowingStream<Unicode.Scalar, Error>.makeStream()

        enum State {
            case initial
            case parsing(Int32, [UInt8])
        }

        let task = Task {
            var state = State.initial
            do {
                for try await byte in bytes {
                    switch state {
                    case .initial:
                        let len = utf8_len(byte)
                        guard len > 0 else {
                            stream.continuation.finish(
                                throwing: DecodingError.invalidUTF8Encoding
                            )
                            return
                        }
                        guard len > 1 else {
                            stream.continuation.yield(.init(byte))
                            continue
                        }

                        state = .parsing(len, [byte])
                    case .parsing(let len, var array):
                        array.append(byte)

                        if array.count == len {
                            let codePoint = to_codepoint(array)
                            guard codePoint >= 0, let scalar = UnicodeScalar(codePoint) else {
                                stream.continuation.finish(
                                    throwing: DecodingError.invalidUTF8Encoding
                                )
                                return
                            }

                            stream.continuation.yield(scalar)
                            state = .initial
                        } else {
                            state = .parsing(len, array)
                        }
                    }
                }
            } catch {
                stream.continuation.finish(throwing: error)
            }
        }

        stream.continuation.onTermination = { termination in
            if case .cancelled = termination {
                task.cancel()
            }
        }

        return stream.stream
    }

    private func parse() -> AsyncThrowingStream<Key, Error> {
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

        return stream.stream
    }

    nonisolated static private let mapping: [String: Key] = [
        // //    Arrow keys
        "\u{1b}[A":    Key(.up),
        "\u{1b}[B":    Key(.down),
        "\u{1b}[C":    Key(.right),
        "\u{1b}[D":    Key(.left),

        "\u{1b}[1;2A": Key(.up,    modifiers: .shift),
        "\u{1b}[1;2B": Key(.down,  modifiers: .shift),
        "\u{1b}[1;2C": Key(.right, modifiers: .shift),
        "\u{1b}[1;2D": Key(.left,  modifiers: .shift),

        "\u{1b}[OA":   Key(.up,    modifiers: .shift), // DECCKM
        "\u{1b}[OB":   Key(.down,  modifiers: .shift), // DECCKM
        "\u{1b}[OC":   Key(.right, modifiers: .shift), // DECCKM
        "\u{1b}[OD":   Key(.left,  modifiers: .shift), // DECCKM

        "\u{1b}[a":    Key(.up,    modifiers: .shift), // urxvt
        "\u{1b}[b":    Key(.down,  modifiers: .shift), // urxvt
        "\u{1b}[c":    Key(.right, modifiers: .shift), // urxvt
        "\u{1b}[d":    Key(.left,  modifiers: .shift), // urxvt

        "\u{1b}[1;3A": Key(.up,    modifiers: .alt),
        "\u{1b}[1;3B": Key(.down,  modifiers: .alt),
        "\u{1b}[1;3C": Key(.right, modifiers: .alt),
        "\u{1b}[1;3D": Key(.left,  modifiers: .alt),

        "\u{1b}[1;4A": Key(.up,    modifiers: [.shift, .alt]),
        "\u{1b}[1;4B": Key(.down,  modifiers: [.shift, .alt]),
        "\u{1b}[1;4C": Key(.right, modifiers: [.shift, .alt]),
        "\u{1b}[1;4D": Key(.left,  modifiers: [.shift, .alt]),

        "\u{1b}[1;5A": Key(.up,    modifiers: .ctrl),
        "\u{1b}[1;5B": Key(.down,  modifiers: .ctrl),
        "\u{1b}[1;5C": Key(.right, modifiers: .ctrl),
        "\u{1b}[1;5D": Key(.left,  modifiers: .ctrl),

        "\u{1b}[Oa":   Key(.up,    modifiers: [.ctrl, .alt]),    // urxvt
        "\u{1b}[Ob":   Key(.down,  modifiers: [.ctrl, .alt]),  // urxvt
        "\u{1b}[Oc":   Key(.right, modifiers: [.ctrl, .alt]), // urxvt
        "\u{1b}[Od":   Key(.left,  modifiers: [.ctrl, .alt]),  // urxvt

        "\u{1b}[1;6A": Key(.up,    modifiers: [.ctrl, .shift]),
        "\u{1b}[1;6B": Key(.down,  modifiers: [.ctrl, .shift]),
        "\u{1b}[1;6C": Key(.right, modifiers: [.ctrl, .shift]),
        "\u{1b}[1;6D": Key(.left,  modifiers: [.ctrl, .shift]),

        "\u{1b}[1;7A": Key(.up,    modifiers: [.ctrl, .alt]),
        "\u{1b}[1;7B": Key(.down,  modifiers: [.ctrl, .alt]),
        "\u{1b}[1;7C": Key(.right, modifiers: [.ctrl, .alt]),
        "\u{1b}[1;7D": Key(.left,  modifiers: [.ctrl, .alt]),

        "\u{1b}[1;8A": Key(.up,    modifiers: [.ctrl, .shift, .alt]),
        "\u{1b}[1;8B": Key(.down,  modifiers: [.ctrl, .shift, .alt]),
        "\u{1b}[1;8C": Key(.right, modifiers: [.ctrl, .shift, .alt]),
        "\u{1b}[1;8D": Key(.left,  modifiers: [.ctrl, .shift, .alt]),

        // Miscellaneous keys
        "\u{1b}[Z":    Key(.tab, modifiers: .shift),

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
            // log("yield: \(Key(.char(character)))")
            continuation.yield(Key(.char(character)))
        }

        func yield(string: String) {
            for char in string.unicodeScalars { yield(character: char) }
        }

        for try await character in unicodeScalars {
            switch (state, character) {
            case (.initial, "\u{1b}"):
                // We received an escape (^[) character, we need to wait a small amount of time for the next character to come in
                // before we emit an escape key that was received.
                state = .escapeSequence(
                    String(character),
                    timeout(yielding: String(character))
                )

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
