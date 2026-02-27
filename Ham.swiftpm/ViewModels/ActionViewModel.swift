//
//  ActionViewModel.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Core performance ViewModel — real-time overacting detection using 6 channels.
///
/// DETECTION CHANNELS:
///   [Amplitude] pitchAmp, volumeAmp, facialAmp — how loud/high/exaggerated
///   [Variance]  pitchVar, volumeSpike, faceVel — how dramatically it changes
///
/// COMBINED SCORE = amplitude(48%) + variance(48%) + constant(4%)
/// 6-channel (device):    Face(44%) > Pitch(34%) >> Volume(18%)
/// 4-channel (simulator): Pitch(56%) >> Volume(40%) — no face tracking
///
/// THRESHOLD TUNING:
///   Pitch amplitude — deadzone: 0.15, divisor: 0.35
///   Volume — deadzone: 4dB above baseline
///   Facial — deadzone: 0.10, divisor: 0.18
///   Pitch variance — deadzone: 18Hz, divisor: 18
///   Volume spike — deadzone: 4dB, divisor: 4
///   Face velocity — deadzone: 0.025, divisor: 0.06
///
///   To make detection stricter: decrease deadzone or divisor
///   To make detection more lenient: increase deadzone or divisor

import SwiftUI
import ARKit
import CoreHaptics

@Observable
final class ActionViewModel {

    // MARK: - UI State

    var currentLineIndex: Int = 0
    var overactingLevel: OveractingLevel = .normal
    var showCutScreen: Bool = false
    var cutFeedback: String = ""
    var isCompleted: Bool = false

    var directorHint: String = ""
    var showDirectorHint: Bool = false
    var fillProgress: CGFloat = 0

    // MARK: - 3-channel meter (0~1 each)

    var meterVoice: CGFloat = 0
    var meterPitch: CGFloat = 0
    var meterFace: CGFloat = 0

    private(set) var pitchAmpValue: Float = 1.0
    private(set) var volumeAmpValue: Float = 1.0
    private(set) var facialAmpValue: Float = 1.0
    private(set) var pitchVarValue: Float = 1.0
    private(set) var volSpikeValue: Float = 1.0
    private(set) var faceVelValue: Float = 1.0
    private(set) var combinedValue: Float = 1.0

    // MARK: - Amplitude (smoothed)

    private var smoothedPitch: Float = 0
    private var smoothedVolume: Float = 0
    private var smoothedFacial: Float = 0

    // MARK: - Variance tracking

    private var pitchBuffer: [Float] = []
    private var prevVolume: Float = 0
    private var prevFacial: Float = 0
    private var smoothedPitchVar: Float = 0
    private var smoothedVolSpike: Float = 0
    private var smoothedFaceVel: Float = 0
    private let pitchBufferSize = 20

    private var linePeakPitch: Float = 0
    private var linePeakVolume: Float = 0
    private var linePeakFacial: Float = 0
    private var linePeakLevel: OveractingLevel = .normal
    private var linePeakFeedback: String?
    private var linePeakDominantIssue: String?

    // MARK: - Dependencies

    private let session: SessionData
    private let faceService: FaceTrackable
    private let speechService: SpeechRecognizable
    private let audioService: AudioService
    private let hasFaceTracking: Bool
    private var hapticEngine: CHHapticEngine?

    private var faceTask: Task<Void, Never>?
    private var voiceTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var silenceTimer: Task<Void, Never>?
    private var hintDismissTask: Task<Void, Never>?
    private var isTransitioning = false
    private var isWarmingUp = true
    private var bestMatchCount = 0

    var currentLine: String {
        guard let scene = session.selectedScene,
              currentLineIndex < scene.lines.count else { return "" }
        return scene.lines[currentLineIndex]
    }

    var totalLines: Int {
        session.selectedScene?.lines.count ?? 0
    }

    var allLines: [String] {
        session.selectedScene?.lines ?? []
    }

    var sceneView: ARSCNView? {
        faceService.sceneView
    }

    init(
        session: SessionData,
        faceService: FaceTrackable? = nil,
        speechService: SpeechRecognizable? = nil,
        audioService: AudioService = AudioService()
    ) {
        self.session = session
        self.audioService = audioService
        self.faceService = faceService ?? FaceTrackingService()
        self.speechService = speechService ?? SpeechService(audioService: audioService)
        self.hasFaceTracking = FaceTrackingService.isAvailable
    }

