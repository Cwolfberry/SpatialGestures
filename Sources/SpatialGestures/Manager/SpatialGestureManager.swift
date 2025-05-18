import Foundation
import RealityKit
import SwiftUI
import Combine
import ARKit

/// AR手势类型枚举
public enum SpatialGestureType {
    /// 拖拽手势
    case drag
    /// 旋转手势
    case rotate
    /// 缩放手势
    case scale
    /// 手势结束
    case gestureEnded
    /// 放置手势
    case placement
}

/// 手势回调信息结构
public struct SpatialGestureInfo {
    /// 手势类型
    public let gestureType: SpatialGestureType
    /// 实体名称
    public let entityName: String
    /// 变换信息
    public let transform: Transform
    /// 初始变换（开始时）
    public let initialTransform: Transform?
    /// 变化值（如缩放系数，旋转角度等）
    public let changeValue: Any?
    
    /// 初始化手势信息
    public init(
        gestureType: SpatialGestureType,
        entityName: String,
        transform: Transform,
        initialTransform: Transform? = nil,
        changeValue: Any? = nil
    ) {
        self.gestureType = gestureType
        self.entityName = entityName
        self.transform = transform
        self.initialTransform = initialTransform
        self.changeValue = changeValue
    }
}

/// 手势回调类型
public typealias SpatialGestureCallback = (SpatialGestureInfo) -> Void

/// 空间手势管理器，负责管理实体和手势交互
@MainActor
public class SpatialGestureManager: ObservableObject {
    /// 活跃的实体列表
    @Published public var entities: [EntityData] = []
    
    /// 调试模式开关
    @Published public var isDebugEnabled: Bool = false
    
    /// 实体映射表，用于快速查找
    private var entityMap: [String: EntityData] = [:]
    
    /// 参考锚点实体
    public var referenceAnchor: Entity?
    
    /// 变换回调
    public var onTransformChanged: ((String, Transform) -> Void)?
    
    /// 手势回调
    public var onGestureCallback: SpatialGestureCallback?
    
    /// 平面检测管理器
    public var meshDetectionManager: MeshDetectionManager?
    
    /// enable mesh detection
    @Published public var isMeshDetectionEnabled: Bool = false
    
    /// placement status changed callback
    public var onPlacementStatusChanged: ((String, Bool, SIMD3<Float>?) -> Void)?

    // rotation axis
    public var rotationAxis: RotationAxis3D? = nil
    
    /// 初始化空间手势管理器
    /// - Parameters:
    ///   - referenceAnchor: 可选参考锚点
    ///   - enableMeshDetection: 是否启用平面检测，默认为false
    ///   - showDebugVisualization: 是否显示平面检测可视化，默认为false
    ///   - isDebugEnabled: 是否启用调试模式，默认为false
    @MainActor
    public init(
        referenceAnchor: Entity? = nil,
        enableMeshDetection: Bool = false,
        showDebugVisualization: Bool = false,
        isDebugEnabled: Bool = false,
        rotationAxis: RotationAxis3D? = nil
    ) {
        self.referenceAnchor = referenceAnchor
        self.isDebugEnabled = isDebugEnabled
        self.rotationAxis = rotationAxis
        
        if enableMeshDetection {
            meshDetectionManager = MeshDetectionManager(
                showDebugVisualization: showDebugVisualization,
                isDebugEnabled: isDebugEnabled
            )
        }
    }
    /// start mesh detection
    /// - Parameters:
    public func startMeshDetection(
        rootEntity: Entity
    ) async {
        guard let manager = meshDetectionManager else {
            if isDebugEnabled {
                print("Mesh detection manager not initialized. Call setupMeshDetection first.")
            }
            return
        }
        
        manager.rootEntity = rootEntity
        await manager.startMeshDetection()
        isMeshDetectionEnabled = true
        
        if isDebugEnabled {
            print("Mesh detection started")
        }
    }
    
    /// 停止平面检测
    public func stopMeshDetection() async {
        guard let manager = meshDetectionManager else { return }
        
        await manager.stopMeshDetection()
        isMeshDetectionEnabled = false
        
        if isDebugEnabled {
            print("Mesh detection stopped")
        }
    }
    
    /// set placement status changed callback
    /// - Parameter callback: callback function (entityName, canPlace, position)
    public func setPlacementStatusCallback(_ callback: @escaping (String, Bool, SIMD3<Float>?) -> Void) {
        self.onPlacementStatusChanged = callback
    }
    
    /// check if entity can be placed at current position
    /// - Parameters:
    ///   - entityName: entity name
    ///   - maxDistance: maximum valid distance
    /// - Returns: if can be placed
    @MainActor
    public func checkEntityPlacement(entity: Entity, maxDistance: Float = 0.3, hitPosition: SIMD3<Float>, hitDistance: Float) -> Bool {
        
        let canPlace = meshDetectionManager?.checkEntityPlacement(entity: entity, maxDistance: maxDistance, hitPosition: hitPosition, hitDistance: hitDistance) ?? false
        
        return canPlace
    }
    
    /// place entity to current valid position
    /// - Parameter entityName: entity name
    /// - Returns: if placed successfully
    @discardableResult
    @MainActor
    public func placeEntity(entity: Entity, entityName: String) -> Bool {
        guard let manager = meshDetectionManager else {
            return false
        }
        
        let success = manager.placeEntity(entity)
        
        if success {
            // Notify about placement if callbacks are set
            notifyGestureEvent(SpatialGestureInfo(
                gestureType: .placement,
                entityName: entityName,
                transform: entity.transform
            ))
        }
        
        return success
    }
    
