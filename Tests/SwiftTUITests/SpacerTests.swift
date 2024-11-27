

import Testing
@testable import SwiftTUI

@MainActor
struct SpacerTests {
    @Test func expandsToFillHStack() throws {
        struct MyView: View {
            var body: some View {
                HStack {
                    Text("A")
                    Spacer()
                    Text("B")
                }
                .frame(width: 100, height: 1)
            }
        }

        let (view, _) = try drawView(MyView(), size: .init(width: 100, height: 1))

        #expect((view.renderer as! TestRenderer).description == "A\(String(repeating: " ", count: 98))B\n")
    }

    @Test func expandsToFillVStack() throws {
        struct MyView: View {
            var body: some View {
                VStack {
                    Text("A")
                    Spacer()
                    Text("B")
                }
                .frame(width: 1, height: 100)
            }
        }

        let (view, _) = try drawView(MyView(), size: .init(width: 1, height: 100))

        #expect((view.renderer as! TestRenderer).description == "A\n\(String(repeating: " \n", count: 98))B\n")
    }
}
