import Testing
import Foundation
@testable import SwiftTUI

@MainActor
@Suite("KeyParser")
struct KeyParserTests {
    @Test(
        arguments: [
            ("\u{1b}OA", Key(.up)),
            ("\u{1b}OB", Key(.down)),
            ("\u{1b}OC", Key(.right)),
            ("\u{1b}OD", Key(.left)),

            ("\u{1b}[1;2A", Key(.up, modifiers: .shift)),
            ("\u{1b}[1;2B", Key(.down, modifiers: .shift)),
            ("\u{1b}[1;2C", Key(.right, modifiers: .shift)),
            ("\u{1b}[1;2D", Key(.left, modifiers: .shift)),

            ("\u{1b}[1;5A", Key(.up, modifiers: .ctrl)),
            ("\u{1b}[1;5B", Key(.down, modifiers: .ctrl)),
            ("\u{1b}[1;5C", Key(.right, modifiers: .ctrl)),
            ("\u{1b}[1;5D", Key(.left, modifiers: .ctrl)),

            ("\u{1b}OP", Key(.f1)),
            ("\u{1b}OQ", Key(.f2)),
            ("\u{1b}OR", Key(.f3)),
            ("\u{1b}OS", Key(.f4)),

            ("\u{1b}[15~", Key(.f5)),
            ("\u{1b}[17~", Key(.f6)),
            ("\u{1b}[18~", Key(.f7)),
            ("\u{1b}[19~", Key(.f8)),
            ("\u{1b}[20~", Key(.f9)),
            ("\u{1b}[21~", Key(.f10)),
            ("\u{1b}[23~", Key(.f11)),
            ("\u{1b}[24~", Key(.f12)),
            ("\u{1b}[25~", Key(.f13)),
            ("\u{1b}[26~", Key(.f14)),
            ("\u{1b}[28~", Key(.f15)),
            ("\u{1b}[29~", Key(.f16)),
            ("\u{1b}[31~", Key(.f17)),
            ("\u{1b}[32~", Key(.f18)),
            ("\u{1b}[33~", Key(.f19)),
            ("\u{1b}[34~", Key(.f20)),

            ("\u{1b}[1~", Key(.home)),
            ("\u{1b}[4~", Key(.end)),
            ("\u{1b}[5~", Key(.pageUp)),
            ("\u{1b}[6~", Key(.pageDown)),
        ]
    )
    func parsesEscapeSequences(input: String, expectation: Key) async throws {
        let (parser, fileHandle) = KeyParser.pipe()
        var iterator = parser.makeAsyncIterator()

        Task {
            try fileHandle.write(
                contentsOf: input.data(using: .utf8)!
            )
        }

        let key = try await iterator.next()
        #expect(key == expectation)
    }

    @Test func parsesEscape() async throws {
        let (parser, fileHandle) = KeyParser.pipe()
        var iterator = parser.makeAsyncIterator()

        Task {
            try fileHandle.write(
                contentsOf: "\u{1b}".data(using: .utf8)!
            )
            try await Task.sleep(for: .milliseconds(100))
            try fileHandle.write(
                contentsOf: "[".data(using: .utf8)!
            )

        }

        do {
            let key = try await iterator.next()
            #expect(key == Key(.escape))
        }

        do {
            let key = try await iterator.next()
            #expect(key == Key("["))
        }

    }

    @Test func parsesUnicode() async throws {
        let (parser, fileHandle) = KeyParser.pipe()
        var iterator = parser.makeAsyncIterator()

        Task {
            try fileHandle.write(
                contentsOf: "\u{1f468}".data(using: .utf8)!
            )
        }

        let key = try await iterator.next()
        #expect(key == .init(.char("\u{1f468}")))

    }
}

// Unicode: U+1F468, UTF-8: F0 9F 91 A8
// Unicode: U+1F469, UTF-8: F0 9F 91 A9
