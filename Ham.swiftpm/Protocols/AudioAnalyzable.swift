//
//  AudioAnalyzable.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Protocol for audio analysis — extracts pitch (Hz) and volume (dB) from audio buffers.
/// Only one tap can be installed on AVAudioEngine's inputNode, so SpeechService
/// calls analyzeBuffer() from its shared tap callback.

import AVFoundation

struct AudioLevel {
    let pitch: Float   // Hz
    let volume: Float  // dB
}

protocol AudioAnalyzable: AnyObject {
    func analyzeBuffer(_ buffer: AVAudioPCMBuffer)
    var audioLevels: AsyncStream<AudioLevel> { get }
    func stopAnalyzing()
}
