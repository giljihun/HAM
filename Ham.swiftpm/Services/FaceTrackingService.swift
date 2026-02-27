//
//  FaceTrackingService.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// ARKit face tracking service — extracts blend shapes each frame via ARSCNViewDelegate.
/// Requires TrueDepth camera. Returns empty stream on Simulator.

import ARKit
import SceneKit

final class FaceTrackingService: NSObject, FaceTrackable, ARSCNViewDelegate {

    static var isAvailable: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    private let _sceneView = ARSCNView()
    var sceneView: ARSCNView? { Self.isAvailable ? _sceneView : nil }

    private var continuation: AsyncStream<FaceMetrics>.Continuation?

    lazy var faceMetrics: AsyncStream<FaceMetrics> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    override init() {
        super.init()
        guard Self.isAvailable else { return }
        _sceneView.delegate = self
        _sceneView.automaticallyUpdatesLighting = false
    }

    func startTracking() {
        guard Self.isAvailable else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        _sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stopTracking() {
        if Self.isAvailable {
            _sceneView.session.pause()
        }
        continuation?.finish()
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        let bs = faceAnchor.blendShapes

        let metrics = FaceMetrics(
            browDownLeft: bs[.browDownLeft]?.floatValue ?? 0,
            browDownRight: bs[.browDownRight]?.floatValue ?? 0,
            jawOpen: bs[.jawOpen]?.floatValue ?? 0,
            mouthFrownLeft: bs[.mouthFrownLeft]?.floatValue ?? 0,
            mouthFrownRight: bs[.mouthFrownRight]?.floatValue ?? 0,
            eyeSquintLeft: bs[.eyeSquintLeft]?.floatValue ?? 0,
            eyeSquintRight: bs[.eyeSquintRight]?.floatValue ?? 0
        )

        continuation?.yield(metrics)
    }
}
