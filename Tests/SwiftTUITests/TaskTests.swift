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
            @State var visible = true
            var called: () -> Void

            var body: some View {
                if visible {
                    Text("Hello")
                        .task {
                            visible = false

                            do {
                                try await Task.sleep(
                                        for: .seconds(1)
                                    )
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

        #expect(node.node.treeDescription == """
            → ComposedView<RootView<MyView>>
              → SetEnvironment<VStack<MyView>, @MainActor @Sendable () -> ()>
                → VStack<MyView>
                  → ComposedView<MyView>
                    → OptionalView<TaskView<Text>>
                      → TaskView<Text>
                        → Text
            """)

        #expect(called == false)
        try await Task.sleep(for: .milliseconds(200))
        #expect(called == true)

        #expect(node.node.treeDescription == """
            → ComposedView<RootView<MyView>>
              → SetEnvironment<VStack<MyView>, @MainActor @Sendable () -> ()>
                → VStack<MyView>
                  → ComposedView<MyView>
                    → OptionalView<TaskView<Text>>
            """)

        _ = node
    }

}
