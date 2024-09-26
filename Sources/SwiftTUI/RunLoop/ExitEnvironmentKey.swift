//
//  Environment.swift
//  SwiftTUI
//
//  Created by Peter Kovacs on 9/26/24.
//

private struct ExitEnvironmentKey: EnvironmentKey {
    static var defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    /// Used to shutdown the application.
    public var exit: @MainActor () -> Void {
        get { self[ExitEnvironmentKey.self] }
        set { self[ExitEnvironmentKey.self] = newValue }
    }
}
