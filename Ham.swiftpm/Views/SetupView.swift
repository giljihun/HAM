//
//  SetupView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Script selection — clapperboard carousel for choosing a scene preset.

import SwiftUI

struct SetupView: View {
    var onSelect: (ActingScene) -> Void
    var onRecalibrate: (() -> Void)?

    @State private var vm = SetupViewModel()

    private let s = Theme.scale

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.trailing, 16 * s)
                .padding(.top, 16 * s)

            Spacer()

            VStack(spacing: 6 * s) {
                Text("Pick a Script")
                    .font(Theme.isPad ? .system(size: 42, weight: .bold) : .largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Choose a scene and start acting.")
                    .font(Theme.isPad ? .title3 : .body)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 36 * s)

            GeometryReader { geo in
                let cardWidth = geo.size.width * (Theme.isPad ? 0.58 : 0.75)
                let sideInset = (geo.size.width - cardWidth) / 2

                ScrollView(.horizontal) {
                    HStack(spacing: 16 * s) {
                        ForEach(vm.presets) { scene in
                            slateCard(scene, isSelected: scene.id == vm.selectedID)
                                .frame(width: cardWidth)
                                .id(scene.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $vm.selectedID)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .contentMargins(.vertical, 20 * s, for: .scrollContent)
            }
            .frame(height: Theme.isPad ? 380 : 290)

            Button {
                let scene = vm.selectPreset()
                onSelect(scene)
            } label: {
                Text("Start")
                    .font(Theme.isPad ? .title3.bold() : .headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 56 * s)
                    .padding(.vertical, 14 * s)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }
            .padding(.top, 32 * s)

            Spacer()
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            Spacer()
            if let onRecalibrate {
                Button {
                    onRecalibrate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Recalibrate")
                    }
                    .font(Theme.isPad ? .subheadline : .caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 14 * s)
                    .padding(.vertical, 8 * s)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Clapperboard card

    @ViewBuilder
    private func slateCard(_ scene: ActingScene, isSelected: Bool = false) -> some View {
        VStack(spacing: 0) {
            clapperStripes
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 14 * s,
                        topTrailingRadius: 14 * s
                    )
                )

            Rectangle()
                .fill(Theme.gold.opacity(0.6))
                .frame(height: 2)

            VStack(alignment: .leading, spacing: 12 * s) {
                slateField("SCENE", value: scene.title, valueFont: Theme.isPad ? .title2.bold() : .title3.bold())

                Text(scene.situation)
                    .font(Theme.isPad ? .body : .subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(3)

                slateDivider

                HStack {
                    slateField("ROLE", value: scene.role)
                    Spacer()
                    slateField("TAKE", value: "\(scene.lines.count) lines")
                }

                slateDivider

                HStack(spacing: 0) {
                    Text("\u{201C}")
                        .foregroundStyle(Theme.gold.opacity(0.4))
                    Text(scene.lines.first ?? "")
                        .foregroundStyle(.white.opacity(0.4))
                    Text("\u{201D}")
                        .foregroundStyle(Theme.gold.opacity(0.4))
                }
                .font(Theme.isPad ? .body.italic() : .subheadline.italic())
                .lineLimit(2)

            }
            .padding(18 * s)
        }
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14 * s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .stroke(Theme.gold.opacity(isSelected ? 0.4 : 0.15), lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: Theme.gold.opacity(isSelected ? 0.35 : 0.15), radius: isSelected ? 24 : 16, y: 0)
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.3), value: isSelected)
    }

    private var clapperStripes: some View {
        Canvas { context, size in
            let stripeW: CGFloat = 22 * s

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(white: 0.82))
            )

            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + stripeW, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height + stripeW, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.closeSubpath()
                context.fill(path, with: .color(Color(white: 0.1)))
                x += stripeW * 2
            }
        }
        .frame(height: 20 * s)
    }

    private func slateField(
        _ label: String,
        value: String,
        valueFont: Font = Theme.isPad ? .title3.bold() : .subheadline.bold()
    ) -> some View {
        HStack(spacing: 8 * s) {
            Text(label)
                .font(Theme.isPad
                      ? .caption.monospaced().bold()
                      : .caption2.monospaced().bold())
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(valueFont)
                .foregroundStyle(Theme.gold)
        }
    }

    private var slateDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 0.5)
    }
}
