import Testing
@testable import SwiftTUI

@MainActor
@Suite("KeyPress") struct KeyPressTests {
    let ctrlL = "\u{c}"
    let ctrlD = "\u{4}"
    let shiftTab = "\u{1b}[Z"

    @Test func actionAreNotInvokedWhenNothingIsFocused() async throws {
        struct MyView: View {
            let action: () -> Void
            var body: some View {
                Text("This is some text")
                    .onKeyPress(Key("l", modifiers: .ctrl)) { action() }
            }
        }

        var called = false
        let (application, fileHandle) = try drawView(MyView() { called = true })

        #expect(application.window.firstResponder is KeyPressView<Text>.KeyPressControl?)

        let task = Task {
            try await application.start()
        }

        Task {
            try fileHandle.write(contentsOf: Key("l", modifiers: .ctrl).bytes())
            try fileHandle.write(contentsOf: Key("d", modifiers: .ctrl).bytes())
            try fileHandle.close()
        }

        _ = try await task.value
        #expect(!called)
    }

    @Test func invokesActionWhenTextFieldIsFocused() async throws {
        struct MyView: View {
            @State var text = ""
            let action: () -> Void
            var body: some View {
                TextField($text) { _ in }
                    .onKeyPress(.init("l", modifiers: .ctrl)) { action() }
            }
        }

        var called = false
        let (application, fileHandle) = try drawView(MyView() { called = true })

        #expect(application.window.firstResponder is TextField.TextFieldControl)

        let task = Task {
            try await application.start()
        }

        try fileHandle.write(contentsOf: Key("l", modifiers: .ctrl).bytes())
        try fileHandle.write(contentsOf: Key("d", modifiers: .ctrl).bytes())
        try fileHandle.close()

        _ = try await task.value
        #expect(called)
    }

    @Test func participatesInFocusChain() async throws {
        struct MyView: View {
            @State var text1 = "1"
            @State var text2 = "2"

            let action: () -> Void
            let outerAction: () -> Void
            var body: some View {
                VStack {
                    TextField($text1) { _ in }
                        .onKeyPress(Key("l", modifiers: .ctrl)) { action() }
                    TextField($text2) { _ in }
                }
                .onKeyPress(Key("l", modifiers: .ctrl), action: outerAction)
            }
        }

        var called = 0, outerCalled = 0

        let (application, fileHandle) = try drawView(
            MyView() {
                called += 1
            } outerAction: {
                outerCalled += 1
            }
        )

        let firstResponder = application.window.firstResponder as? TextField.TextFieldControl
        #expect(firstResponder?.text == "1")

        let task = Task {
            try await application.start()
        }

        try fileHandle.write(contentsOf: Array("asdf".utf8))
        try fileHandle.write(contentsOf: Key("l", modifiers: .ctrl).bytes())
        try fileHandle.write(contentsOf: Key(.tab).bytes())

        try await Task.sleep(for: .milliseconds(100))
        #expect(firstResponder?.text == "1asdf")
        #expect(called == 1)

        let secondResponder = application.window.firstResponder as? TextField.TextFieldControl
        #expect(secondResponder?.text == "2")

        try fileHandle.write(contentsOf: Array("asdf".utf8))
        try fileHandle.write(contentsOf: Key("l", modifiers: .ctrl).bytes())
        try fileHandle.write(contentsOf: Key(.tab, modifiers: .shift).bytes())

        try fileHandle.write(contentsOf: Array("asdf".utf8))
        try fileHandle.write(contentsOf: Key("l", modifiers: .ctrl).bytes())
        try fileHandle.write(contentsOf: Key("d", modifiers: .ctrl).bytes())
        try fileHandle.close()

        _ = try await task.value
        #expect(firstResponder?.text == "1asdfasdf")
        #expect(secondResponder?.text == "2asdf")
        #expect(called == 2)
        #expect(outerCalled == 1)
    }
}
