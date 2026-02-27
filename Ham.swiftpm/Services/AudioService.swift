//
//  AudioService.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Extracts pitch (Hz) and volume (dB) from audio buffers using Accelerate/vDSP.
/// Receives buffers from SpeechService's shared AVAudioEngine tap.

import AVFoundation
import Accelerate

final class AudioService: AudioAnalyzable {

    private var continuation: AsyncStream<AudioLevel>.Continuation?
    private var _audioLevels: AsyncStream<AudioLevel>?

    var audioLevels: AsyncStream<AudioLevel> {
        if let existing = _audioLevels { return existing }
        let stream = AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
        _audioLevels = stream
        return stream
    }

    func analyzeBuffer(_ buffer: AVAudioPCMBuffer) {
        let volume = calculateRMS(buffer)
        let pitch = estimatePitch(buffer)

        guard pitch > 50, pitch < 500, volume > -60 else { return }
        continuation?.yield(AudioLevel(pitch: pitch, volume: volume))
    }

    func stopAnalyzing() {
        continuation?.finish()
        continuation = nil
        _audioLevels = nil
    }

    // MARK: - Volume (RMS → dB)

    /// dB = 20 × log10(RMS). vDSP_measqv computes mean square via SIMD acceleration.
    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return -100 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return -100 }

        var meanSquare: Float = 0
        vDSP_measqv(channelData, 1, &meanSquare, vDSP_Length(frameLength))

        guard meanSquare > 0 else { return -100 }
        return 20 * log10(sqrt(meanSquare))
    }

    // MARK: - Pitch (Autocorrelation)

    /// Autocorrelation-based F0 estimation.
    /// Searches for the lag with highest correlation in human voice range (85–300 Hz).
    /// F0 = sampleRate / bestLag.
    private func estimatePitch(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        guard frameLength > 0, sampleRate > 0 else { return 0 }

        let minLag = Int(sampleRate / 300)
        let maxLag = Int(sampleRate / 85)
        let searchEnd = min(maxLag, frameLength / 2)

        guard minLag < searchEnd else { return 0 }

        var bestLag = minLag
        var bestCorrelation: Float = -1

        for lag in minLag..<searchEnd {
            var correlation: Float = 0
            vDSP_dotpr(
                channelData, 1,
                channelData.advanced(by: lag), 1,
                &correlation,
                vDSP_Length(frameLength - lag)
            )
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        return sampleRate / Float(bestLag)
    }
}
