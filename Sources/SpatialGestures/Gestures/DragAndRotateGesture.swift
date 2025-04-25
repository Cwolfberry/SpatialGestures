import SwiftUI
import RealityKit

public struct DragAndRotateGestureViewModifier: ViewModifier {
    
    @ObservedObject var manager: SpatialGestureManager
    // Drag state
    @State private var isDraging = false
    @State private var isRotating = false
    @State private var dragStartPosition = SIMD3<Float>.zero
    @State private var lastRotation: simd_quatf?
    @State private var dragingEntityName: String = ""
    @State private var initialTransform: Transform?
    
    // Rotation axis configuration
    private let rotationAxis: RotationAxis3D?
    private let rotationEnabled: Bool
    
    /// Initialize the drag and rotate gesture
    /// - Parameters:
    ///   - manager: Spatial gesture manager
    ///   - rotationAxis: The axis to constrain rotation to (default is .y). Set to nil for unconstrained rotation.
    ///   - rotationEnabled: Whether rotation is enabled (default is true)
    public init(
        manager: SpatialGestureManager, 
        rotationAxis: RotationAxis3D? = .y,
        rotationEnabled: Bool = true
    ) {
        self.manager = manager
        self.rotationAxis = rotationAxis
        self.rotationEnabled = rotationEnabled
    }

    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture()
                    .simultaneously(
                        with: rotationEnabled ? 
                            (rotationAxis != nil ? 
                                RotateGesture3D(constrainedToAxis: rotationAxis!) : 
                                RotateGesture3D()) : 
                            nil
                    )
                    .targetedToAnyEntity()
                    .handActivationBehavior(.pinch) // Prevent moving objects by direct touch
                    .onChanged({ value in
                        let gestureEntity = value.entity
                        
                        // Use new method to quickly find entity
                        let (foundEntData, entName) = manager.findEntityData(from: gestureEntity)
                        
                        guard let foundEntData = foundEntData, !entName.isEmpty else {
                            if manager.isDebugEnabled {
                                print("Entity not found:\(value.entity)")
                            }
                            return
                        }
                        
                        let foundEntity = foundEntData.entity
                        // Rotation part
                        if rotationEnabled, let rotationValue = value.second {
                            
                            var rotation3D = rotationValue.rotation
                            rotation3D.vector.z = -rotation3D.vector.z
                            let rotationTransform = Transform(AffineTransform3D(rotation: rotationValue.rotation))
                            
                            var relativeRotation = rotationTransform
                            if let anchor = manager.referenceAnchor {
                                // Use a synchronous approach for better user experience
                                // The @MainActor isolation will be handled at usage time
                                relativeRotation = rotationTransform // Use rotation as is if convert fails
                                relativeRotation.translation = foundEntity.transform.translation
                                relativeRotation.scale = foundEntity.transform.scale

                                // Send transform message
                                manager.notifyTransformChanged(entName, relativeRotation)
                            } else {
                                relativeRotation.translation = foundEntity.transform.translation
                                relativeRotation.scale = foundEntity.transform.scale
                                
                                // Send transform message
                                manager.notifyTransformChanged(entName, relativeRotation)
                            }
                            
                            if !isRotating {
                                isRotating = true
                                if manager.isDebugEnabled {
                                    print("Starting rotation, entity rotation\(foundEntity.transform.rotation.convertToEulerAngles())")
                                }
                                lastRotation = foundEntity.transform.rotation
                                dragingEntityName = entName
                                initialTransform = foundEntity.transform
                            }
                            
                            if (lastRotation == simd_quatf() || lastRotation == nil) {
                                foundEntity.transform.rotation = rotationTransform.rotation
                                lastRotation = rotationTransform.rotation
                            } else {
                                foundEntity.transform.rotation = lastRotation! * rotationTransform.rotation
                            }
                            
                            // Send gesture callback
                            // We're updating the transform, not calculating a specific angle
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .rotate,
                                entityName: entName,
                                transform: foundEntity.transform,
                                initialTransform: initialTransform,
                                changeValue: nil
                            ))
                                                    
                        } else if let transformValue = value.first {
                            // Movement part
                            let location3D = value.convert(transformValue.location3D, from: .local, to: .scene)
                            let translation3D = value.convert(transformValue.translation3D, from: .local, to: .scene)
                            
                            var transform = foundEntity.transform
                            // Set translation
                            transform.translation = SIMD3<Float>(x: Float(location3D.x),
                                                                 y: Float(location3D.y),
                                                                 z: Float(location3D.z))
                            
                            var relativePos = transform
                            if let anchor = manager.referenceAnchor {
                                // Use synchronous approach for better UX
                                relativePos = transform // Default if convert fails
                                relativePos.scale = transform.scale
                                relativePos.rotation = transform.rotation
                                
                                // Send transform message
                                manager.notifyTransformChanged(entName, relativePos)
                            } else {
                                relativePos.scale = transform.scale
                                relativePos.rotation = transform.rotation
                                
                                // Send transform message
                                manager.notifyTransformChanged(entName, relativePos)
                            }
                            
                            if !isDraging {
                                isDraging = true
                                dragStartPosition = foundEntity.position(relativeTo: nil)
                                dragingEntityName = entName
                                initialTransform = foundEntity.transform
                            }
                            let offset = SIMD3<Float>(x: Float(translation3D.x),
                                                      y: Float(translation3D.y),
                                                      z: Float(translation3D.z))
                            
                            let newPos = dragStartPosition + offset
                            foundEntity.setPosition(newPos, relativeTo: nil)
                            
                            // Send gesture callback
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .drag,
                                entityName: entName,
                                transform: foundEntity.transform,
                                initialTransform: initialTransform,
                                changeValue: offset
                            ))
                        }
                    })
                    .onEnded { _ in
                        isDraging = false
                        isRotating = false
                        
                        // Send gesture end callback
                        if let foundEntData = manager.getEntity(named: dragingEntityName) {
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .gestureEnded,
                                entityName: dragingEntityName,
                                transform: foundEntData.entity.transform,
                                initialTransform: initialTransform
                            ))
                            
                            let transform = foundEntData.entity.transform
                            var relativePos = transform
                            if let anchor = manager.referenceAnchor {
                                // Use synchronous approach
                                relativePos = transform // Default if convert fails
                                relativePos.scale = transform.scale
                                relativePos.rotation = transform.rotation
                                
                                // Send transform message
                                manager.notifyTransformChanged(dragingEntityName, relativePos)
                            } else {
                                relativePos.scale = transform.scale
                                relativePos.rotation = transform.rotation
                                
                                // Send transform message
                                manager.notifyTransformChanged(dragingEntityName, relativePos)
                            }
                        }
                        
                        dragingEntityName = ""
                        initialTransform = nil
                    }
            )
    }
}

public extension View {
    /// Add drag and rotate gesture
    /// - Parameters:
    ///   - manager: Spatial gesture manager
    ///   - rotationAxis: The axis to constrain rotation to (default is .y). Set to nil for unconstrained rotation.
    ///   - rotationEnabled: Whether rotation is enabled (default is true)
    /// - Returns: View with added gestures
    func onDragAndRotate(
        manager: SpatialGestureManager,
        rotationAxis: RotationAxis3D? = .y,
        rotationEnabled: Bool = true
    ) -> some View {
        modifier(DragAndRotateGestureViewModifier(
            manager: manager,
            rotationAxis: rotationAxis,
            rotationEnabled: rotationEnabled
        ))
    }
    
    /// Add drag-only gesture (no rotation)
    /// - Parameter manager: Spatial gesture manager
    /// - Returns: View with added gesture
    func onDragOnly(manager: SpatialGestureManager) -> some View {
        modifier(DragAndRotateGestureViewModifier(
            manager: manager,
            rotationEnabled: false
        ))
    }
} 