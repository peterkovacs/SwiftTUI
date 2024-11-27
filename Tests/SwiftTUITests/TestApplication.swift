//
//  TestApplication.swift
//  SwiftTUI
//
//  Created by Peter Kovacs on 10/24/24.
//
@testable import SwiftTUI
import Foundation

class TestApplication: Application {
}

@MainActor
func drawView<V: View>(_ view: V, size: Size = .init(width: 100, height: 100)) throws -> (Application, FileHandle) {
    let (parser, fileHandle) = KeyParser.pipe()
    let application = Application(
        rootView: view,
        renderer: TestRenderer(size: size),
        parser: parser
    )

    application.setup()

    return (application, fileHandle)
}

extension KeyParser {
    static func pipe() -> (parser: KeyParser, fileHandle: FileHandle) {
        let pipe = Pipe()
        let parser = KeyParser(fileHandle: pipe.fileHandleForReading)

        return (parser: parser, fileHandle: pipe.fileHandleForWriting)
    }
}
