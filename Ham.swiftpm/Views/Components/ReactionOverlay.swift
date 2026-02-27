//
//  ReactionOverlay.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Director's thought bubble overlay — shows hints at caution/warning levels.

import SwiftUI

struct ReactionOverlay: View {
    let show: Bool
    let text: String

    private let s = Theme.scale

    var body: some View {
        VStack {
            if show {
                directorBubble
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -8)),
                        removal: .opacity
                    ))
                    .padding(.top, 90 * s)
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.4), value: show)
        .allowsHitTesting(false)
    }

    private var directorBubble: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(Theme.isPad ? .body : .caption)
                .italic()
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14 * s)
                .padding(.vertical, 10 * s)
                .background(
                    RoundedRectangle(cornerRadius: 12 * s)
                        .fill(.black.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12 * s)
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        )
                )

            HStack(spacing: 3) {
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 6 * s, height: 6 * s)
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 4 * s, height: 4 * s)
            }
        }
    }
}
