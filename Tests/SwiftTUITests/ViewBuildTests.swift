import Testing
@testable import SwiftTUI

@MainActor
@Suite("ViewBuildTests")
struct ViewBuildTests {
    @Test func fromApplication() throws {
        struct MyView: View {
            var body: some View {
                Text("Hello World")
            }
        }

        let (application, _) = try drawView(MyView())
        #expect(application.node.treeDescription ==
            """
            → ComposedView<RootView<MyView>>
              → SetEnvironment<VStack<MyView>, @MainActor @Sendable () -> ()>
                → VStack<MyView>
                  → ComposedView<MyView>
                    → Text
            """)

        #expect(application.control.treeDescription ==
            """
            → VStackControl
              → TextControl
            """)

    }

    @Test func VStack_TupleView2() throws {
        struct MyView: View {
            var body: some View {
                VStack {
                    Text("One")
                    Text("Two")
                }
            }
        }

        let node = Node(view: MyView().view, parent: nil)
        #expect(
            node.control(at: 0).treeDescription ==
            """
            → VStackControl
              → TextControl
              → TextControl
            """
        )
    }

    @Test func Conditional_VStack() throws {
        struct MyView: View {
            @State var value = true

            var body: some View {
                if value {
                    VStack {
                        Text("One")
                    }
                } else {
                    Text("Two")
                }
            }
        }

        do {
            let node = Node(view: MyView().view, parent: nil)
            #expect(
                node.control(at: 0).treeDescription ==
            """
            → VStackControl
              → TextControl
            """
            )
        }

        do {
            let node = Node(view: MyView(value: false).view, parent: nil)
            #expect(
                node.control(at: 0).treeDescription ==
            """
            → TextControl
            """
            )
        }
    }
}
