# RealityKitFocus - Planning Document

## Project Vision

Create an improved focus entity system for RealityKit that enhances upon existing solutions like FocusEntity with:
- Easy focus entity removal/management
- Semi-transparent model previews before placement
- Enhanced placement validation
- Clean, fluent API design

## Technical Architecture

### Core Components

#### 1. FocusEntity
Main class for AR focus tracking and visualization.

```swift
@MainActor
public class FocusEntity: Entity, HasModel, HasAnchoring {
    public enum Style {
        case classic    // Traditional AR scanning box
        case modern     // Clean, minimal indicator  
        case minimal    // Simple dot/circle
        case custom(ModelEntity)
    }
    
    public enum State {
        case initializing
        case tracking
        case found
        case hidden
    }
    
    private var raycastQuery: ARRaycastQuery?
    private var collisionComponent: CollisionComponent?
}
```

#### 2. ModelPreview
Component for semi-transparent model visualization.

```swift
@MainActor
public class ModelPreview: Entity, HasModel {
    private var originalModel: ModelEntity
    private var transparencyLevel: Float = 0.5
    private var previewMaterial: UnlitMaterial?
    
    public func updatePreview(with model: ModelEntity) async
    public func setTransparency(_ level: Float)
    public func generateCollisionShapes() // For raycasting
}
```

#### 3. PlacementManager
Handles placement validation and management.

```swift
@MainActor
public class PlacementManager {
    public struct PlacementResult {
        let position: SIMD3<Float>
        let normal: SIMD3<Float>
        let isValid: Bool
        let confidence: Float
        let anchor: ARAnchor?
    }
    
    private let arView: ARView
    
    public func performRaycast(from screenPoint: CGPoint) async -> [ARRaycastResult]
    public func validatePlacement(at position: SIMD3<Float>) -> PlacementResult
    public func snapToGrid(_ position: SIMD3<Float>) -> SIMD3<Float>
}
```

### API Design

#### Fluent API (Recommended)

**ARView (Legacy):**
```swift
let focusEntity = await FocusEntity(on: arView)
    .withStyle(.modern)
    .start()
```

**RealityView (Modern SwiftUI):**
```swift
RealityView { content in
    content.camera = .worldTracking
    
    let focusEntity = await FocusEntity(on: content)
        .withStyle(.modern)
        .enablePreview(for: modelEntity)
        .setTransparency(0.6)
        .start()
}
```

#### Event-Driven API
```swift
focusEntity.onStateChange { state in
    switch state {
    case .found:
        // Show placement UI
    case .tracking:
        // Hide placement UI
    }
}
```

## Implementation Phases

### Phase 1: Core Focus Entity ✓
- [x] Basic FocusEntity class structure
- [x] RealityKit integration
- [x] State management
- [x] Visual styles (classic, modern, minimal)
- [x] Easy removal methods

### Phase 2: Semi-Transparent Preview System
- [ ] ModelPreview component
- [ ] Material transparency override
- [ ] Real-time preview updates
- [ ] Custom model support

### Phase 3: Enhanced Placement System  
- [ ] Surface detection and validation
- [ ] Placement confidence scoring
- [ ] Snap-to-grid functionality
- [ ] Undo/redo system

### Phase 4: API Polish & Testing
- [ ] Fluent API implementation
- [ ] Comprehensive example app
- [ ] Unit test coverage
- [ ] Performance optimization

## Technical Specifications

### Dependencies
- RealityKit (iOS 15.0+, macOS 12.0+, visionOS 1.0+)
- ARKit (for plane detection on iOS/iPadOS)
- Swift 6.0+ with modern concurrency support

### 2024 RealityKit Architecture Updates

#### Entity-Component-System (ECS) Integration
- Leverage RealityKit's ECS paradigm for better performance
- Use HasAnchoring protocol requirement for scene integration
- Implement proper entity hierarchy with AnchorEntity roots

#### Modern Raycasting
- Replace deprecated hit testing with ARRaycastQuery
- Support LiDAR-enhanced raycasting on compatible devices
- Use `.estimatedPlane` target for improved surface detection

#### Cross-Platform Considerations
- iOS/iPadOS: Full ARKit integration with plane detection
- macOS: Limited functionality without ARKit (manual placement)  
- visionOS: Enhanced spatial computing capabilities

#### SwiftUI RealityView Integration (2024)
- Support both ARView (legacy) and RealityView (modern SwiftUI)
- RealityViewCameraContent for iOS/macOS, RealityViewContent for visionOS
- Dual API design for backward compatibility

### Key Features

#### Focus Management
- Multiple visual styles
- Smooth animations
- State-based behavior
- Memory-efficient cleanup

#### Preview System
- Automatic material transparency
- Real-time position updates  
- Support for complex 3D models
- Customizable transparency levels

#### Placement Validation
- Plane detection integration
- Surface normal analysis
- Confidence scoring
- Grid alignment options

### Performance Considerations (2024 Best Practices)
- Entity hierarchy optimization (avoid deep nesting)
- Polygon count limits: <250k for shared space, <500k for immersive
- Use AnchorEntity for proper transform hierarchy
- generateCollisionShapes() for raycasting performance
- Material batching for transparency rendering
- LiDAR-optimized raycasting on supported devices
- Proper entity cleanup with removeFromParent()

## API Examples

### Basic Usage
```swift
import RealityKitFocus

@MainActor
class ARViewController: UIViewController {
    @IBOutlet var arView: ARView!
    private var focusEntity: FocusEntity?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            focusEntity = await FocusEntity(on: arView)
                .withStyle(.modern)
                .start()
        }
    }
    
    @IBAction func toggleFocus(_ sender: UIButton) {
        focusEntity?.isHidden.toggle()
    }
    
    @IBAction func removeFocus(_ sender: UIButton) {
        focusEntity?.remove()
        focusEntity = nil
    }
}
```

### Advanced Usage with Preview
```swift
do {
    let modelEntity = try await ModelEntity(named: "chair")
    
    focusEntity = await FocusEntity(on: arView)
        .withStyle(.classic)
        .enablePreview(for: modelEntity)
        .setTransparency(0.4)
        .enableGridSnapping(size: 0.05)
        .withRaycastTarget(.estimatedPlane)
        .onPlacement { [weak self] entity, position, anchor in
            await self?.placeChair(at: position, anchor: anchor)
        }
        .onStateChange { state in
            print("Focus state changed to: \(state)")
        }
        .start()
} catch {
    print("Failed to load model: \(error)")
}
```

## Testing Strategy

### Unit Tests
- FocusEntity state transitions
- Material transparency calculations
- Placement validation logic
- Memory management

### Integration Tests  
- ARView integration
- Real device AR tracking
- Performance benchmarks
- Memory leak detection

## Documentation Plan

### Public API Documentation
- Complete DocC documentation
- Code examples for all features
- Migration guide from other solutions

### Example Applications
- Basic focus tracking demo
- Model placement with preview
- Advanced placement validation
- Custom styling examples

## Success Metrics

### Technical Goals
- < 16ms frame rendering time
- < 50MB memory usage for typical scenes
- 99%+ placement accuracy
- Zero memory leaks

### Developer Experience
- One-line setup for basic use cases
- Intuitive API naming
- Comprehensive error handling
- Clear documentation