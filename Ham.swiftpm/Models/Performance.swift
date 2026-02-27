//
//  Performance.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Core data models for voice calibration, overacting detection levels, and line results.

import SwiftUI

// MARK: - Voice Baseline

/// Running average of the user's natural voice, collected during onboarding calibration.
struct VoiceBaseline: Codable {
    var averagePitch: Float = 0
    var averageVolume: Float = 0
    var sampleCount: Int = 0

    /// Running average: newAvg = (oldAvg × (n-1) + sample) / n
    mutating func update(pitch: Float, volume: Float) {
        sampleCount += 1
        averagePitch = (averagePitch * Float(sampleCount - 1) + pitch) / Float(sampleCount)
        averageVolume = (averageVolume * Float(sampleCount - 1) + volume) / Float(sampleCount)
    }
}

// MARK: - Overacting Detection

/// Real-time overacting severity level, escalated based on deviation from baseline.
///
/// THRESHOLD TUNING (in ActionViewModel.updateOveractingLevel):
///   normal  → combined < 1.15
///   caution → 1.15 ..< 1.26
///   warning → 1.26 ..< 1.70
///   cut     → 1.70+
enum OveractingLevel: Int, Comparable {
    case normal = 0
    case caution = 1
    case warning = 2
    case cut = 3

    static func < (lhs: OveractingLevel, rhs: OveractingLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Performance Result

enum LineStatus {
    case natural
    case passed
    case flat
    case warning
    case ham

    var color: Color {
        switch self {
        case .natural: return Theme.systemGreen
        case .passed:  return .blue
        case .flat:    return .blue.opacity(0.7)
        case .warning: return Theme.systemOrange
        case .ham:     return Theme.systemRed
        }
    }

    var label: String {
        switch self {
        case .natural: return "Natural"
        case .passed:  return "Passed"
        case .flat:    return "Too flat"
        case .warning: return "A bit much"
        case .ham:     return "Total ham"
        }
    }
}

struct LineResult: Identifiable {
    let id = UUID()
    let line: String
    let status: LineStatus
    let feedback: String?
    let peakPitchRatio: Float?
    let peakVolumeRatio: Float?
    let peakFacialIntensity: Float?
    let dominantIssue: String?
}
