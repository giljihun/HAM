//
//  SetupViewModel.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Setup ViewModel — manages scene preset selection and carousel scroll state.

import SwiftUI

@Observable
final class SetupViewModel {

    var selectedID: UUID?
    let presets = ScenePresets.all

    init() {
        selectedID = presets.first?.id
    }

    func selectPreset() -> ActingScene {
        presets.first { $0.id == selectedID } ?? presets[0]
    }
}
