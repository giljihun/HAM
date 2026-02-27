//
//  AppConfig.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Global app configuration — locale and shared settings.

import Foundation

@Observable
final class AppConfig {
    static let shared = AppConfig()

    var locale: String { "en-US" }
}
