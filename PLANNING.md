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
}
```

#### 2. ModelPreview
Component for semi-transparent model visualization.

```swift
public class ModelPreview: Entity, HasModel {
    private var originalModel: ModelEntity
    private var transparencyLevel: Float = 0.5
    
    public func updatePreview(with model: ModelEntity)
    public func setTransparency(_ level: Float)
}
```

#### 3. PlacementManager
Handles placement validation and management.

```swift
public class PlacementManager {
    public struct PlacementResult {
        let position: SIMD3<Float>
        let normal: SIMD3<Float>
        let isValid: Bool
        let confidence: Float
    }
    
    public func validatePlacement(at position: SIMD3<Float>) -> PlacementResult
    public func snapToGrid(_ position: SIMD3<Float>) -> SIMD3<Float>
}
```

### API Design

#### Fluent API (Recommended)
```swift
let focusEntity = FocusEntity(on: arView)
    .withStyle(.modern)
    .enablePreview(for: modelEntity)
    .setTransparency(0.6)
    .enableGridSnapping(size: 0.1)
    .onPlacement { [weak self] entity, position in
        self?.placeModel(at: position)
    }
    .start()

// Easy removal
focusEntity.remove()
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
- RealityKit (iOS 13.0+)
- ARKit (for plane detection)
- Swift 5.2+

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

### Performance Considerations
- Efficient entity pooling
- Minimal draw calls for transparency
- Optimized ray casting for placement
- Memory management for large models

## API Examples

### Basic Usage
```swift
import RealityKitFocus

class ARViewController: UIViewController {
    @IBOutlet var arView: ARView!
    private var focusEntity: FocusEntity?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        focusEntity = FocusEntity(on: arView)
            .withStyle(.modern)
            .start()
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
let modelEntity = try! ModelEntity.loadModel(named: "chair")

focusEntity = FocusEntity(on: arView)
    .withStyle(.classic)
    .enablePreview(for: modelEntity)
    .setTransparency(0.4)
    .enableGridSnapping(size: 0.05)
    .onPlacement { [weak self] entity, position in
        self?.placeChair(at: position)
    }
    .onStateChange { state in
        print("Focus state changed to: \(state)")
    }
    .start()
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