//
//  TaskTests.swift
//  SwiftTUI
//
//  Created by Peter Kovacs on 10/23/24.
//

import Testing
@testable import SwiftTUI

@Suite("Task")
@MainActor
struct TaskTests {
    @Test func taskExecutes() async throws {
        struct MyView: View {
            var called: () -> Void
            var body: some View {
                Text("Hello")
                    .task(called)
            }
        }

        var called = false

        let node = try drawView(
            MyView {
                called = true
            }
        )

        #expect(called == false)
        try await Task.sleep(for: .milliseconds(25))
        #expect(called == true)

        _ = node
    }

    @Test func taskCancels() async throws {
        struct MyView: View {
            @State var count = 0
            var called: () -> Void

            var body: some View {
                if count < 3 {
                    Text("Hello \(count)")
                        .task {
                            do {
                                while !Task.isCancelled {
                                    count += 1
                                    try await Task.sleep(
                                        for: .milliseconds(10)
                                    )
                                }
                            } catch is CancellationError {
                                called()
                            } catch {
                            }
                        }
                }
            }
        }

        var called = false

        let node = try drawView(
            MyView {
                called = true
            }
        )

        #expect(called == false)
        try await Task.sleep(for: .milliseconds(200))
        #expect(called == true)

        _ = node
    }


    func drawView<V: View>(_ view: V) throws -> Application {
        let application = TestApplication(
            rootView: view,
            fileHandle: try .init(
                forWritingTo: .init(filePath: "/dev/null")
            )
        )

        application.setup()

        return application
    }
}
