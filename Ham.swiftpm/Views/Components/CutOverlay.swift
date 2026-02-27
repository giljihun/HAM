//
//  CutOverlay.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Full-screen "CUT!" overlay — shown when overacting level reaches cut threshold.

import SwiftUI

struct CutOverlay: View {
    let feedback: String
    let onRetry: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    private let s = Theme.scale

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 32 * s) {
                Spacer()

                Text("CUT!")
                    .font(.system(size: 56 * s, weight: .black))
                    .foregroundStyle(Theme.systemRed)

                Text(feedback)
                    .font(Theme.isPad ? .title3 : .body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * s)

                Spacer()

                HStack(spacing: 16 * s) {
                    Button(action: onRetry) {
                        Text("Retry")
                            .font(Theme.isPad ? .title3.bold() : .headline)
                            .foregroundStyle(Theme.gold)
                            .frame(maxWidth: .infinity)
                            .padding(14 * s)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.corner)
                                    .stroke(Theme.gold, lineWidth: 1)
                            )
                    }

                    Button(action: onSkip) {
                        Text("Skip")
                            .font(Theme.isPad ? .title3.bold() : .headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(14 * s)
                            .background(Theme.gold)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    }
                }
                .padding(.horizontal, Theme.padH)
                .padding(.bottom, 32 * s)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                appeared = true
            }
        }
    }
}
