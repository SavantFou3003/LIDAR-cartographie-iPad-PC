import Foundation
import ARKit

struct PointData: Codable {
    let x: Float
    let y: Float
    let z: Float
    let gray: Float

    var position: SIMD3<Float> { SIMD3(x, y, z) }
}

final class PointExtractor {
    private let downsampleRatio: Float
    private let maxPoints: Int

    init(downsampleRatio: Float = 0.25, maxPoints: Int = 10_000) {
        self.downsampleRatio = max(0.01, min(1.0, downsampleRatio))
        self.maxPoints = max(100, maxPoints)
    }

    func extractPoints(from frame: ARFrame) -> [PointData] {
        let meshPoints = meshVertices(from: frame)
        let points = meshPoints.isEmpty ? featurePoints(from: frame) : meshPoints
        guard !points.isEmpty else { return [] }

        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x,
                                          cameraTransform.columns.3.y,
                                          cameraTransform.columns.3.z)

        var filtered: [SIMD3<Float>] = []
        filtered.reserveCapacity(min(points.count, maxPoints))
        let strideValue = max(1, Int(1.0 / Double(downsampleRatio)))
        for (index, position) in points.enumerated() where index % strideValue == 0 {
            filtered.append(position)
            if filtered.count >= maxPoints { break }
        }

        let distances = filtered.map { simd_distance($0, cameraPosition) }
        guard let minDistance = distances.min(), let maxDistance = distances.max(), maxDistance > minDistance else {
            return filtered.map { PointData(x: $0.x, y: $0.y, z: $0.z, gray: 0.5) }
        }

        let denominator = max(maxDistance - minDistance, 0.001)
        return zip(filtered, distances).map { position, distance in
            let normalized = max(0, min(1, (distance - minDistance) / denominator))
            return PointData(x: position.x, y: position.y, z: position.z, gray: normalized)
        }
    }

    private func meshVertices(from frame: ARFrame) -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []
        for anchor in frame.anchors.compactMap({ $0 as? ARMeshAnchor }) {
            let geometry = anchor.geometry
            let vertexBuffer = geometry.vertices
            let vertexPointer = vertexBuffer.buffer.contents().advanced(by: vertexBuffer.offset)
            let vertices = vertexPointer.bindMemory(to: SIMD3<Float>.self, capacity: geometry.vertexCount)
            let transform = anchor.transform
            for index in stride(from: 0, to: geometry.vertexCount, by: 4) {
                let vertex = vertices[index]
                let worldPosition = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                positions.append(SIMD3<Float>(worldPosition.x, worldPosition.y, worldPosition.z))
            }
        }
        return positions
    }

    private func featurePoints(from frame: ARFrame) -> [SIMD3<Float>] {
        guard let featurePoints = frame.rawFeaturePoints?.points else { return [] }
        return featurePoints
    }
}
