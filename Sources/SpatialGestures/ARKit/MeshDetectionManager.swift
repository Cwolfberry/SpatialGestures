import Foundation
import RealityKit
import SwiftUI
import ARKit

/// Manager for handling mesh detection and entity placement
@MainActor
public class MeshDetectionManager: ObservableObject {
    /// ARKit session for mesh detection
    private var arkitSession: ARKitSession?
    /// Mesh detection provider
    private var meshDetection: SceneReconstructionProvider
    /// Root entity to attach meshes to
    var rootEntity: Entity
    
    /// Collection of detected mesh anchors indexed by ID
    @Published public var meshAnchorsByID: [UUID: MeshAnchor] = [:]
    /// Collection of detected mesh entities indexed by ID
    @Published public var meshEntities: [UUID: Entity] = [:]
    
    /// Whether mesh detection is currently active
    @Published public var isDetecting: Bool = false
    /// Whether debug visualization is enabled
    @Published public var showDebugVisualization: Bool = false
    
    /// Current placement position for an entity
    @Published public var placementPosition: SIMD3<Float>?
    /// Whether placement is possible at current position
    @Published public var canPlace: Bool = false
    
    /// Placement instruction entity (visual indicator for placement)
    public var placementInstructionEntity: Entity?
    
    /// Debug mode switch
    @Published public var isDebugEnabled: Bool = false
    
    /// Horizontal collision group for mesh collision detection
    public static let horizontalCollisionGroup: CollisionGroup = CollisionGroup(rawValue: 1 << 1)
    /// Vertical collision group for mesh collision detection
    public static let verticalCollisionGroup: CollisionGroup = CollisionGroup(rawValue: 1 << 2)
    
    /// Initializes the mesh detection manager
    /// - Parameters:
    ///   - showDebugVisualization: Whether to show debug visualization for meshes
    ///   - isDebugEnabled: Whether to enable debug logging
    public init(showDebugVisualization: Bool = false, isDebugEnabled: Bool = false) {
        self.showDebugVisualization = showDebugVisualization
        self.isDebugEnabled = isDebugEnabled
        
        // Initialize with horizontal mesh detection by default
        self.meshDetection = SceneReconstructionProvider(modes: [.classification])
        rootEntity = Entity()
    }
    
    /// Sets up the placement instruction entity
    private func setupPlacementInstructionEntity() {
        // Create a simple circular indicator for placement
        let material = SimpleMaterial(color: .green.withAlphaComponent(0.6), isMetallic: false)
        let mesh = MeshResource.generatePlane(width: 0.3, depth: 0.3, cornerRadius: 0.3)
        let modelComponent = ModelComponent(mesh: mesh, materials: [material])
        
        placementInstructionEntity = ModelEntity(components: [modelComponent])
        placementInstructionEntity?.name = "PlacementIndicator"
        placementInstructionEntity?.isEnabled = true
        
        placementInstructionEntity?.setPosition(SIMD3<Float>(0, 1.5, -1), relativeTo: nil)
        
        rootEntity.addChild(placementInstructionEntity!)
    }
    
    /// Starts scene reconstruction and mesh detection
    /// - Parameters:
    public func startMeshDetection() async {
        if !SceneReconstructionProvider.isSupported {
            if isDebugEnabled {
                print("Mesh detection is not supported on this device")
            }
            return
        }
        
        do {
            setupPlacementInstructionEntity()
            
            // Create and run ARKit session with mesh detection
            arkitSession = ARKitSession()
            
            try await arkitSession?.run([meshDetection])
            isDetecting = true
            
            // Start monitoring mesh updates
            Task {
                await processMeshUpdates()
            }
            
            // Start monitoring session events
            Task {
                await monitorSessionEvents()
            }
            
            if isDebugEnabled {
                print("Mesh detection started successfully")
            }
        } catch {
            if isDebugEnabled {
                print("Failed to start mesh detection: \(error)")
            }
            isDetecting = false
        }
    }
    
    /// Stops mesh detection
    public func stopMeshDetection() async {
        guard let session = arkitSession else { return }
        
        await session.stop()
        arkitSession = nil
        isDetecting = false
        
        // Clear meshes
        for entity in meshEntities.values {
            entity.removeFromParent()
        }
        meshEntities.removeAll()
        meshAnchorsByID.removeAll()
        
        if isDebugEnabled {
            print("Mesh detection stopped")
        }
    }
    
    /// Processes mesh anchor updates
    @MainActor
    private func processMeshUpdates() async {
        let updates = meshDetection.anchorUpdates
        
        for await anchorUpdate in updates {
            let anchor = anchorUpdate.anchor

            if anchorUpdate.event == .removed {
                meshAnchorsByID.removeValue(forKey: anchor.id)
                if let entity = meshEntities.removeValue(forKey: anchor.id) {
                    entity.removeFromParent()
                }
                return
            }

            meshAnchorsByID[anchor.id] = anchor
            
            guard let shape = try? await ShapeResource.generateStaticMesh(from: anchor) else { continue }

            let entity = ModelEntity()
            entity.name = "Mesh \(anchor.id)"
            entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
            entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
            entity.components.set(InputTargetComponent())
            entity.physicsBody = PhysicsBodyComponent(mode: .static)
            
            if showDebugVisualization {
                // set color by classification
                let classification = getAnchorClassification(anchor: anchor) ?? .none
                var color: UIColor
                switch classification {
                case .floor:
                    color = .blue
                case .table:
                    color = .green
                case .wall:
                    color = .red
                case .ceiling:
                    color = .yellow
                case .door:
                    color = .purple
                case .window:
                    color = .cyan
                case .seat:
                    color = .orange
                default:
                    color = .gray
                }
                
                var material = SimpleMaterial(color: color, isMetallic: false)
                material.triangleFillMode = .lines
                await entity.components.set(
                    ModelComponent(mesh: MeshResource(shape: shape), materials: [material])
                )
            } else {
                var material = OcclusionMaterial()
                await entity.components.set(
                    ModelComponent(mesh: MeshResource(shape: shape), materials: [material])
                )
            }
            
            
            // Replace existing entity if any
            let existingEntity = meshEntities[anchor.id]
            meshEntities[anchor.id] = entity
            
            rootEntity.addChild(entity)
            existingEntity?.removeFromParent()
        }
    }
    
