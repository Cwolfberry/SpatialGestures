import Foundation
import RealityKit
import SwiftUI
import Combine

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
    
    /// 初始化空间手势管理器
    /// - Parameters:
    ///   - referenceAnchor: 可选参考锚点
    ///   - isDebugEnabled: 是否启用调试模式，默认为false
    public init(
        referenceAnchor: Entity? = nil, 
        isDebugEnabled: Bool = false
    ) {
        self.referenceAnchor = referenceAnchor
        self.isDebugEnabled = isDebugEnabled
    }
    
    /// 添加实体到管理器
    /// - Parameters:
    ///   - entity: 要添加的实体
    ///   - name: 实体名称
    /// - Returns: 添加的实体数据
    @discardableResult
    @MainActor
    public func addEntity(_ entity: Entity, name: String) async -> EntityData {
        let entityData = EntityData(entity: entity, name: name)
        entityMap[name] = entityData
        entities.append(entityData)
        
        // 指定Entity为输入目标！！！
        entity.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
        // 设置碰撞体积。 这两步操作也可以在 Reality Composer中进行
        await entity.generateCollisionShapes(recursive: true)
        
        
        if isDebugEnabled {
            print("[Entity Registered]: \(name)")
        }
        
        return entityData
    }
    
    /// 根据交互实体查找主实体
    /// - Parameter interactedEntity: 被交互的实体
    /// - Returns: 找到的实体数据和名称
    @MainActor public func findEntityData(from interactedEntity: Entity) -> (EntityData?, String) {
        // 首先尝试直接匹配
        for entData in entities {
            let entity = entData.entity
            let name = entData.name
            
            // 检查是否是主实体
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
        }
        
        return result
    }
    
    /// 启用或禁用调试模式
    /// - Parameter enabled: 是否启用调试
    public func setDebugEnabled(_ enabled: Bool) {
        self.isDebugEnabled = enabled
    }
} 
