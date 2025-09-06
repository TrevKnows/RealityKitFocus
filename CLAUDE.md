# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift Package Manager library called "RealityKitFocus" that provides an enhanced focus entity system for RealityKit AR applications. It offers improvements over existing solutions like FocusEntity with features including:

- Easy focus entity removal and management
- Semi-transparent model previews before placement  
- Multiple visual styles (classic, modern, minimal, custom)
- Fluent API design for ease of use
- Cross-platform support (iOS 15.0+, macOS 12.0+)

## Commands

### Build
```bash
swift build
```

### Test  
```bash
swift test
```

### Run Single Test
```bash
swift test --filter <test_name>
```

### Package Resolution
```bash
swift package resolve
```

### Generate Xcode Project (if needed)
```bash
swift package generate-xcodeproj
```

## Architecture

The library follows a component-based architecture:

### Core Components

- **FocusEntity**: Main class for AR focus tracking and visualization
- **ModelPreview**: Component for semi-transparent model visualization before placement  
- **PlacementManager**: (Planned) Handles placement validation and management

### Directory Structure

- **Sources/RealityKitFocus/**: Main library code
  - `RealityKitFocus.swift`: Core FocusEntity class with fluent API
  - `ModelPreview.swift`: Semi-transparent model preview system
- **Tests/RealityKitFocusTests/**: Test suite using Swift Testing framework
- **Examples/ARFocus/**: Example/demo directory (planned)
- **Package.swift**: Swift package manifest with iOS 15.0+ and macOS 12.0+ support
- **PLANNING.md**: Detailed technical specifications and implementation roadmap

### Platform Support

- iOS 15.0+ (with ARKit integration)
- macOS 12.0+ (limited functionality without ARKit)
- Swift 6.0+
- Uses modern Swift concurrency and testing frameworks

## Key Files

- `Package.swift`: Package configuration with RealityKit and ARKit dependencies
- `Sources/RealityKitFocus/RealityKitFocus.swift`: Main FocusEntity implementation
- `Sources/RealityKitFocus/ModelPreview.swift`: Semi-transparent preview system
- `PLANNING.md`: Technical specifications and roadmap
- `Tests/RealityKitFocusTests/RealityKitFocusTests.swift`: Test suite entry point

## API Usage Example

```swift
import RealityKitFocus

let focusEntity = FocusEntity(on: arView)
    .withStyle(.modern)
    .enablePreview(for: modelEntity)
    .setTransparency(0.6)
    .onPlacement { entity, position in
        // Handle placement
    }
    .start()

// Easy cleanup
focusEntity.remove()
```