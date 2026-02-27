//
//  Scene.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Acting scene model and onboarding monologue data.

import Foundation

struct ActingScene: Identifiable {
    let id = UUID()
    let title: String
    let situation: String
    let role: String
    let lines: [String]
}

/// Monologue text read during onboarding voice calibration.
enum OnboardingData {
    static let monologue: [String] = [
        "I am an actor.",
        "But the director always says",
        "my acting is... too much.",
        "Today, I must be natural.",
        "Speak, not perform.",
        "Let me check today's script."
    ]
}
