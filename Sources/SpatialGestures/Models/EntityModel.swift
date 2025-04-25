import Foundation
import RealityKit

/// Entity data structure containing the Entity and its related information
public struct EntityData: Identifiable, @unchecked Sendable {
    /// Unique identifier
    public let id: UUID
    /// Entity object
    public let entity: Entity
    /// Entity name
    public let name: String
    
    /// Initialize a new EntityData
    /// - Parameters:
    ///   - entity: Entity object
    ///   - name: Entity name
    public init(entity: Entity, name: String) {
        self.id = UUID()
        self.entity = entity
        self.name = name
    }
    
    /// Initialize EntityData with specified ID
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - entity: Entity object
    ///   - name: Entity name
    public init(id: UUID, entity: Entity, name: String) {
        self.id = id
        self.entity = entity
        self.name = name
    }
}

/// Transform change callback type
public typealias TransformChangedCallback = (String, Transform) -> Void 