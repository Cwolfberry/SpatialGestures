import SwiftUI
import RealityKit

public struct DragGestureViewModifier: ViewModifier {
    
    @ObservedObject var manager: SpatialGestureManager
    // Drag state
    @State private var isDragging = false
    @State private var dragStartPosition = SIMD3<Float>.zero
    @State private var draggingEntityName: String = ""
    @State private var initialTransform: Transform?
    
    /// Initialize the drag gesture
    /// - Parameter manager: Spatial gesture manager
    public init(manager: SpatialGestureManager) {
        self.manager = manager
    }

    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture()
                    .targetedToAnyEntity()
                    .handActivationBehavior(.pinch) // Prevent moving objects by direct touch
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
                        
                        // Movement part
                        let location3D = value.convert(value.location3D, from: .local, to: .scene)
                        let translation3D = value.convert(value.translation3D, from: .local, to: .scene)
                        
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
                        
                        if !isDragging {
                            isDragging = true
                            dragStartPosition = foundEntity.position(relativeTo: nil)
                            draggingEntityName = entName
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
                    })
                    .onEnded { _ in
                        isDragging = false
                        
                        // Send gesture end callback
                        if let foundEntData = manager.getEntity(named: draggingEntityName) {
                            manager.notifyGestureEvent(SpatialGestureInfo(
                                gestureType: .gestureEnded,
                                entityName: draggingEntityName,
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
                                manager.notifyTransformChanged(draggingEntityName, relativePos)
                            } else {
                                relativePos.scale = transform.scale
                                relativePos.rotation = transform.rotation
                                
                                // Send transform message
                                manager.notifyTransformChanged(draggingEntityName, relativePos)
                            }
                        }
                        
                        draggingEntityName = ""
                        initialTransform = nil
                    }
            )
    }
}

public extension View {
    /// 添加拖拽手势
    /// - Parameter manager: 空间手势管理器
    /// - Returns: 添加了拖拽手势的视图
    func onDrag(manager: SpatialGestureManager) -> some View {
        modifier(DragGestureViewModifier(manager: manager))
    }
} 