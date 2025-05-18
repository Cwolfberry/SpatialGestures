// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import RealityKit

/// SpatialGestures 是一个为 VisionOS 的 Entity 提供空间交互手势能力的包
/// 包括拖拽、旋转和缩放功能
public struct SpatialGestures {
    /// 包版本
    public static let version = "1.1.0"
    
    /// 初始化并创建一个空间手势管理器
    /// - Parameters:
    ///   - referenceAnchor: 可选的参考锚点
    ///   - isDebugEnabled: 是否启用调试模式，默认为false
    /// - Returns: 空间手势管理器实例
    @MainActor public static func createManager(
        referenceAnchor: Entity? = nil,
        enableMeshDetection: Bool = false,
        showDebugVisualization: Bool = false,
        isDebugEnabled: Bool = false,
        rotationAxis: RotationAxis3D? = nil
    ) -> SpatialGestureManager {
        return SpatialGestureManager(
            referenceAnchor: referenceAnchor,
            enableMeshDetection: enableMeshDetection,
            showDebugVisualization: showDebugVisualization,
            isDebugEnabled: isDebugEnabled,
            rotationAxis: rotationAxis
        )
    }
    
    /// 初始化函数
    public init() {}
} 
