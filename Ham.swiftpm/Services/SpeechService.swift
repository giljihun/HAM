//
//  SpeechService.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// On-device speech recognition via SFSpeechRecognizer.
/// Audio engine tap runs continuously; only recognition sessions restart per line.
/// Uses requiresOnDeviceRecognition = true for offline SSC compliance.

import Speech
import AVFoundation

final class SpeechService: SpeechRecognizable {

    let audioService: AudioService

    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isEngineRunning = false
    private var currentContinuation: AsyncStream<String>.Continuation?

    init(audioService: AudioService = AudioService()) {
        self.audioService = audioService
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: AppConfig.shared.locale))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            ?? SFSpeechRecognizer()!
    }

    func requestAuthorization() async -> Bool {
        let micOK = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard micOK else { return false }

        let speechOK = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        return speechOK
    }

    // MARK: - Engine (started once, kept alive)

    private func ensureEngineRunning() throws {
        guard !isEngineRunning else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.audioService.analyzeBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isEngineRunning = true
    }

    // MARK: - Recognition session

    func startListening() -> AsyncStream<String> {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        currentContinuation?.finish()

        return AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            self.currentContinuation = continuation

            do {
                try self.ensureEngineRunning()
            } catch {
                continuation.finish()
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true
            self.recognitionRequest = request

            self.recognitionTask = self.speechRecognizer.recognitionTask(with: request) { result, error in
                if let result {
                    continuation.yield(result.bestTranscription.formattedString)
                }
                if error != nil || (result?.isFinal ?? false) {
                    continuation.finish()
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.recognitionRequest?.endAudio()
                self?.recognitionTask?.cancel()
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
            }
        }
    }

    func stopListening() {
        currentContinuation?.finish()
        currentContinuation = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    func shutdown() {
        stopListening()
        if isEngineRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            isEngineRunning = false
        }
    }
}
