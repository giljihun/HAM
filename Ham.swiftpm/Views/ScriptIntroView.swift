//
//  ScriptIntroView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// "Today's script is..." — karaoke intro between onboarding and scene selection.
/// Advances after recognizing just 1 token (very short line).

import SwiftUI
import CoreHaptics

struct ScriptIntroView: View {
    let session: SessionData
    var onComplete: () -> Void

    private let s = Theme.scale

    private let line = "Today's script is..."

    @State private var fillProgress: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var isCompleted = false
    @State private var speechService: SpeechService?
    @State private var silenceTimer: Task<Void, Never>?
    @State private var hapticEngine: CHHapticEngine?

    var body: some View {
        VStack {
            Spacer()

            KaraokeTextView(
                text: line,
                fillProgress: fillProgress,
                filledColor: Theme.gold,
                unfilledColor: .white.opacity(0.4)
            )
            .font(Theme.isPad ? .system(size: 44, weight: .bold) : .largeTitle.bold())
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.padH)

            Spacer()
        }
        .opacity(opacity)
        .task {
            withAnimation(.easeIn(duration: 0.6)) {
                opacity = 1
            }
            try? await Task.sleep(for: .seconds(0.6))
            await startListening()
        }
        .onDisappear {
            silenceTimer?.cancel()
            speechService?.stopListening()
            speechService?.shutdown()
        }
    }

    // MARK: - Speech recognition

    private func startListening() async {
        let audioSvc = AudioService()
        let svc = SpeechService(audioService: audioSvc)
        speechService = svc

        let authorized = await svc.requestAuthorization()
        guard authorized else {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { onComplete() }
            return
        }

        let tokens = SpeechMatcher.tokenize(line)
        let textStream = svc.startListening()

        for await text in textStream {
            guard !isCompleted else { break }

            await MainActor.run {
                let matched = SpeechMatcher.matchTokens(recognized: text, tokens: tokens)
                let newProgress = tokens.isEmpty
                    ? 1.0
                    : SpeechMatcher.fillProgress(matched: matched, in: line)
                fillProgress = max(fillProgress, newProgress)
                resetSilenceTimer()

                if matched >= 1 { complete() }
            }
        }
    }

    // MARK: - Transition

    private func complete() {
        guard !isCompleted else { return }
        isCompleted = true
        fillProgress = 1.0
        silenceTimer?.cancel()
        speechService?.stopListening()
        speechService?.shutdown()

        Task {
            await playHaptic()
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run { onComplete() }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, !isCompleted else { return }
            speechService?.stopListening()
            await MainActor.run { fillProgress = 0 }
            try? await Task.sleep(for: .seconds(0.3))
            guard let svc = speechService else { return }
            let tokens = SpeechMatcher.tokenize(line)
            let stream = svc.startListening()
            for await text in stream {
                guard !isCompleted else { break }
                await MainActor.run {
                    let matched = SpeechMatcher.matchTokens(recognized: text, tokens: tokens)
                    let newProgress = tokens.isEmpty
                        ? 1.0
                        : SpeechMatcher.fillProgress(matched: matched, in: line)
                    fillProgress = max(fillProgress, newProgress)
                    resetSilenceTimer()
                    if matched >= 2 { complete() }
                }
            }
        }
    }

    private func playHaptic() async {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try await hapticEngine?.start()
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {}
    }
}
