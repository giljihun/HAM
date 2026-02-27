//
//  Theme.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Design tokens — colors, adaptive scaling (iPhone=1.0, iPad=1.4), and layout constants.

import SwiftUI

enum Theme {
    static let bg = Color.black
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let gold = Color(red: 0.83, green: 0.66, blue: 0.26)
    static let goldDim = Color(red: 0.65, green: 0.55, blue: 0.24)
    static let systemRed = Color(red: 1, green: 0.27, blue: 0.23)
    static let systemGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let systemOrange = Color(red: 1, green: 0.62, blue: 0.04)

    static let isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    static let scale: CGFloat = isPad ? 1.4 : 1.0

    static let padH: CGFloat = isPad ? 48 : 24
    static let padV: CGFloat = isPad ? 40 : 24
    static let corner: CGFloat = isPad ? 20 : 12
}
