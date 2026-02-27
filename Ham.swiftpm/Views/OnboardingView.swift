//
//  OnboardingView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Onboarding — cinematic intro sequence + karaoke-style voice calibration.

import SwiftUI

struct OnboardingView: View {
    let session: SessionData

    @State private var viewModel: OnboardingViewModel?
    @State private var showScript = false

    @State private var showIcon = false
    @State private var showLine1 = false
    @State private var showLine2 = false
    @State private var showLine3 = false
    @State private var showBottom = false

    private let s = Theme.scale

    var body: some View {
        ZStack {
            if let vm = viewModel {
                if !showScript {
                    promptView(vm: vm)
                } else {
                    scriptView(vm: vm)
                }
            }
        }
        .task {
            let vm = OnboardingViewModel(session: session)
            viewModel = vm
            await runIntroSequence()
        }
    }

    // MARK: - Cinematic intro sequence

    private func runIntroSequence() async {
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeOut(duration: 0.8)) { showIcon = true }

        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.easeOut(duration: 0.7)) { showLine1 = true }

        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeOut(duration: 0.7)) { showLine2 = true }

        try? await Task.sleep(for: .seconds(1.5))
        withAnimation(.easeOut(duration: 0.7)) { showLine3 = true }

        try? await Task.sleep(for: .seconds(1.0))
        withAnimation(.easeOut(duration: 0.6)) { showBottom = true }
    }

    // MARK: - Phase 1: Cinematic prompt

    @ViewBuilder
    private func promptView(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 0) {
            Spacer()

            appIcon
                .opacity(showIcon ? 1 : 0)
                .scaleEffect(showIcon ? 1.0 : 0.8)
                .padding(.bottom, 32 * s)

            Text("Right now, you are an actor.")
                .font(Theme.isPad ? .system(size: 34, weight: .bold) : .title.bold())
                .foregroundStyle(.white)
                .opacity(showLine1 ? 1 : 0)
                .offset(y: showLine1 ? 0 : 12)

            Spacer().frame(height: 20 * s)

            VStack(spacing: 6 * s) {
                Text("And one who wants to become truly great!")
                    .foregroundStyle(Theme.gold)
                Text("But for that, you need natural acting skills.")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .font(Theme.isPad ? .title2 : .title3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24 * s)
            .opacity(showLine2 ? 1 : 0)
            .offset(y: showLine2 ? 0 : 12)

            Spacer().frame(height: 20 * s)

            Text("We'll calibrate your natural voice first.\nJust read a few lines aloud.")
                .font(Theme.isPad ? .title3 : .body)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24 * s)
                .opacity(showLine3 ? 1 : 0)
                .offset(y: showLine3 ? 0 : 12)

            Spacer()

            VStack(spacing: 14 * s) {
                HStack(spacing: 6 * s) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.subheadline)
                    Text("Please use in a quiet environment.")
                        .font(Theme.isPad ? .body : .subheadline)
                }
                .foregroundStyle(.white.opacity(0.3))

                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showScript = true
                    }
                    Task { await vm.start() }
                } label: {
                    Text("OK")
                        .font(Theme.isPad ? .title3.bold() : .headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 56 * s)
                        .padding(.vertical, 14 * s)
                        .background(Theme.gold)
                        .clipShape(Capsule())
                }
            }
            .opacity(showBottom ? 1 : 0)
            .padding(.bottom, 48 * s)
        }
    }

    // MARK: - App icon

    private var appIcon: some View {
        Group {
            if let icon = loadAppIcon() {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 88 * s, height: 88 * s)
                    .clipShape(RoundedRectangle(cornerRadius: 20 * s, style: .continuous))
                    .shadow(color: Theme.gold.opacity(0.3), radius: 16, y: 4)
            }
        }
    }

    private func loadAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last,
           let img = UIImage(named: name) {
            return img
        }
        return UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60")
    }

    // MARK: - Phase 2: Script reading

    @ViewBuilder
    private func scriptView(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 0) {
            recordingIndicator
                .padding(.top, 16 * s)

            Spacer()

            Text("🗣️ Speak naturally")
                .font(Theme.isPad ? .title3 : .headline)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 32 * s)

            VStack(spacing: 28 * s) {
                ForEach(0..<OnboardingData.monologue.count, id: \.self) { i in
                    lineView(index: i, vm: vm)
                }
            }
            .padding(.horizontal, 28 * s)

            Spacer().frame(height: 16 * s)

            Text("Try again")
                .font(Theme.isPad ? .body : .subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .opacity(vm.showRetryHint ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: vm.showRetryHint)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.tapToAdvance()
        }
        .transition(.opacity)
        .onChange(of: vm.isCompleted) { _, completed in
            if completed {
                session.currentScreen = .scriptIntro
            }
        }
    }

    // MARK: - Recording indicator

    private var recordingIndicator: some View {
        HStack(spacing: 6 * s) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red.opacity(0.6), radius: 4)

            Text("Listening...")
                .font(Theme.isPad ? .subheadline : .caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Line view

    @ViewBuilder
    private func lineView(index i: Int, vm: OnboardingViewModel) -> some View {
        let isRead = i < vm.currentLineIndex
        let isCurrent = i == vm.currentLineIndex
        let text = OnboardingData.monologue[i]

        Group {
            if isCurrent {
                KaraokeTextView(
                    text: text,
                    fillProgress: vm.fillProgress
                )
            } else {
                Text(text)
                    .foregroundStyle(isRead ? Theme.gold.opacity(0.5) : .white.opacity(0.2))
            }
        }
        .font(Theme.isPad ? .system(size: 32, weight: .bold) : .title2.bold())
        .multilineTextAlignment(.center)
        .scaleEffect(isCurrent ? 1.0 : 0.85)
    }
}