    // MARK: - Start / Stop

    func start() async {
        resetLinePeaks()

        if hasFaceTracking {
            faceService.startTracking()
            faceTask = Task { [weak self] in await self?.analyzeFace() }
        }

        // Warmup: let sensors stabilize before scoring
        voiceTask = Task { [weak self] in await self?.analyzeVoice() }
        try? await Task.sleep(for: .seconds(1.0))
        await MainActor.run { isWarmingUp = false }

        await listenForCurrentLine()
    }

    func stop() {
        faceTask?.cancel()
        voiceTask?.cancel()
        speechTask?.cancel()
        silenceTimer?.cancel()
        hintDismissTask?.cancel()
        faceService.stopTracking()
        speechService.stopListening()
        audioService.stopAnalyzing()
        if let svc = speechService as? SpeechService {
            svc.shutdown()
        }
    }

    // MARK: - Face analysis

    private func analyzeFace() async {
        for await metrics in faceService.faceMetrics {
            guard !showCutScreen, !isCompleted else { continue }
            await MainActor.run {
                let intensity = adjustFacialForSpeech(metrics)

                let delta = abs(intensity - prevFacial)
                smoothedFaceVel = smoothedFaceVel * 0.7 + delta * 0.3
                prevFacial = intensity

                smoothedFacial = smoothedFacial * 0.3 + intensity * 0.7
                linePeakFacial = max(linePeakFacial, smoothedFacial)

                updateOveractingLevel()
            }
        }
    }

    /// Jaw opening reduced by 0.15 to discount natural speech mouth movement.
    private func adjustFacialForSpeech(_ m: FaceMetrics) -> Float {
        let brow = (m.browDownLeft + m.browDownRight) / 2
        let frown = (m.mouthFrownLeft + m.mouthFrownRight) / 2
        let squint = (m.eyeSquintLeft + m.eyeSquintRight) / 2
        let jaw = max(m.jawOpen - 0.15, 0)
        return brow * 0.3 + jaw * 0.2 + frown * 0.25 + squint * 0.25
    }

    // MARK: - Voice analysis

    private func analyzeVoice() async {
        for await level in audioService.audioLevels {
            guard !showCutScreen, !isCompleted else { continue }
            await MainActor.run {
                // Dynamic noise gate: baseline(speaking volume) - 5dB
                // Example: speaking at -25dB → gate at -30dB (strongly rejects non-voice)
                let noiseGate = max(session.baseline.averageVolume - 5, -40)
                let isSpeaking = level.volume > noiseGate

                if isSpeaking {
                    pitchBuffer.append(level.pitch)
                    if pitchBuffer.count > pitchBufferSize {
                        pitchBuffer.removeFirst()
                    }
                    if pitchBuffer.count >= 10 {
                        let stdDev = standardDeviation(pitchBuffer)
                        smoothedPitchVar = smoothedPitchVar * 0.7 + stdDev * 0.3
                    }

                    smoothedPitch = smoothedPitch * 0.3 + level.pitch * 0.7
                    linePeakPitch = max(linePeakPitch, smoothedPitch)

                    smoothedVolume = smoothedVolume * 0.3 + level.volume * 0.7
                    linePeakVolume = max(linePeakVolume, smoothedVolume)

                    if prevVolume > noiseGate {
                        let volJump = abs(level.volume - prevVolume)
                        smoothedVolSpike = smoothedVolSpike * 0.7 + volJump * 0.3
                    }
                    prevVolume = level.volume

                    updateOveractingLevel()
                } else {
                    // Silence: gradually decay toward baseline
                    smoothedPitch = smoothedPitch * 0.95 + session.baseline.averagePitch * 0.05
                    smoothedVolume = smoothedVolume * 0.95 + session.baseline.averageVolume * 0.05
                    prevVolume = level.volume

                    updateOveractingLevel()
                }
            }
        }
    }

    private func standardDeviation(_ values: [Float]) -> Float {
        let count = Float(values.count)
        guard count > 1 else { return 0 }
        let mean = values.reduce(0, +) / count
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / count
        return sqrt(variance)
    }

    // MARK: - Token-based speech recognition