    /// Monitors ARKit session events
    private func monitorSessionEvents() async {
        guard let session = arkitSession else { return }
        
        for await event in session.events {
            switch event {
            case .authorizationChanged(type: _, status: let status):
                if isDebugEnabled {
                    print("ARKit authorization changed to: \(status)")
                }
                
                if status == .denied {
                    // Handle authorization denied
                    await stopMeshDetection()
                }
                
            case .dataProviderStateChanged(dataProviders: let providers, newState: let state, error: let error):
                if isDebugEnabled {
                    print("ARKit data provider changed: \(providers), state: \(state)")
                    if let error {
                        print("ARKit data provider error: \(error)")
                    }
                }
                
            @unknown default:
                if isDebugEnabled {
                    print("Unknown ARKit session event: \(event)")
                }
            }
        }
    }
    
    /// Checks if an entity can be placed at its current position
    /// - Parameters:
    ///   - entity: The entity to check for placement
    ///   - maxDistance: Maximum distance from mesh for valid placement
    /// - Returns: True if the entity can be placed
    @MainActor
    public func checkEntityPlacement(entity: Entity, maxDistance: Float = 0.3, hitPosition: SIMD3<Float>, hitDistance: Float) -> Bool {
        if hitDistance < maxDistance {

            placementPosition = SIMD3<Float>(
                x: hitPosition.x,
                y: hitPosition.y + 0.001,
                z: hitPosition.z
            )
            
            placementInstructionEntity?.setPosition(placementPosition!, relativeTo: nil)
            placementInstructionEntity?.isEnabled = true
            
            // Scale based on proximity to mesh (larger when closer)
            let scale = hitDistance <= 0 ? 1.0 : 1.0 - (0.75 * (hitDistance / maxDistance))
            placementInstructionEntity?.transform.scale = SIMD3<Float>(scale, 1, scale)
            canPlace = true
        } else {
            placementInstructionEntity?.isEnabled = false
            canPlace = false
        }
        
        return canPlace
    }
    
    /// Places an entity at the current valid placement position
    /// - Parameter entity: Entity to place
    /// - Returns: True if placement was successful
    @discardableResult
    @MainActor
    public func placeEntity(_ entity: Entity) -> Bool {
        guard canPlace, let position = placementPosition else {
            return false
        }
        
        // Set the entity to the placement position
        entity.setPosition(position, relativeTo: nil)
        
        // Hide placement indicator
        placementInstructionEntity?.isEnabled = false
        
        if isDebugEnabled {
            print("Entity placed at \(position)")
        }
        
        return true
    }
    
    /// Helper function to determine the classification of an anchor
    /// - Parameter anchor: The anchor to check
    /// - Returns: The classification of the anchor
    private func getAnchorClassification(anchor: MeshAnchor) -> MeshAnchor.MeshClassification? {
        if let classifications = anchor.geometry.classifications {
            // Get the dominant classification from the mesh
            // This is a simplified approach - consider a more sophisticated method if needed
            var classificationCounts: [MeshAnchor.MeshClassification: Int] = [:]
            
            // Count occurrences of each classification
            for faceIndex in 0..<anchor.geometry.faces.count {
                if let classRawValue = classifications[faceIndex] {
                    let classification = MeshAnchor.MeshClassification(rawValue: Int(classRawValue))!
                    classificationCounts[classification, default: 0] += 1
                }
            }
            
            // Find the most common classification
            let dominantClassification = classificationCounts.max(by: { $0.value < $1.value })?.key
            
            // Map MeshAnchor.MeshClassification to MeshAnchor.MeshClassification
            return dominantClassification
        }
        return nil
    }

    // setMeshDetectionVisualization
    @MainActor
    public func setMeshDetectionVisualization(_ show: Bool) {
        showDebugVisualization = show
        // handle all entities material
        for entity in meshEntities.values {
            if var model = entity.components[ModelComponent.self] {
                if show {
                    var material = SimpleMaterial(color: .blue, isMetallic: false)
                    material.triangleFillMode = .lines
                    model.materials = [material]
                } else {
                    model.materials = [OcclusionMaterial()]
                }
            }
        }
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        return SIMD3<Scalar>(x, y, z)
    }
}

/// Extension to access GeometrySource elements using subscript notation
extension GeometrySource {
    subscript(index: Int) -> UInt8? {
        // Ensure index is within bounds
        guard index < self.count && index >= 0 else {
            return nil
        }
        
        // Get the buffer (which is not optional)
        let buffer = self.buffer
        
        // Calculate byte offset based on format, stride, and index
        let byteOffset = self.offset + (index * self.stride)
        
        // Make sure we're within buffer bounds
        guard byteOffset + MemoryLayout<UInt8>.size <= buffer.length else {
            return nil
        }
        
        // Get a pointer to the data and read the UInt8 value
        return buffer.contents().load(fromByteOffset: byteOffset, as: UInt8.self)
    }
}
