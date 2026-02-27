//
//  KaraokeTextView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Karaoke-style text fill.
/// Single-line mode: overlay + clipShape sweep (smooth animation).
/// Multi-line mode: AttributedString per-character fill (safe for wrapped text).

import SwiftUI

struct KaraokeTextView: View {
    let text: String
    let fillProgress: CGFloat
    var filledColor: Color = Theme.gold
    var unfilledColor: Color = .white.opacity(0.4)
    var multiline: Bool = false

    var body: some View {
        if multiline {
            multilineBody
        } else {
            singleLineBody
        }
    }

    // MARK: - Single-line: clipShape sweep

    private var singleLineBody: some View {
        Text(text)
            .foregroundStyle(unfilledColor)
            .overlay {
                Text(text)
                    .foregroundStyle(filledColor)
                    .clipShape(FillClip(progress: fillProgress))
            }
            .animation(.easeOut(duration: 0.3), value: fillProgress)
    }

    // MARK: - Multi-line: AttributedString (safe for wrapped text)

    private var filledCount: Int {
        min(Int(round(CGFloat(text.count) * fillProgress)), text.count)
    }

    private var attributedText: AttributedString {
        var result = AttributedString(text)

        if filledCount > 0 {
            let start = result.startIndex
            let end = result.index(start, offsetByCharacters: filledCount)
            result[start..<end].foregroundColor = UIColor(filledColor)
        }

        if filledCount < text.count {
            let start = result.index(result.startIndex, offsetByCharacters: filledCount)
            result[start..<result.endIndex].foregroundColor = UIColor(unfilledColor)
        }

        return result
    }

    private var multilineBody: some View {
        Text(attributedText)
            .contentTransition(.interpolate)
            .animation(.easeOut(duration: 0.3), value: filledCount)
    }
}

private struct FillClip: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width * max(0, min(1, progress))
        return Path(CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height))
    }
}