    private func listenForCurrentLine() async {
        guard !isCompleted else { return }

        let myLineIndex = await MainActor.run {
            bestMatchCount = 0
            isTransitioning = false
            pitchBuffer = []
            smoothedPitchVar = 0
            smoothedVolSpike = 0
            smoothedFaceVel = 0
            return currentLineIndex
        }
        let targetLine = allLines[myLineIndex]
        let tokens = SpeechMatcher.tokenize(targetLine)
        let completionThreshold = max(2, Int(ceil(Double(tokens.count) * 0.75)))

        let textStream = speechService.startListening()
        let listenStart = ContinuousClock.now

        for await text in textStream {
            guard !isCompleted, !isTransitioning else { break }
            guard currentLineIndex == myLineIndex else { break }

            await MainActor.run {
                guard !isTransitioning else { return }

                let matched = SpeechMatcher.matchTokens(recognized: text, tokens: tokens)
                let newProgress = tokens.isEmpty
                    ? 1.0
                    : SpeechMatcher.fillProgress(matched: matched, in: targetLine)
                fillProgress = max(fillProgress, newProgress)

                if matched > bestMatchCount { bestMatchCount = matched }
                resetSilenceTimer()

                // Guard: wait at least 1s to prevent residual text from auto-completing
                let elapsed = ContinuousClock.now - listenStart
                guard elapsed > .seconds(1.0) else { return }

                guard matched >= completionThreshold else { return }

                lineCompleted()
            }
        }
    }

    // MARK: - Overacting evaluation

    private func updateOveractingLevel() {
        guard !isTransitioning, !isWarmingUp else { return }

        let baseline = session.baseline

        // === Amplitude ratios (one-directional — only detects "over") ===

        let rawPitchRatio: Float = baseline.averagePitch > 0
            ? smoothedPitch / baseline.averagePitch : 1.0
        let pitchDeviation = max(rawPitchRatio - 1.0, 0)
        let pitchAmp: Float = 1.0 + max(pitchDeviation - 0.15, 0) / 0.35

        let volumeAmp: Float
        if baseline.averageVolume < 0, baseline.averageVolume != 0 {
            let volOver = max(smoothedVolume - baseline.averageVolume, 0)
            volumeAmp = 1.0 + max(volOver - 4, 0) / (abs(baseline.averageVolume) * 0.8)
        } else {
            volumeAmp = 1.0
        }

        let facialAmp: Float = 1.0 + max(smoothedFacial - 0.10, 0) / 0.18

        // === Variance ratios ===

        let pitchVar: Float = 1.0 + max(smoothedPitchVar - 18, 0) / 18
        let volSpike: Float = 1.0 + max(smoothedVolSpike - 4, 0) / 4
        let faceVel: Float = 1.0 + max(smoothedFaceVel - 0.025, 0) / 0.06

        // === Combined score ===
        // 6-channel (device): Face(44%) > Pitch(34%) >> Volume(18%)
        // 4-channel (simulator): Pitch(56%) >> Volume(40%)
        let ampScore: Float
        let varScore: Float
        if hasFaceTracking {
            ampScore = pitchAmp * 0.12 + volumeAmp * 0.12 + facialAmp * 0.24
            varScore = pitchVar * 0.22 + volSpike * 0.06 + faceVel * 0.20
        } else {
            ampScore = pitchAmp * 0.20 + volumeAmp * 0.16
            varScore = pitchVar * 0.40 + volSpike * 0.20
        }
        let combined = ampScore + varScore + 0.04

        pitchAmpValue = pitchAmp
        volumeAmpValue = volumeAmp
        facialAmpValue = facialAmp
        pitchVarValue = pitchVar
        volSpikeValue = volSpike
        faceVelValue = faceVel
        combinedValue = combined

        // Meter scaling
        let cutExcess: Float = 0.45

        let volExcess = (volumeAmp - 1.0) * 0.12 + (volSpike - 1.0) * 0.06
        let targetVoice = CGFloat(min(max(volExcess / 0.18, 0), 1.0))

        let pitchExcess = (pitchAmp - 1.0) * 0.12 + (pitchVar - 1.0) * 0.22
        let targetPitch = CGFloat(min(max(pitchExcess / cutExcess, 0), 1.0))

        // Smoothing: 70% previous + 30% new
        meterVoice = meterVoice * 0.7 + targetVoice * 0.3
        meterPitch = meterPitch * 0.7 + targetPitch * 0.3

        if hasFaceTracking {
            let faceExcess = (facialAmp - 1.0) * 0.24 + (faceVel - 1.0) * 0.20
            let targetFace = CGFloat(min(max(faceExcess / cutExcess, 0), 1.0))
            meterFace = meterFace * 0.7 + targetFace * 0.3
        }

        let newLevel: OveractingLevel
        switch combined {
        case ..<1.15:     newLevel = .normal
        case 1.15..<1.26: newLevel = .caution
        case 1.26..<1.70: newLevel = .warning
        default:          newLevel = .cut
        }

        if newLevel > linePeakLevel {
            linePeakLevel = newLevel
            let (dominant, _) = findDominantIssue()
            linePeakDominantIssue = dominant
            linePeakFeedback = buildFeedback()
        }
        if newLevel != overactingLevel {
            overactingLevel = newLevel
            applyReaction(newLevel)
        }
    }