    /// add entity to manager
    /// - Parameters:
    ///   - entity: entity to add
    ///   - name: entity name
    /// - Returns: added entity data
    @discardableResult
    @MainActor
    public func addEntity(
        _ entity: Entity,
        name: String
    ) async -> EntityData {
        let entityData = EntityData(entity: entity, name: name)
        entityMap[name] = entityData
        entities.append(entityData)
        
        // specify entity as input target
        entity.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
        // set collision volume
        await entity.generateCollisionShapes(recursive: true)
        
        if isDebugEnabled {
            print("[Entity Registered]: \(name)")
        }
        
        return entityData
    }
    
    /// find main entity from interacted entity
    /// - Parameter interactedEntity: interacted entity
    /// - Returns: found entity data and name
    @MainActor public func findEntityData(from interactedEntity: Entity) -> (EntityData?, String) {
        // try to match directly
        for entData in entities {
            let entity = entData.entity
            let name = entData.name
            
            // check if it is the main entity
            if entity == interactedEntity {
                return (entData, name)
            }
            
            var clone = interactedEntity
            while let parent = clone.parent {
                if parent == nil {
                    break
                }
                if parent == entity {
                    return (entData, name)
                }
                clone = parent
            }   
        }
        
        return (nil, "")
    }
    
    /// 移除实体
    /// - Parameter name: 实体名称
    public func removeEntity(named name: String) {
        if let index = entities.firstIndex(where: { $0.name == name }) {
            entities.remove(at: index)
            entityMap.removeValue(forKey: name)
            
            if isDebugEnabled {
                print("Entity removed: \(name)")
            }
        }
    }
    
    /// 获取实体
    /// - Parameter name: 实体名称
    /// - Returns: 实体数据（如果存在）
    public func getEntity(named name: String) -> EntityData? {
        return entityMap[name]
    }
    
    /// 发送变换消息
    /// - Parameters:
    ///   - entityName: 实体名称
    ///   - transform: 变换信息
    public func notifyTransformChanged(_ entityName: String, _ transform: Transform) {
        onTransformChanged?(entityName, transform)
    }
    
    /// 设置变换回调
    /// - Parameter callback: 回调函数
    public func setTransformChangedCallback(_ callback: @escaping (String, Transform) -> Void) {
        self.onTransformChanged = callback
    }
    
    /// 获取相对变换
    /// - Parameter transform: 原始变换
    /// - Returns: 相对于参考锚点的变换
    public func getRelativeTransform(_ transform: Transform) -> Transform {
        guard let anchor = referenceAnchor else { return transform }
        
        // 在非Main Actor上下文中无法直接调用convert方法，所以返回原始变换
        // 需要在调用者端使用MainActor包装
        // 例如: Task { @MainActor in let relativeTransform = anchor.convert(transform: transform, from: nil) }
        return transform
    }
    
    /// 获取相对变换（异步版本）
    /// - Parameter transform: 原始变换
    /// - Returns: 相对于参考锚点的变换
    @MainActor
    public func getRelativeTransformAsync(_ transform: Transform) async -> Transform {
        guard let anchor = referenceAnchor else { return transform }
        return anchor.convert(transform: transform, from: nil)
    }
    
    /// 设置手势回调
    /// - Parameter callback: 手势回调函数
    public func setGestureCallback(_ callback: @escaping SpatialGestureCallback) {
        self.onGestureCallback = callback
    }
    
    /// 通知手势事件
    /// - Parameter gestureInfo: 手势信息
    public func notifyGestureEvent(_ gestureInfo: SpatialGestureInfo) {
        onGestureCallback?(gestureInfo)
        
        if isDebugEnabled {
            let changeValueStr = gestureInfoString(gestureInfo)
            print("😀 SpatialGesture Debug: [\(gestureTypeString(gestureInfo.gestureType))] Entity: \(gestureInfo.entityName) \(changeValueStr)")
        }
    }
    
    /// 获取手势类型的字符串表示
    private func gestureTypeString(_ type: SpatialGestureType) -> String {
        switch type {
        case .drag:
            return "Drag"
        case .rotate:
            return "Rotate"
        case .scale:
            return "Magnify"
        case .gestureEnded:
            return "Gesture Ended"
        case .placement:
            return "Placement"
        }
    }
    
    /// 获取手势信息的字符串表示
    private func gestureInfoString(_ info: SpatialGestureInfo) -> String {
        var result = ""
        
        switch info.gestureType {
        case .drag:
            result += "position: \(info.transform.translation)"
            if let initialTransform = info.initialTransform {
                let offset = info.transform.translation - initialTransform.translation
                result += " offset: \(offset)"
            }
        case .rotate:
            result += "rotation: \(info.transform.rotation.convertToEulerAngles())"
            if let angle = info.changeValue as? Float {
                result += " angle: \(angle)"
            }
        case .scale:
            result += "scale: \(info.transform.scale)"
            if let magnification = info.changeValue as? Float {
                result += " magnification: \(magnification)"
            }
        case .gestureEnded:
            result += "position: \(info.transform.translation) rotation: \(info.transform.rotation.convertToEulerAngles()) scale: \(info.transform.scale)"
        case .placement:
            result += "position: \(info.transform.translation)"
        }
        
        return result
    }
    
    /// 启用或禁用调试模式
    /// - Parameter enabled: 是否启用调试
    @MainActor
    public func setDebugEnabled(_ enabled: Bool) {
        self.isDebugEnabled = enabled
        
        meshDetectionManager?.isDebugEnabled = enabled
    }
    
    /// 显示或隐藏平面检测可视化
    /// - Parameter show: 是否显示
    @MainActor
    public func setMeshDetectionVisualization(_ show: Bool) {
        meshDetectionManager?.setMeshDetectionVisualization(show)
    }
} 
