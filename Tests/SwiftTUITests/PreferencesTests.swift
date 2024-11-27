//
//  Preferences.swift
//  SwiftTUI
//
//  Created by Peter Kovacs on 10/28/24.
//

import Testing
@testable import SwiftTUI

@Suite("Preferences")
@MainActor
struct PreferencesTests {
    @Test func testMergesPreferences() async throws {
        struct Key: PreferenceKey {
            static var defaultValue: Int = 0

            static func reduce(value: inout Int, nextValue: () -> Int) {
                value += nextValue()
            }
        }

        struct PreferenceView: View {
            var body: some View {
                ChildView(value: 1)
                ChildView(value: 2)
            }
        }

        struct ChildView: View {
            let value: Int

            var body: some View {
                Text("Value: \(value)")
                    .preference(key: Key.self, value: value)
            }
        }

        let (application, _) = try drawView(PreferenceView())
        #expect(application.node.preference.count == 1)
        #expect(Array(application.node.preference.values).first?.1.value as? Int == 3)
    }

    @Test func testOverridesPreferences() async throws {
        struct Key: PreferenceKey {
            static var defaultValue: Int = 0

            static func reduce(value: inout Int, nextValue: () -> Int) {
                value += nextValue()
            }
        }

        struct PreferenceView: View {
            var body: some View {
                ChildView(value: 1)
                ChildView(value: 2)
                    .preference(key: Key.self, value: 10)
            }
        }

        struct ChildView: View {
            let value: Int

            var body: some View {
                Text("Value: \(value)")
                    .preference(key: Key.self, value: value)
            }
        }

        let (application, _) = try drawView(PreferenceView())
        #expect(application.node.preference.count == 1)
        #expect(Array(application.node.preference.values).first?.1.value as? Int == 11)
    }

    @Test func testOnPreferenceChange() async throws {
        struct Key: PreferenceKey {
            static var defaultValue: Int = 0
            static func reduce(value: inout Int, nextValue: () -> Int) {
                value = nextValue()
            }
        }

        var value = [] as [Int]

        struct PreferenceView: View {
            @State var value = 1
            let action: @MainActor @Sendable (Int) -> Void

            var body: some View {
                Text("Value: \(value)")
                    .preference(key: Key.self, value: value)
                    .onPreferenceChange(Key.self, perform: action)
                    .task {
                        value += 1
                    }
            }
        }

        let (application, _) = try drawView(PreferenceView {
            value.append($0)
        })

        #expect(value == [1])
        #expect(application.node.preference.count == 1)
        #expect(Array(application.node.preference.values).first?.1.value as? Int == 1)
        try await Task.sleep(for: .milliseconds(200))
        #expect(value == [1, 2])
        #expect(application.node.preference.count == 1)
        #expect(Array(application.node.preference.values).first?.1.value as? Int == 2)

    }

}
