import SwiftUI
import ARKit
import SceneKit

struct LidarView: UIViewRepresentable {
    let pointExtractor: PointExtractor
    let webSocketClient: WebSocketClient

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.preferredFramesPerSecond = 30
        view.scene = SCNScene()
        view.scene.rootNode.addChildNode(context.coordinator.pointNode)

        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        configuration.frameSemantics = .sceneDepth
        view.session.run(configuration)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // handled via delegate updates
    }

    final class Coordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
        private let parent: LidarView
        fileprivate let pointNode = SCNNode()
        private let processingQueue = DispatchQueue(label: "PointProcessingQueue")
        private var lastTransmissionTime = Date(timeIntervalSince1970: 0)

        init(parent: LidarView) {
            self.parent = parent
            super.init()
            pointNode.geometry = SCNGeometry()
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            processingQueue.async { [weak self] in
                guard let self = self else { return }
                let points = self.parent.pointExtractor.extractPoints(from: frame)
                guard !points.isEmpty else { return }
                self.updateScene(with: points)
                self.transmit(points: points)
            }
        }

        private func updateScene(with points: [PointData]) {
            let vertexValues: [Float] = points.flatMap { [$0.position.x, $0.position.y, $0.position.z] }
            let colorValues: [Float] = points.flatMap { [$0.gray, $0.gray, $0.gray, 1.0] }
            let indices: [UInt32] = (0..<points.count).map { UInt32($0) }

            let vertexData = vertexValues.withUnsafeBufferPointer { Data(buffer: $0) }
            let colorData = colorValues.withUnsafeBufferPointer { Data(buffer: $0) }
            let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }

            let vertexSource = SCNGeometrySource(data: vertexData,
                                                 semantic: .vertex,
                                                 vectorCount: points.count,
                                                 usesFloatComponents: true,
                                                 componentsPerVector: 3,
                                                 bytesPerComponent: MemoryLayout<Float>.size,
                                                 dataOffset: 0,
                                                 dataStride: MemoryLayout<Float>.size * 3)

            let colorSource = SCNGeometrySource(data: colorData,
                                                semantic: .color,
                                                vectorCount: points.count,
                                                usesFloatComponents: true,
                                                componentsPerVector: 4,
                                                bytesPerComponent: MemoryLayout<Float>.size,
                                                dataOffset: 0,
                                                dataStride: MemoryLayout<Float>.size * 4)

            let element = SCNGeometryElement(data: indexData,
                                             primitiveType: .point,
                                             primitiveCount: points.count,
                                             bytesPerIndex: MemoryLayout<UInt32>.size)

            let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
            geometry.firstMaterial?.lightingModel = .constant
            geometry.firstMaterial?.isDoubleSided = true
            geometry.firstMaterial?.pointSize = 4

            DispatchQueue.main.async {
                self.pointNode.geometry = geometry
            }
        }

        private func transmit(points: [PointData]) {
            let now = Date()
            guard now.timeIntervalSince(lastTransmissionTime) > 0.1 else { return }
            lastTransmissionTime = now
            parent.webSocketClient.send(points: points)
        }
    }
}
