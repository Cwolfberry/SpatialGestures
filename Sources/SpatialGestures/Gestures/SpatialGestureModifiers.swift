import SwiftUI
import RealityKit

public struct SpatialGestureModifiers: ViewModifier {
    @ObservedObject var manager: SpatialGestureManager
    
    // Rotation configuration
    private let rotationAxis: RotationAxis3D
    private let rotationEnabled: Bool
    
    /// Initialize Spatial gestures modifier
    /// - Parameters:
    ///   - manager: Spatial gesture manager
    ///   - rotationAxis: The axis to constrain rotation to (default is .y)
    ///   - rotationEnabled: Whether rotation is enabled (default is true)
    public init(
        manager: SpatialGestureManager, 
        rotationAxis: RotationAxis3D = .y,
        rotationEnabled: Bool = true
    ) {
        self.manager = manager
        self.rotationAxis = rotationAxis
        self.rotationEnabled = rotationEnabled
    }
    
    public func body(content: Content) -> some View {
        content
            .onDragAndRotate(
                manager: manager,
                rotationAxis: rotationAxis,
                rotationEnabled: rotationEnabled
            )
            .onScale(manager: manager)
    }
}

public extension View {
    /// Add Spatial interaction gestures including drag, rotate, and scale
    /// - Parameters:
    ///   - manager: Spatial gesture manager containing entities and state information
    ///   - rotationAxis: The axis to constrain rotation to (default is .y)
    ///   - rotationEnabled: Whether rotation is enabled (default is true)
    /// - Returns: View with Spatial gestures added
    func withSpatialGestures(
        manager: SpatialGestureManager,
        rotationAxis: RotationAxis3D = .y,
        rotationEnabled: Bool = true
    ) -> some View {
        modifier(SpatialGestureModifiers(
            manager: manager,
            rotationAxis: rotationAxis,
            rotationEnabled: rotationEnabled
        ))
    }
    
    /// Add Spatial interaction gestures with drag only (no rotation) and scale
    /// - Parameter manager: Spatial gesture manager containing entities and state information
    /// - Returns: View with Spatial gestures added
    func withSpatialDragAndScaleGestures(manager: SpatialGestureManager) -> some View {
        modifier(SpatialGestureModifiers(
            manager: manager,
            rotationEnabled: false
        ))
    }
} 