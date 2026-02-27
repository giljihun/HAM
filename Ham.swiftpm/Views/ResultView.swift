//
//  ResultView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Director's Notes — per-line performance review with status icons and peak metrics.

import SwiftUI

struct ResultView: View {
    let results: [LineResult]
    var onTryAgain: () -> Void
    var onNewScene: () -> Void

    private let s = Theme.scale

    private var summary: String {
        let naturalCount = results.filter { $0.status == .natural }.count
        let flatCount = results.filter { $0.status == .flat }.count
        let warningCount = results.filter { $0.status == .warning }.count
        let hamCount = results.filter { $0.status == .ham }.count
        let total = results.count
        guard total > 0 else { return "" }

        if naturalCount == total {
            return "Perfect. Every line was natural. You're ready for camera."
        } else if naturalCount >= total / 2 {
            var parts: [String] = ["\(naturalCount)/\(total) natural."]
            if hamCount > 0 { parts.append("\(hamCount) over the top.") }
            if warningCount > 0 { parts.append("\(warningCount) a bit much.") }
            if flatCount > 0 { parts.append("\(flatCount) too quiet.") }
            return parts.joined(separator: " ")
        } else {
            return "Only \(naturalCount)/\(total) natural. Remember: the camera sees everything."
        }
    }

    var body: some View {
        VStack(spacing: 24 * s) {
            Text("Director's Notes")
                .font(Theme.isPad ? .system(size: 40, weight: .bold) : .largeTitle.bold())
                .foregroundStyle(.primary)
                .padding(.top, 48 * s)

            Text(summary)
                .font(Theme.isPad ? .title3 : .body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32 * s)

            ScrollView {
                VStack(spacing: 12 * s) {
                    ForEach(results) { result in
                        lineCard(result)
                    }
                }
                .padding(.horizontal, Theme.padH)
            }

            HStack(spacing: 16 * s) {
                Button {
                    onTryAgain()
                } label: {
                    Text("Try Again")
                        .font(Theme.isPad ? .title3.bold() : .headline)
                        .foregroundStyle(Theme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(14 * s)
                        .background(Theme.bg)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.corner)
                                .stroke(Theme.gold, lineWidth: 1)
                        )
                }

                Button {
                    onNewScene()
                } label: {
                    Text("New Scene")
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
    }

    // MARK: - Line result card

    @ViewBuilder
    private func lineCard(_ result: LineResult) -> some View {
        HStack(alignment: .top, spacing: 12 * s) {
            Image(systemName: result.status.iconName)
                .font(Theme.isPad ? .title3 : .body)
                .foregroundStyle(result.status.color)
                .frame(width: 24 * s, height: 24 * s)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4 * s) {
                Text(result.line)
                    .font(Theme.isPad ? .title3 : .body)
                    .foregroundStyle(.primary)

                Text(result.status.label)
                    .font(Theme.isPad ? .subheadline : .caption)
                    .foregroundStyle(.secondary)

                Text(feedbackText(for: result))
                    .font(Theme.isPad ? .caption : .caption2)
                    .foregroundStyle(result.status.color.opacity(0.8))

                if let metrics = metricsLine(for: result) {
                    Text(metrics)
                        .font(Theme.isPad ? .caption.monospaced() : .caption2.monospaced())
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14 * s)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
    }

    private func feedbackText(for result: LineResult) -> String {
        if let feedback = result.feedback {
            return feedback
        }
        switch result.status {
        case .natural: return "Good job — natural and believable."
        case .passed:  return "Skipped — no judgment this time."
        case .flat:    return "Too quiet."
        case .warning: return "Close, but a little over the top."
        case .ham:     return "Way over the top."
        }
    }

    private func metricsLine(for result: LineResult) -> String? {
        guard result.status != .natural, result.status != .passed else { return nil }

        var parts: [String] = []

        if let volDiff = result.peakVolumeRatio {
            let sign = volDiff >= 0 ? "+" : ""
            parts.append("Vol \(sign)\(String(format: "%.0f", volDiff))dB")
        }
        if let pitchRatio = result.peakPitchRatio {
            parts.append("Pitch \(String(format: "%.1f", pitchRatio))x")
        }
        if let facial = result.peakFacialIntensity, facial > 0.01 {
            parts.append("Face \(String(format: "%.0f", facial * 100))%")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private extension LineStatus {
    var iconName: String {
        switch self {
        case .natural: return "checkmark.circle.fill"
        case .passed:  return "forward.circle.fill"
        case .flat:    return "speaker.slash.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .ham:     return "xmark.circle.fill"
        }
    }
}
