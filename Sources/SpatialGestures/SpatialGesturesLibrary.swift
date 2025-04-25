import SwiftUI
import RealityKit

/// 提供拖拽、旋转和缩放手势的库功能
public struct SpatialGesturesLib {
    /// 库版本
    public static let version = "1.0.0"
    
    /// 快速使用所有手势的方法
    /// - Parameter manager: 空间手势管理器
    /// - Returns: 添加了所有手势的视图修饰器
    @MainActor public static func allGestures(manager: SpatialGestureManager) -> some ViewModifier {
        AllGesturesViewModifier(manager: manager)
    }
}

/// 包含所有手势的视图修饰器
public struct AllGesturesViewModifier: ViewModifier {
    @ObservedObject var manager: SpatialGestureManager
    
    public init(manager: SpatialGestureManager) {
        self.manager = manager
    }
    
    public func body(content: Content) -> some View {
        content
            .onDrag(manager: manager)
            .onScaleAndRotate(manager: manager, rotationAxis: nil)
    }
}

public extension View {
    /// 添加所有手势（拖拽、旋转、缩放）
    /// - Parameter manager: 空间手势管理器
    /// - Returns: 添加了所有手势的视图
    func withSpatialGestures(manager: SpatialGestureManager) -> some View {
        self.modifier(SpatialGesturesLib.allGestures(manager: manager))
    }
} 
