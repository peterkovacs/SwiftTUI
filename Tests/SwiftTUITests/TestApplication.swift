//
//  TestApplication.swift
//  SwiftTUI
//
//  Created by Peter Kovacs on 10/24/24.
//
@testable import SwiftTUI

class TestApplication: Application {
    override func updateWindowSize() {
        window.layer.frame.size = .init(
            width: 100, height: 100
        )
        renderer.setCache()
    }

}
