import SwiftUI
import RealityKit

public struct ScaleGestureViewModifier: ViewModifier {
    
    @ObservedObject var manager: SpatialGestureManager
    @State private var isScaling = false
    @State private var initialScale = SIMD3<Float>.zero
    @State private var scalingEntityName: String = ""
    @State private var initialTransform: Transform?
    
    public init(manager: SpatialGestureManager) {
        self.manager = manager
    }

    public func body(content: Content) -> some View {
        content
            .gesture(
                MagnifyGesture()
                    .targetedToAnyEntity()
                    .handActivationBehavior(.pinch)
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
                        
                        if !isScaling {
                            isScaling = true
                            initialScale = foundEntity.transform.scale
                            scalingEntityName = entName
                            initialTransform = foundEntity.transform
                        }
                        
                        // Calculate new scale value
                        let magnification = Float(value.magnification)
                        let newScale = initialScale * magnification
                        
                        // Set limits to prevent objects from scaling too large or too small
                        let minScale: Float = 0.1
                        let maxScale: Float = 5.0
                        
                        let clampedScale = SIMD3<Float>(
                            max(minScale, min(maxScale, newScale.x)),
                            max(minScale, min(maxScale, newScale.y)),
                            max(minScale, min(maxScale, newScale.z))
                        )
                        
                        foundEntity.transform.scale = clampedScale
                        
                        // Update transform and send message
                        var transform = foundEntity.transform
                        var relativeTransform = transform
                        if let anchor = manager.referenceAnchor {
                            relativeTransform = anchor.convert(transform: transform, from: nil)
                        }
                        
                        // Send scale message
                        manager.notifyTransformChanged(entName, relativeTransform)
                        
                        // Send gesture callback
                        manager.notifyGestureEvent(SpatialGestureInfo(
                            gestureType: .scale,
                            entityName: entName,
                            transform: foundEntity.transform,
                            initialTransform: initialTransform,
                            changeValue: magnification
                        ))
                    })
                    .onEnded { _ in
                        isScaling = false
                        
                        if let foundEntData = manager.getEntity(named: scalingEntityName) {
                            let transform = foundEntData.entity.transform
                            var relativeTransform = transform
                            if let anchor = manager.referenceAnchor {
                                relativeTransform = anchor.convert(transform: transform, from: nil)
                            }
                            
                            // Send final scale message
                            manager.notifyTransformChanged(scalingEntityName, relativeTransform)
                            
                            // Send gesture end callback
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .gestureEnded,
                                entityName: scalingEntityName,
                                transform: transform,
                                initialTransform: initialTransform
                            ))
                        }
                        
                        scalingEntityName = ""
                        initialTransform = nil
                    }
            )
    }
}

public extension View {
    /// Add scale gesture
    /// - Parameter manager: Spatial gesture manager
    /// - Returns: View with added scale gesture
    func onScale(manager: SpatialGestureManager) -> some View {
        modifier(ScaleGestureViewModifier(manager: manager))
    }
} 