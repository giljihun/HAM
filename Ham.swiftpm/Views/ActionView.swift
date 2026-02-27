//
//  ActionView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Main performance screen — AR camera + teleprompter + real-time voice meter + CUT overlay.

import SwiftUI

struct ActionView: View {
    let session: SessionData

    @State private var viewModel: ActionViewModel?
    @State private var showChannelGuide = true

    private let s = Theme.scale

    var body: some View {
        ZStack {
            if let vm = viewModel {
                if let arView = vm.sceneView {
                    ARCameraView(sceneView: arView)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }

                teleprompter(vm: vm)

                ReactionOverlay(
                    show: vm.showDirectorHint,
                    text: vm.directorHint
                )

                VStack {
                    HStack {
                        Button {
                            vm.stop()
                            session.currentScreen = .setup
                        } label: {
                            Image(systemName: "xmark")
                                .font(Theme.isPad ? .title3.bold() : .body.bold())
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 44 * s, height: 44 * s)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16 * s)
                        Spacer()
                    }
                    .padding(.top, 8)
                    Spacer()
                }

                voiceMeter(vm: vm)

                if vm.showCutScreen {
                    CutOverlay(
                        feedback: vm.cutFeedback,
                        onRetry: { vm.retryLine() },
                        onSkip: { vm.skipLine() }
                    )
                }
            }
        }
        .task {
            viewModel = ActionViewModel(session: session)
        }
        .onChange(of: viewModel?.isCompleted ?? false) { _, completed in
            if completed {
                session.currentScreen = .wrap
            }
        }
        .alert("Meter Guide", isPresented: $showChannelGuide) {
            Button("Got it") {
                guard let vm = viewModel else { return }
                Task { await vm.start() }
            }
        } message: {
            if FaceTrackingService.isAvailable {
                Text("""
                🔊 Volume — how loud you speak
                ↕️ Pitch — how dramatic your tone is
                🎭 Face — how exaggerated your expressions are

                Keep the bars low. The higher they go, the closer you are to CUT!
                """)
            } else {
                Text("""
                🔊 Volume — how loud you speak
                ↕️ Pitch — how dramatic your tone is

                Keep the bars low. The higher they go, the closer you are to CUT!
                """)
            }
        }
    }

    // MARK: - Teleprompter

    @ViewBuilder
    private func teleprompter(vm: ActionViewModel) -> some View {
        let lines = vm.allLines
        let idx = vm.currentLineIndex

        VStack(spacing: 16 * s) {
            if idx > 0 {
                Text(lines[idx - 1])
                    .font(Theme.isPad ? .title3 : .body)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black, radius: 10)
                    .shadow(color: .black, radius: 6)
            }

            HStack(spacing: 10 * s) {
                KaraokeTextView(
                    text: vm.currentLine,
                    fillProgress: vm.fillProgress,
                    unfilledColor: .white.opacity(0.6),
                    multiline: true
                )
                .font(Theme.isPad ? .title.bold() : .title2.bold())
                .multilineTextAlignment(.center)
                .shadow(color: .black, radius: 16)
                .shadow(color: .black, radius: 8)

                Button {
                    vm.passLine()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(Theme.isPad ? .body : .caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36 * s, height: 36 * s)
                        .background(.white.opacity(0.25))
                        .clipShape(Circle())
                }
            }

            if idx < lines.count - 1 {
                Text(lines[idx + 1])
                    .font(Theme.isPad ? .title3 : .body)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black, radius: 10)
                    .shadow(color: .black, radius: 6)
            }

            Text("\(idx + 1) / \(vm.totalLines)")
                .font(Theme.isPad ? .subheadline : .caption)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 4 * s)
        }
        .padding(.horizontal, Theme.padH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: idx)
    }

    // MARK: - 3-channel meter

    @ViewBuilder
    private func voiceMeter(vm: ActionViewModel) -> some View {
        GeometryReader { geo in
            HStack {
                Spacer()
                VoiceMeterView(
                    voiceLevel: vm.meterVoice,
                    pitchLevel: vm.meterPitch,
                    faceLevel: vm.sceneView != nil ? vm.meterFace : nil
                )
                .frame(height: geo.size.height * 0.25)
                .padding(.trailing, 20 * s)
            }
        }
    }
}
