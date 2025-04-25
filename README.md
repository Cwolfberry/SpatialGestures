# SpatialGestures

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![visionOS](https://img.shields.io/badge/visionOS-1.0+-blue.svg)](https://developer.apple.com/visionos/)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

SpatialGestures is a Swift package that provides simple yet powerful gesture handling for AR entities in visionOS applications.

<p align="center">
  <img src="SpatialGesturesLogo.png" width="600" alt="SpatialGestures Demo">
</p>

## Features

- **Drag**: Move 3D objects in space
- **Rotate**: Rotate 3D objects (with customizable rotation axes)
- **Scale**: Resize 3D objects
- **Gesture Callbacks**: Monitor gesture events and get transformation data
- **Debug Mode**: Get detailed gesture information during development
- **Customizable Rotation**: Specify rotation axes or disable rotation entirely

## Todo:
- **Plane Detection**: Place objects on detected surfaces


## Requirements

- visionOS 1.0+
- Swift 5.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/layzgunner/SpatialGestures.git", from: "1.0.0")
]
```

Or add it in Xcode:
1. Go to File > Add Packages...
2. Enter package URL: `https://github.com/layzgunner/SpatialGestures.git`
3. Select version requirements and click "Add Package"

## Usage

### Initialize the SpatialGestureManager

```swift
import SpatialGestures
import RealityKit
import SwiftUI

// Create anchor and placement instruction entities
let referenceAnchor = Entity()
let placementInstructionEntity = Entity()

// Initialize gesture manager with debug mode
let gestureManager = SpatialGestures.createManager(
    referenceAnchor: referenceAnchor,
    placementInstructionEntity: placementInstructionEntity,
    isDebugEnabled: true  // Enable debug output
)

// Or initialize directly
let manager = SpatialGestureManager(
    referenceAnchor: referenceAnchor,
    placementInstructionEntity: placementInstructionEntity
)

// Add a 3D model entity
let modelEntity = try! await Entity.load(named: "toy_robot")
gestureManager.addEntity(modelEntity, name: "robot")

// Set transform callback
gestureManager.setTransformChangedCallback { (entityName, transform) in
    print("Entity \(entityName) transformed to: \(transform)")
}

// Set gesture callback (monitor all gesture events)
gestureManager.setGestureCallback { gestureInfo in
    switch gestureInfo.gestureType {
    case .drag:
        print("Dragging: \(gestureInfo.entityName)")
    case .rotate:
        print("Rotating: \(gestureInfo.entityName)")
    case .scale:
        if let magnification = gestureInfo.changeValue as? Float {
            print("Scaling: \(gestureInfo.entityName), magnification: \(magnification)")
        }
    case .gestureEnded:
        print("Gesture ended: \(gestureInfo.entityName)")
    }
}
```

### Enable or Disable Debug Mode

```swift
// Enable debug mode
gestureManager.setDebugEnabled(true)

// Disable debug mode
gestureManager.setDebugEnabled(false)

// Direct property access
gestureManager.isDebugEnabled = true
```

### Add Gesture Support to Views

```swift
import SpatialGestures
import RealityKit
import SwiftUI

struct ContentView: View {
    @StateObject private var gestureManager = SpatialGestures.createManager(
        referenceAnchor: Entity(),
        isDebugEnabled: true
    )
    var basicEntity = Entity()
    
    var body: some View {
        RealityView { content, attachments in
            content.add(basicEntity)

            Task {
                do {
                    let robotEntity = try await Entity(named: "Robot", in: realityKitContentBundle)
                    await gestureManager.addEntity(robotEntity, name: "Robot")
                    basicEntity.addChild(robotEntity)
                    
                    robotEntity.position = SIMD3<Float>(-0.4, 1.4, -0.6)
                    
                    // Set gesture callback
                    gestureManager.setGestureCallback { gestureInfo in
                        debugViewModel.addLog(gestureInfo)
                        
                        // Update entity properties display
                        if gestureInfo.entityName == "Robot" {
                            debugViewModel.updateEntityProperties(
                                position: gestureInfo.transform.translation,
                                rotation: gestureInfo.transform.rotation.convertToEulerAngles(),
                                scale: gestureInfo.transform.scale
                            )
                        }
                    }
                    
                    // Initialize entity properties
                    debugViewModel.updateEntityProperties(
                        position: robotEntity.position,
                        rotation: robotEntity.orientation.convertToEulerAngles(),
                        scale: robotEntity.scale
                    )
                    
                } catch {
                    print("Failed to load Robot entity")
                }
            }
        }
        .withSpatialGestures(manager: gestureManager)
    }
}
```

### Using Individual Gestures

If you only need specific gesture functionality:

```swift
// Use drag and rotate only (Y-axis rotation)
myView.onDragAndRotate(manager: gestureManager)

// Specify rotation axis
myView.onDragAndRotate(
    manager: gestureManager,
    rotationAxis: .z  // Rotate around Z axis
)

// Drag gesture only (no rotation)
myView.onDragOnly(manager: gestureManager)

// Scale gesture only
myView.onScale(manager: gestureManager)
```

## Managing Entities

SpatialGestureManager provides several methods to manage entities:

```swift
// Add entity
let entityData = gestureManager.addEntity(newEntity, name: "newEntity")

// Get entity
if let entity = gestureManager.getEntity(named: "robot") {
    // Use found entity...
}

// Remove entity
gestureManager.removeEntity(named: "robot")

// Find main entity from interacted entity
let (entityData, entityName) = gestureManager.findEntityData(from: interactedEntity)
```


```swift
gestureManager.setGestureCallback { info in
    // Gesture type
    let gestureType = info.gestureType
    
    // Entity name
    let entityName = info.entityName
    
    // Current transform
    let transform = info.transform
    
    // Initial transform (at start)
    if let initialTransform = info.initialTransform {
        // Calculate difference
        let translationDiff = transform.translation - initialTransform.translation
        print("Position offset: \(translationDiff)")
    }
    
    // Specific change value
    if let changeValue = info.changeValue {
        if info.gestureType == .scale {
            // Scale factor
            let magnification = changeValue as! Float
            print("Scale factor: \(magnification)")
        } else if info.gestureType == .rotate {
            // Rotation angle
            let angle = changeValue as! Float
            print("Rotation angle: \(angle)")
        }
    }
}
```


## Example Project

Check out our [example project](https://github.com/lazygunner/SpatialGesturesDemo) for complete usage demonstrations.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

SpatialGestures is released under the MIT license. See [LICENSE](LICENSE) for details.