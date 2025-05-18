import SwiftUI
import RealityKit

public struct DragGestureViewModifier: ViewModifier {
    
    @ObservedObject var manager: SpatialGestureManager
    // Drag state
    @State private var isDragging = false
    @State private var dragStartPosition = SIMD3<Float>.zero
    @State private var draggingEntityName: String = ""
    @State private var initialTransform: Transform?
    @State private var canPlace: Bool = false
    
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
                        
                        // raycast
                        let result = value.entity.scene?.raycast(origin: foundEntity.position, direction: SIMD3<Float>(0, -1, 0))
                        
                        if result != nil && result?.count ?? 0 > 0 {
                            let collison = result![0]
                            let collisonEntity = collison.entity
                            
                            canPlace = manager.checkEntityPlacement(entity: foundEntity, maxDistance: 0.3, hitPosition: collison.position, hitDistance: collison.distance)
                            if manager.isDebugEnabled {
                                print("Can place \(entName) at current position: \(canPlace)")
                            }
                            
                            // Notify placement status if callback exists
                            manager.onPlacementStatusChanged?(entName, canPlace, foundEntity.position)
                        }
                        
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
                            
                            if canPlace {
                                manager.placeEntity(entity: foundEntData.entity, entityName: draggingEntityName)
                            }
                        }
                        
                        draggingEntityName = ""
                        initialTransform = nil
                        canPlace = false
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
