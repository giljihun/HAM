//
//  ARCameraView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// UIViewRepresentable wrapper for ARSCNView — bridges ARKit camera feed into SwiftUI.

import SwiftUI
import ARKit

struct ARCameraView: UIViewRepresentable {
    let sceneView: ARSCNView

    func makeUIView(context: Context) -> ARSCNView {
        sceneView.scene = SCNScene()
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
