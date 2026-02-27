//
//  VoiceMeterView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Real-time 3-channel voice meter — fills bottom-to-top, higher = closer to CUT.
/// Channels: Volume (cyan), Pitch (purple), Face (orange). All values 0~1.

import SwiftUI

struct VoiceMeterView: View {
    let voiceLevel: CGFloat
    let pitchLevel: CGFloat
    var faceLevel: CGFloat? = nil

    private let s = Theme.scale

    var body: some View {
        HStack(spacing: 6 * s) {
            MeterBar(level: voiceLevel, color: .cyan, icon: "🔊")
            MeterBar(level: pitchLevel, color: .purple, icon: "↕️")
            if let face = faceLevel {
                MeterBar(level: face, color: Theme.systemOrange, icon: "🎭")
            }
        }
        .allowsHitTesting(false)
    }
}

/// Individual channel bar — color shifts to red as level approaches 1.0.
private struct MeterBar: View {
    let level: CGFloat
    let color: Color
    let icon: String

    private let s = Theme.scale

    private var barColor: Color {
        let clamped = min(max(level, 0), 1)
        if clamped < 0.4 { return color.opacity(0.7) }
        if clamped < 0.7 { return color }
        return Theme.systemRed
    }

    var body: some View {
        VStack(spacing: 6 * s) {
            GeometryReader { geo in
                let h = geo.size.height
                let w = geo.size.width
                let clamped = min(max(level, 0), 1)
                let fillH = clamped * h

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4 * s)
                        .fill(.white.opacity(0.1))

                    if clamped > 0.01 {
                        RoundedRectangle(cornerRadius: 3 * s)
                            .fill(barColor)
                            .frame(width: w - 2, height: fillH)
                    }
                }
                .animation(.easeOut(duration: 0.1), value: level)
            }
            .frame(width: 14 * s)

            Text(icon)
                .font(.system(size: 12 * s))
        }
    }
}
