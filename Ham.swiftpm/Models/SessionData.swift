//
//  SessionData.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Single source of truth for app session — baseline, scene selection, and results.
/// @Observable tracks property-level changes: only views reading a changed property re-render.

import SwiftUI

@Observable
final class SessionData {
    // MARK: - Calibration

    var baseline = VoiceBaseline()
    var isCalibrated: Bool { baseline.sampleCount > 0 }

    // MARK: - Scene selection

    var selectedScene: ActingScene?

    // MARK: - Results

    var lineResults: [LineResult] = []

    // MARK: - Navigation

    var currentScreen: Screen = .onboarding

    // MARK: - Persistence

    private let baselineKey = "com.ham.voiceBaseline"
    private var baselineSaved = false

    /// Saves baseline with 0.93 discount — onboarding voice is slightly louder than natural.
    func saveBaseline() {
        guard !baselineSaved else { return }
        baselineSaved = true
        baseline.averagePitch *= 0.93
        baseline.averageVolume *= 0.93
        if let data = try? JSONEncoder().encode(baseline) {
            UserDefaults.standard.set(data, forKey: baselineKey)
        }
    }

    func loadBaseline() {
        guard let data = UserDefaults.standard.data(forKey: baselineKey),
              let saved = try? JSONDecoder().decode(VoiceBaseline.self, from: data) else { return }
        baseline = saved
    }

    func resetBaseline() {
        baseline = VoiceBaseline()
        baselineSaved = false
        UserDefaults.standard.removeObject(forKey: baselineKey)
    }

    func resetResults() {
        lineResults = []
    }
}
