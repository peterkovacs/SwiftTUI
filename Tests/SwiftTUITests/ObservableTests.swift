import Testing
import Observation
@testable import SwiftTUI

@MainActor
@Suite("Observable") struct ObservableTests {
    @Observable class Model {
        var count: Int = 0

        func increment() {
            count += 1
        }
    }

    @Test func testObservableModel() async throws {
        struct MyView: View {
            @State var model: Model

            var body: some View {
                Text("Count: \(model.count)")
                    .task {
                        Task {
                            try await Task.sleep(for: .milliseconds(10))
                            model.increment()
                        }
                    }
            }
        }


        let (app, _) = try drawView(MyView(model: Model()))

        #expect(app.node.treeDescription ==  """
            → ComposedView<RootView<MyView>>
              → SetEnvironment<VStack<MyView>, @MainActor @Sendable () -> ()>
                → VStack<MyView>
                  → ComposedView<MyView>
                    → TaskView<Text>
                      → Text
            """
        )
        #expect((app.node.children[0].children[0].children[0].children[0].children[0].control as? Text.TextControl)?.text == "Count: 0")

        try await Task.sleep(for: .milliseconds(250))
        #expect(app.node.treeDescription ==  """
            → ComposedView<RootView<MyView>>
              → SetEnvironment<VStack<MyView>, @MainActor @Sendable () -> ()>
                → VStack<MyView>
                  → ComposedView<MyView>
                    → TaskView<Text>
                      → Text
            """
        )

        #expect((app.node.children[0].children[0].children[0].children[0].children[0].control as? Text.TextControl)?.text == "Count: 1")
    }

    @Test func testDeeplyNestedObservableModel() async throws {
        struct Subview: View {
            let count: Int

            var body: some View {
                HStack {
                    Text("This is some text.")
                    Spacer()
                    Text("Count: \(count)")
                }
                .padding(1)
                .border()
                .background(.blue)
            }
        }

        struct MyView: View {
            @State var model: Model

            var body: some View {
                VStack {
                    HStack {
                        Subview(count: model.count + 1)
                    }

                    if (model.count > 0) {
                        Subview(count: model.count * 10)
                    }

                    HStack {
                        Subview(count: model.count + 2)
                    }
                }
                .task {
                    try? await Task.sleep(for: .milliseconds(10))
                    model.increment()
                }
            }
        }

        let (app, _) = try drawView(MyView(model: Model()))

        #expect(app.node.extractText() == ["This is some text.", "Count: 1", "This is some text.", "Count: 2"])
        try await Task.sleep(for: .milliseconds(250))
        #expect(
            app.node.extractText() == ["This is some text.", "Count: 2", "This is some text.", "Count: 10", "This is some text.", "Count: 3"]
        )
    }
}

extension Node {
    func extractText() -> [String] {
        if let control = control as? Text.TextControl {
            return [control.text ?? ""]
        } else {
            var result = [] as [String]
            for child in children {
                result.append(contentsOf: child.extractText())
            }
            return result
        }
    }
}
