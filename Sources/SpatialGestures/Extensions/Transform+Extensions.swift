import RealityKit
import simd

extension simd_quatf {
    /// 将四元数转换为欧拉角（以弧度为单位）
    /// - Returns: 欧拉角，分别表示x、y、z轴上的旋转（pitch, yaw, roll）
    public func convertToEulerAngles() -> SIMD3<Float> {
        // 基于四元数转欧拉角的标准算法
        let x = self.vector.x
        let y = self.vector.y
        let z = self.vector.z
        let w = self.vector.w
        
        // Roll (绕x轴旋转)
        let sinr_cosp = 2 * (w * x + y * z)
        let cosr_cosp = 1 - 2 * (x * x + y * y)
        let roll = atan2(sinr_cosp, cosr_cosp)
        
        // Pitch (绕y轴旋转)
        let sinp = 2 * (w * y - z * x)
        let pitch: Float
        if abs(sinp) >= 1 {
            pitch = copysign(Float.pi / 2, sinp) // 使用90度，如果越界
        } else {
            pitch = asin(sinp)
        }
        
        // Yaw (绕z轴旋转)
        let siny_cosp = 2 * (w * z + x * y)
        let cosy_cosp = 1 - 2 * (y * y + z * z)
        let yaw = atan2(siny_cosp, cosy_cosp)
        
        return SIMD3<Float>(pitch, yaw, roll)
    }
} 