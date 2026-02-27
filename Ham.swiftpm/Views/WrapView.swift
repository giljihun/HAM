//
//  WrapView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// "That's a wrap!" — cinematic transition screen after all lines are complete.

import SwiftUI

struct WrapView: View {
    var onComplete: () -> Void

    @State private var opacity: Double = 0

    private let s = Theme.scale

    var body: some View {
        VStack(spacing: 16 * s) {
            Spacer()

            Text("That's a wrap!")
                .font(Theme.isPad ? .system(size: 44, weight: .bold) : .largeTitle.bold())
                .foregroundStyle(Theme.gold)

            Spacer()
        }
        .opacity(opacity)
        .task {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
            try? await Task.sleep(for: .seconds(1.5))
            onComplete()
        }
    }
}
