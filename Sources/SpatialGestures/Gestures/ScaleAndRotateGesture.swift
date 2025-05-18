import SwiftUI
import RealityKit

public struct ScaleAndRotateGestureViewModifier: ViewModifier {
    
    @ObservedObject var manager: SpatialGestureManager
    // Scale state
    @State private var isScaling = false
    @State private var initialScale = SIMD3<Float>.zero
    // Rotate state
    @State private var isRotating = false
    @State private var lastRotation: simd_quatf?
    // Common state
    @State private var entityName: String = ""
    @State private var initialTransform: Transform?
    
    // Rotation axis configuration
    private let rotationAxis: RotationAxis3D?
    
    /// Initialize the scale and rotate gesture
    /// - Parameters:
    ///   - manager: Spatial gesture manager
    ///   - rotationAxis: The axis to constrain rotation to (default is .y). Set to nil for unconstrained rotation.
    public init(
        manager: SpatialGestureManager, 
        rotationAxis: RotationAxis3D? = .y
    ) {
        self.manager = manager
        self.rotationAxis = rotationAxis
    }

    public func body(content: Content) -> some View {
        content
            .gesture(
                MagnifyGesture()
                    .simultaneously(
                        with: rotationAxis != nil ?
                            RotateGesture3D(constrainedToAxis: rotationAxis!) :
                            RotateGesture3D()
                    )
                    .targetedToAnyEntity()
                    .handActivationBehavior(.pinch)
                    .onChanged({ value in
                        let gestureEntity = value.entity
                        
                        // Use method to quickly find entity
                        let (foundEntData, entName) = manager.findEntityData(from: gestureEntity)
                        
                        guard let foundEntData = foundEntData, !entName.isEmpty else {
                            if manager.isDebugEnabled {
                                print("实体未找到:\(value.entity)")
                            }
                            return
                        }
                        
                        let foundEntity = foundEntData.entity
                        
                        // Save entity name
                        if entityName.isEmpty {
                            entityName = entName
                            initialTransform = foundEntity.transform
                        }
                        
                        // Handle scale gesture
                        if let scaleValue = value.first {
                            if !isScaling {
                                isScaling = true
                                initialScale = foundEntity.transform.scale
                            }
                            
                            // Calculate new scale value
                            let magnification = Float(scaleValue.magnification)
                            let newScale = initialScale * magnification
                            
                            // Set limits to prevent objects from scaling too large or too small
                            let minScale: Float = 0.01
                            let maxScale: Float = 500.0
                            
                            let clampedScale = SIMD3<Float>(
                                max(minScale, min(maxScale, newScale.x)),
                                max(minScale, min(maxScale, newScale.y)),
                                max(minScale, min(maxScale, newScale.z))
                            )
                            
                            foundEntity.transform.scale = clampedScale
                            
                            // Send gesture callback
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .scale,
                                entityName: entName,
                                transform: foundEntity.transform,
                                initialTransform: initialTransform,
                                changeValue: magnification
                            ))
                        }
                        
                        // Handle rotation gesture
                        if let rotationValue = value.second {
                            if !isRotating {
                                isRotating = true
                                if manager.isDebugEnabled {
                                    print("开始旋转, 实体旋转角度\(foundEntity.transform.rotation.convertToEulerAngles())")
                                }
                                lastRotation = foundEntity.transform.rotation
                            }
                            
                            var rotation3D = rotationValue.rotation
                            rotation3D.vector.z = -rotation3D.vector.z
                            let rotationTransform = Transform(AffineTransform3D(rotation: rotationValue.rotation))
                            
                            if (lastRotation == simd_quatf() || lastRotation == nil) {
                                foundEntity.transform.rotation = rotationTransform.rotation
                                lastRotation = rotationTransform.rotation
                            } else {
                                foundEntity.transform.rotation = lastRotation! * rotationTransform.rotation
                            }
                            
                            // Send gesture callback
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .rotate,
                                entityName: entName,
                                transform: foundEntity.transform,
                                initialTransform: initialTransform,
                                changeValue: nil
                            ))
                        }
                        
                        // Update transform and send message
                        var transform = foundEntity.transform
                        var relativeTransform = transform
                        if let anchor = manager.referenceAnchor {
                            // Use synchronous approach for better UX
                            relativeTransform = transform // Default if convert fails
                        }
                        
                        // Send transform message
                        manager.notifyTransformChanged(entName, relativeTransform)
                    })
                    .onEnded { _ in
                        isScaling = false
                        isRotating = false
                        
                        if let foundEntData = manager.getEntity(named: entityName) {
                            // Send gesture end callback
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .gestureEnded,
                                entityName: entityName,
                                transform: foundEntData.entity.transform,
                                initialTransform: initialTransform
                            ))
                            
                            // Update final transform
                            let transform = foundEntData.entity.transform
                            var relativeTransform = transform
                            if let anchor = manager.referenceAnchor {
                                // Use synchronous approach
                                relativeTransform = transform // Default if convert fails
                            }
                            
                            // Send final transform message
                            manager.notifyTransformChanged(entityName, relativeTransform)
                        }
                        
                        entityName = ""
                        initialTransform = nil
                        lastRotation = nil
                    }
            )
    }
}

public extension View {
    /// 添加缩放和旋转手势
    /// - Parameters:
    ///   - manager: 空间手势管理器
    ///   - rotationAxis: 旋转轴约束（默认为Y轴）。设置为nil则不约束旋转轴。
    /// - Returns: 添加了手势的视图
    func onScaleAndRotate(
        manager: SpatialGestureManager,
        rotationAxis: RotationAxis3D? = .y
    ) -> some View {
        modifier(ScaleAndRotateGestureViewModifier(
            manager: manager,
            rotationAxis: rotationAxis
        ))
    }
} 