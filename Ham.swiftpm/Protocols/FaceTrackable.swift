//
//  FaceTrackable.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Protocol for ARKit face tracking — extracts 7 key blend shapes for overacting detection.

import ARKit

/// Facial expression data from ARKit's 52 blend shapes.
/// overallIntensity weights: brow(30%) + jaw(25%) + frown(25%) + squint(20%).
struct FaceMetrics {
    let browDownLeft: Float
    let browDownRight: Float
    let jawOpen: Float
    let mouthFrownLeft: Float
    let mouthFrownRight: Float
    let eyeSquintLeft: Float
    let eyeSquintRight: Float

    var overallIntensity: Float {
        let brow = (browDownLeft + browDownRight) / 2
        let mouth = jawOpen
        let frown = (mouthFrownLeft + mouthFrownRight) / 2
        let squint = (eyeSquintLeft + eyeSquintRight) / 2
        return brow * 0.3 + mouth * 0.25 + frown * 0.25 + squint * 0.2
    }

    var dominantFeature: String {
        let features: [(String, Float)] = [
            ("brow tension", (browDownLeft + browDownRight) / 2),
            ("jaw opening", jawOpen),
            ("mouth frowning", (mouthFrownLeft + mouthFrownRight) / 2),
            ("eye squinting", (eyeSquintLeft + eyeSquintRight) / 2)
        ]
        return features.max(by: { $0.1 < $1.1 })?.0 ?? "facial expression"
    }
}

protocol FaceTrackable: AnyObject {
    var faceMetrics: AsyncStream<FaceMetrics> { get }
    func startTracking()
    func stopTracking()
    var sceneView: ARSCNView? { get }
    static var isAvailable: Bool { get }
}
