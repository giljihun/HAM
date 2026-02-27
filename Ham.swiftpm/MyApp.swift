//
//  MyApp.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// App entry point. Sets dark mode as the default color scheme.

import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