    // MARK: - Reactions (director hints)

    private func applyReaction(_ level: OveractingLevel) {
        switch level {
        case .normal:
            dismissHint()
        case .caution:
            let (dominant, _) = findDominantIssue()
            showHint(cautionText(for: dominant))
        case .warning:
            let (dominant, _) = findDominantIssue()
            showHint(warningText(for: dominant))
        case .cut:
            dismissHint()
            triggerCut()
        }
    }

    private func showHint(_ text: String) {
        directorHint = text
        showDirectorHint = true
        hintDismissTask?.cancel()
        hintDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.showDirectorHint = false
        }
    }

    private func dismissHint() {
        hintDismissTask?.cancel()
        showDirectorHint = false
    }

    private var isPitchVarDominant: Bool {
        (pitchVarValue - 1.0) > (pitchAmpValue - 1.0)
    }

    private func cautionText(for dominant: String) -> String {
        switch dominant {
        case "face":   return "hmm... the face"
        case "pitch":
            return isPitchVarDominant ? "hmm... the tone shifts" : "hmm... the tone"
        case "volume": return "hmm... a bit loud"
        default:       return "hmm..."
        }
    }

    private func warningText(for dominant: String) -> String {
        switch dominant {
        case "face":   return "easy on the expressions..."
        case "pitch":
            return isPitchVarDominant ? "the tone is all over the place..." : "the pitch is too high..."
        case "volume": return "way too loud..."
        default:       return "hold on..."
        }
    }

    // MARK: - CUT

    private func triggerCut() {
        isTransitioning = true
        speechService.stopListening()
        silenceTimer?.cancel()

        cutFeedback = buildFeedback()
        showCutScreen = true
    }

    private func buildFeedback() -> String {
        let (top, _) = findDominantIssue()

        switch top {
        case "face":
            return "Your face is doing too much. Relax — the camera catches everything."
        case "pitch":
            if isPitchVarDominant {
                return "Your tone swings too wildly. Keep it steady — talk like a real person."
            } else {
                return "Your voice pitch is too high. Bring it down to your natural range."
            }
        case "volume":
            return "Too loud. The mic is right there — just talk normally."
        default:
            return "Too much overall. Think smaller. The camera sees everything."
        }
    }

    /// Returns the channel contributing most to the combined score.
    private func findDominantIssue() -> (String, Float) {
        var contributions: [(String, Float)] = [
            ("pitch",  (pitchAmpValue - 1.0) * 0.12 + (pitchVarValue - 1.0) * 0.22),
            ("volume", (volumeAmpValue - 1.0) * 0.12 + (volSpikeValue - 1.0) * 0.06),
        ]
        if hasFaceTracking {
            contributions.append(
                ("face", (facialAmpValue - 1.0) * 0.24 + (faceVelValue - 1.0) * 0.20)
            )
        }
        return contributions.max(by: { $0.1 < $1.1 }) ?? ("overall", 0)
    }

    // MARK: - Post-CUT actions

    func retryLine() {
        showCutScreen = false
        resetLinePeaks()

        speechTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(0.3))
            await self.listenForCurrentLine()
        }
    }

    func skipLine() {
        let (dominant, _) = findDominantIssue()
        let result = LineResult(
            line: currentLine,
            status: .ham,
            feedback: cutFeedback,
            peakPitchRatio: session.baseline.averagePitch > 0
                ? linePeakPitch / session.baseline.averagePitch : nil,
            peakVolumeRatio: linePeakVolume - session.baseline.averageVolume,
            peakFacialIntensity: linePeakFacial,
            dominantIssue: dominant
        )
        session.lineResults.append(result)
        showCutScreen = false
        advanceToNextLine()

        if !isCompleted {
            speechTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(0.3))
                await self.listenForCurrentLine()
            }
        }
    }

    func passLine() {
        guard !isTransitioning else { return }
        isTransitioning = true
        silenceTimer?.cancel()
        speechService.stopListening()

        let result = LineResult(
            line: currentLine,
            status: .passed,
            feedback: nil,
            peakPitchRatio: nil,
            peakVolumeRatio: nil,
            peakFacialIntensity: nil,
            dominantIssue: nil
        )
        session.lineResults.append(result)
        fillProgress = 1.0

        speechTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(0.3))
            await MainActor.run { self.advanceToNextLine() }
            guard !self.isCompleted else { return }
            try? await Task.sleep(for: .seconds(0.3))
            await self.listenForCurrentLine()
        }
    }

    // MARK: - Line completion

    private func lineCompleted() {
        guard !isTransitioning else { return }
        isTransitioning = true
        silenceTimer?.cancel()
        speechService.stopListening()

        // Use peak level during the line (not the level at completion time)
        let status: LineStatus
        let lineFeedback: String?
        let issue: String?

        switch linePeakLevel {
        case .normal:
            status = .natural
            lineFeedback = nil
            issue = nil
        case .caution, .warning:
            status = .warning
            issue = linePeakDominantIssue
            lineFeedback = linePeakFeedback
        case .cut:
            status = .ham
            issue = linePeakDominantIssue
            lineFeedback = linePeakFeedback
        }

        let result = LineResult(
            line: currentLine,
            status: status,
            feedback: lineFeedback,
            peakPitchRatio: session.baseline.averagePitch > 0
                ? linePeakPitch / session.baseline.averagePitch : nil,
            peakVolumeRatio: linePeakVolume - session.baseline.averageVolume,
            peakFacialIntensity: linePeakFacial,
            dominantIssue: issue
        )
        session.lineResults.append(result)

        fillProgress = 1.0

        speechTask = Task { [weak self] in
            guard let self else { return }
            await self.playLineHaptic()
            try? await Task.sleep(for: .seconds(0.7))
            await MainActor.run { self.advanceToNextLine() }
            guard !self.isCompleted else { return }
            try? await Task.sleep(for: .seconds(0.3))
            await self.listenForCurrentLine()
        }
    }

    private func advanceToNextLine() {
        resetLinePeaks()

        if currentLineIndex < totalLines - 1 {
            currentLineIndex += 1
        } else {
            stop()
            isCompleted = true
        }
    }

    private func resetLinePeaks() {
        smoothedPitch = session.baseline.averagePitch
        smoothedVolume = session.baseline.averageVolume
        smoothedFacial = 0
        smoothedPitchVar = 0
        smoothedVolSpike = 0
        smoothedFaceVel = 0
        prevVolume = session.baseline.averageVolume
        prevFacial = 0
        pitchBuffer = []
        linePeakPitch = 0
        linePeakVolume = 0
        linePeakFacial = 0
        linePeakLevel = .normal
        linePeakFeedback = nil
        linePeakDominantIssue = nil
        overactingLevel = .normal
        dismissHint()
        fillProgress = 0
    }

    // MARK: - Silence timer (3s: restart recognition, +2s: reset fill)

    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.0))
            guard !Task.isCancelled else { return }
            guard let self, !self.isTransitioning, !self.isCompleted else { return }

            self.speechService.stopListening()
            self.speechTask = Task {
                try? await Task.sleep(for: .seconds(0.3))
                await self.listenForCurrentLine()
            }

            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            guard !self.isTransitioning, !self.isCompleted else { return }

            await MainActor.run {
                self.fillProgress = 0
                self.bestMatchCount = 0
            }
        }
    }

    // MARK: - Haptics

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
}
