//
//  OnboardingViewModel.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Onboarding ViewModel — karaoke-style speech tracking with voice baseline calibration.
/// Progress never goes backward. Matching is generous (fuzzy + short-word auto-skip).
/// 65% token match threshold to advance. Tap fallback always available.

import SwiftUI
import CoreHaptics

@Observable
final class OnboardingViewModel {

    // MARK: - UI State

    var currentLineIndex: Int = 0
    var fillProgress: CGFloat = 0
    var isCompleted: Bool = false
    var isMicDenied: Bool = false
    var showRetryHint: Bool = false

    // MARK: - Internal

    private var lines: [String] { OnboardingData.monologue }
    private var speechService: SpeechRecognizable
    private let audioService: AudioService
    private let session: SessionData
    private var hapticEngine: CHHapticEngine?
    private var silenceTimer: Task<Void, Never>?
    private var listeningTask: Task<Void, Never>?
    private var isTransitioning = false
    private var bestMatchCount = 0

    var currentLine: String {
        guard currentLineIndex < lines.count else { return "" }
        return lines[currentLineIndex]
    }

    init(
        session: SessionData,
        speechService: SpeechRecognizable? = nil,
        audioService: AudioService = AudioService()
    ) {
        self.session = session
        self.audioService = audioService
        self.speechService = speechService ?? SpeechService(audioService: audioService)
    }

    // MARK: - Start

    func start() async {
        speechService = SpeechService(audioService: audioService)
        let authorized = await speechService.requestAuthorization()
        if !authorized {
            await MainActor.run { isMicDenied = true }
            return
        }

        let audioTask = Task { [weak self] in
            guard let self else { return }
            for await level in audioService.audioLevels {
                await MainActor.run {
                    self.session.baseline.update(pitch: level.pitch, volume: level.volume)
                }
            }
        }

        await listenForCurrentLine()
        audioTask.cancel()
    }

    // MARK: - Token-based speech recognition

    private func listenForCurrentLine() async {
        guard !isCompleted else { return }

        let myLineIndex = await MainActor.run {
            bestMatchCount = 0
            isTransitioning = false
            return currentLineIndex
        }
        let targetLine = lines[myLineIndex]
        let tokens = SpeechMatcher.tokenize(targetLine)
        let completionThreshold = max(2, Int(ceil(Double(tokens.count) * 0.65)))

        let textStream = speechService.startListening()
        let listenStart = ContinuousClock.now

        for await text in textStream {
            guard !isCompleted, !isTransitioning else { break }
            guard currentLineIndex == myLineIndex else { break }

            await MainActor.run {
                guard !self.isTransitioning else { return }

                let matched = SpeechMatcher.matchTokens(recognized: text, tokens: tokens)
                let newProgress = tokens.isEmpty
                    ? 1.0
                    : SpeechMatcher.fillProgress(matched: matched, in: targetLine)
                fillProgress = max(fillProgress, newProgress)

                if matched > bestMatchCount {
                    bestMatchCount = matched
                }

                resetSilenceTimer()

                let elapsed = ContinuousClock.now - listenStart
                guard elapsed > .seconds(1.0) else { return }

                guard matched >= completionThreshold else { return }

                advanceLine()
            }
        }
    }

    // MARK: - Line progression

    private func advanceLine() {
        isTransitioning = true
        silenceTimer?.cancel()
        listeningTask?.cancel()
        speechService.stopListening()

        fillProgress = 1.0

        listeningTask = Task { [weak self] in
            guard let self else { return }
            await self.playLineHaptic()
            try? await Task.sleep(for: .seconds(0.7))

            let isLast = await MainActor.run {
                self.currentLineIndex >= self.lines.count - 1
            }

            if isLast {
                await MainActor.run { self.completeOnboarding() }
            } else {
                await MainActor.run {
                    self.currentLineIndex += 1
                    self.fillProgress = 0
                }
                try? await Task.sleep(for: .seconds(0.3))
                await self.listenForCurrentLine()
            }
        }
    }

    private func completeOnboarding() {
        silenceTimer?.cancel()
        listeningTask?.cancel()
        speechService.stopListening()
        audioService.stopAnalyzing()
        if let svc = speechService as? SpeechService {
            svc.shutdown()
        }
        session.saveBaseline()

        Task {
            await playCompletionHaptic()
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                isCompleted = true
            }
        }
    }

    // MARK: - Silence timer (3s: restart recognition, +2s: reset fill)

    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            guard let self, !self.isTransitioning else { return }

            self.speechService.stopListening()
            self.listeningTask?.cancel()

            await MainActor.run {
                self.fillProgress = 0
                self.bestMatchCount = 0
                self.showRetryHint = true
            }

            self.listeningTask = Task {
                await self.listenForCurrentLine()
            }

            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.showRetryHint = false
            }
        }
    }

    // MARK: - Tap fallback

    func tapToAdvance() {
        guard !isTransitioning else { return }
        isTransitioning = true
        silenceTimer?.cancel()
        listeningTask?.cancel()
        speechService.stopListening()

        fillProgress = 1.0

        listeningTask = Task { [weak self] in
            guard let self else { return }
            await self.playLineHaptic()
            try? await Task.sleep(for: .seconds(0.5))

            let isLast = await MainActor.run {
                self.currentLineIndex >= self.lines.count - 1
            }

            if isLast {
                await MainActor.run { self.completeOnboarding() }
            } else {
                await MainActor.run {
                    self.currentLineIndex += 1
                    self.fillProgress = 0
                }
                try? await Task.sleep(for: .seconds(0.3))
                await self.listenForCurrentLine()
            }
        }
    }

    // MARK: - CoreHaptics

    private func playLineHaptic() async {
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

    private func playCompletionHaptic() async {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try await hapticEngine?.start()
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {}
    }
}
