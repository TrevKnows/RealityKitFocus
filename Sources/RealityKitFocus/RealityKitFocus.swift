import RealityKit
@preconcurrency import Combine
import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(ARKit)
import ARKit
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class FocusEntity: Entity, HasModel, HasAnchoring {
    
    public enum Style {
        case classic
        case modern
        case minimal
        case custom(ModelEntity)
    }
    
    public enum State {
        case initializing
        case onPlane          // Solid: on detected plane surface
        case offPlane         // Translucent: hovering above estimated position
        case hidden           // Invisible: no valid placement surface
    }
    
    private weak var arView: ARView?
    private var style: Style = .classic
    private var currentState: State = .initializing
    private var cancellables = Set<AnyCancellable>()
    
    // Smooth movement properties
    private var targetTransform: Transform?
    private var lastValidPosition: SIMD3<Float>?
    private var isInterpolating = false
    private let smoothingFactor: Float = 0.15
    
    // Animation properties
    private var pulseAnimation: AnimationResource?
    private var scaleAnimation: AnimationResource?
    private var isSelected = false
    
    private var stateChangeHandler: ((State) -> Void)?
    private var placementHandler: ((FocusEntity, SIMD3<Float>) -> Void)?
    private var modelPreview: ModelPreview?
    private var previewEnabled: Bool = false
    
    public var state: State {
        return currentState
    }
    
    public init(on arView: ARView) {
        super.init()
        self.arView = arView
        setupFocusEntity()
        arView.scene.addAnchor(self)
        startTracking()
    }
    
    required init() {
        super.init()
    }
    
    private func setupFocusEntity() {
        setupVisualStyle()
        anchoring = AnchoringComponent(.world(transform: matrix_identity_float4x4))
        setupAnimations()
    }
    
    private func setupAnimations() {
        // Gentle pulse animation for off-plane state
        pulseAnimation = try? AnimationResource.generate(
            with: FromToByAnimation(
                from: 1.0,
                to: 1.1,
                duration: 1.0,
                timing: .easeInOut
            )
        )
        
        // Selection scale animation
        scaleAnimation = try? AnimationResource.generate(
            with: FromToByAnimation(
                from: 1.0,
                to: 1.2,
                duration: 0.2,
                timing: .easeOut
            )
        )
    }
    
    private func setupVisualStyle() {
        switch style {
        case .classic:
            setupClassicStyle()
        case .modern:
            setupModernStyle()
        case .minimal:
            setupMinimalStyle()
        case .custom(let modelEntity):
            setupCustomStyle(modelEntity)
        }
    }
    
    private func setupClassicStyle() {
        // Classic AR scanning box with corners
        let mesh = MeshResource.generateBox(size: [0.1, 0.005, 0.1])
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white.withAlphaComponent(0.8))
        
        model = ModelComponent(mesh: mesh, materials: [material])
    }
    
    private func setupModernStyle() {
        // Modern flat ring indicator
        let mesh = MeshResource.generatePlane(width: 0.15, depth: 0.15, cornerRadius: 0.075)
        var material = UnlitMaterial(color: .systemBlue)
        material.color = .init(tint: .systemBlue.withAlphaComponent(0.6))
        
        model = ModelComponent(mesh: mesh, materials: [material])
    }
    
    private func setupMinimalStyle() {
        // Simple dot indicator
        let mesh = MeshResource.generateSphere(radius: 0.02)
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white.withAlphaComponent(0.9))
        
        model = ModelComponent(mesh: mesh, materials: [material])
    }
    
    private func setupCustomStyle(_ modelEntity: ModelEntity) {
        if let modelComponent = modelEntity.model {
            model = modelComponent
        }
    }
    
    private func startTracking() {
        guard arView != nil else { return }
        
        // Update at 60fps for smooth movement
        Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateFocusPosition()
                self?.updateSmoothMovement()
            }
            .store(in: &cancellables)
        
        setState(.initializing)
    }
    
    private func updateFocusPosition() {
        guard let arView = arView,
              currentState != .hidden else { return }
        
        #if canImport(ARKit) && os(iOS)
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Try multiple raycast targets for better surface detection
        let raycastQueries: [(ARRaycastQuery.Target, State)] = [
            (.existingPlaneGeometry, .onPlane),    // Solid on detected planes
            (.estimatedPlane, .offPlane)           // Translucent on estimated surfaces
        ]
        
        var bestResult: (result: ARRaycastResult, state: State)?
        
        for (target, state) in raycastQueries {
            let query = arView.makeRaycastQuery(from: screenCenter,
                                              allowing: target,
                                              alignment: .any)
            
            if let query = query {
                let results = arView.session.raycast(query)
                if let result = results.first {
                    bestResult = (result, state)
                    break // Use the first valid result (prioritize existing planes)
                }
            }
        }
        
        if let (result, newState) = bestResult {
            let newTransform = Transform(matrix: result.worldTransform)
            
            // Set target for smooth interpolation
            targetTransform = newTransform
            lastValidPosition = newTransform.translation
            
            setState(newState)
            updatePreviewPosition(newTransform)
        } else {
            // No valid surface found - hide after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if self?.targetTransform == nil {
                    self?.setState(.hidden)
                }
            }
        }
        #else
        // For macOS or other platforms without ARKit
        if currentState != .onPlane {
            setState(.onPlane)
        }
        #endif
    }
    
    private func updateSmoothMovement() {
        guard let target = targetTransform,
              isInterpolating || simd_distance(transform.translation, target.translation) > 0.001 else { return }
        
        isInterpolating = true
        
        // Smooth interpolation
        let currentPos = transform.translation
        let targetPos = target.translation
        let newPos = currentPos + (targetPos - currentPos) * smoothingFactor
        
        // Update rotation smoothly too
        let currentRot = transform.rotation
        let targetRot = target.rotation
        let newRot = simd_slerp(currentRot, targetRot, smoothingFactor)
        
        transform.translation = newPos
        transform.rotation = newRot
        
        // Stop interpolating when close enough
        let distance = simd_distance(newPos, targetPos)
        if distance < 0.001 {
            transform = target
            isInterpolating = false
            targetTransform = nil
        }
    }
    
    private func updatePreviewPosition(_ transform: Transform) {
        guard previewEnabled, let preview = modelPreview else { return }
        preview.updatePosition(transform)
    }
    
    private func setState(_ newState: State) {
        guard currentState != newState else { return }
        
        currentState = newState
        updateVisualForState()
        stateChangeHandler?(newState)
    }
    
    private func updateVisualForState() {
        switch currentState {
        case .initializing:
            isEnabled = false
            transform.scale = SIMD3<Float>(0.5, 0.5, 0.5)
            updateMaterialOpacity(0.3)
            modelPreview?.hide()
            
        case .onPlane:
            isEnabled = true
            transform.scale = SIMD3<Float>(1.0, 1.0, 1.0)
            updateMaterialOpacity(0.9)
            stopAnimations()
            if previewEnabled {
                modelPreview?.show()
            }
            
        case .offPlane:
            isEnabled = true
            transform.scale = SIMD3<Float>(0.8, 0.8, 0.8)
            updateMaterialOpacity(0.5)
            startPulseAnimation()
            modelPreview?.hide()
            
        case .hidden:
            isEnabled = false
            updateMaterialOpacity(0.0)
            modelPreview?.hide()
        }
    }
    
    private func updateMaterialOpacity(_ opacity: Float) {
        guard var modelComponent = model else { return }
        
        let updatedMaterials = modelComponent.materials.map { material -> RealityFoundation.Material in
            if var unlitMaterial = material as? UnlitMaterial {
                let currentTint = unlitMaterial.color.tint
                unlitMaterial.color = .init(
                    tint: currentTint.withAlphaComponent(CGFloat(opacity)),
                    texture: unlitMaterial.color.texture
                )
                return unlitMaterial
            } else if var simpleMaterial = material as? SimpleMaterial {
                let currentTint = simpleMaterial.color.tint
                simpleMaterial.color = .init(
                    tint: currentTint.withAlphaComponent(CGFloat(opacity)),
                    texture: simpleMaterial.color.texture
                )
                return simpleMaterial
            }
            return material
        }
        
        modelComponent.materials = updatedMaterials
        model = modelComponent
    }
    
    private func startPulseAnimation() {
        guard let animation = pulseAnimation else { return }
        playAnimation(animation.repeat(duration: .infinity))
    }
    
    private func stopAnimations() {
        stopAllAnimations()
    }
    
    // MARK: - Interaction Methods
    
    public func onTap() {
        guard currentState == .onPlane else { return }
        
        isSelected = true
        
        // Scale up animation
        if let scaleAnim = scaleAnimation {
            playAnimation(scaleAnim)
        }
        
        // Trigger placement after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.triggerPlacement()
            self?.isSelected = false
        }
    }
    
    // MARK: - Public API Methods
    
    @discardableResult
    public func withStyle(_ style: Style) -> Self {
        self.style = style
        setupVisualStyle()
        return self
    }
    
    @discardableResult
    public func onStateChange(_ handler: @escaping (State) -> Void) -> Self {
        stateChangeHandler = handler
        return self
    }
    
    @discardableResult
    public func onPlacement(_ handler: @escaping (FocusEntity, SIMD3<Float>) -> Void) -> Self {
        placementHandler = handler
        return self
    }
    
    @discardableResult
    public func enablePreview(for model: ModelEntity, transparency: Float = 0.5) -> Self {
        modelPreview = ModelPreview(model: model, transparency: transparency)
        previewEnabled = true
        
        if let preview = modelPreview, let arView = arView {
            arView.scene.addAnchor(preview)
            preview.hide()
        }
        
        return self
    }
    
    @discardableResult
    public func setTransparency(_ level: Float) -> Self {
        modelPreview?.setTransparency(level)
        return self
    }
    
    @discardableResult
    public func disablePreview() -> Self {
        modelPreview?.removeFromParent()
        modelPreview = nil
        previewEnabled = false
        return self
    }
    
    @discardableResult
    public func start() -> Self {
        if currentState == .hidden {
            setState(.initializing)
        }
        return self
    }
    
    public func hide() {
        setState(.hidden)
    }
    
    public func show() {
        if currentState == .hidden {
            setState(.initializing)
        }
    }
    
    public func remove() {
        cancellables.removeAll()
        stopAllAnimations()
        modelPreview?.removeFromParent()
        arView?.scene.removeAnchor(self)
        removeFromParent()
    }
    
    public func triggerPlacement() {
        guard currentState == .onPlane,
              let position = lastValidPosition else { return }
        placementHandler?(self, position)
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - RealityView Support (iOS 18.0+, macOS 15.0+)
#if canImport(SwiftUI)
@available(iOS 18.0, macOS 15.0, *)
public extension FocusEntity {
    
    /// Modern SwiftUI RealityView support
    /// Use this initializer when working with RealityView's content parameter
    convenience init(content: RealityViewCameraContent) {
        self.init()
        setupFocusEntityInternal()
        content.add(self)
        startBasicTracking()
    }
    
    /// Internal setup method for RealityView initialization
    private func setupFocusEntityInternal() {
        anchoring = AnchoringComponent(.world(transform: matrix_identity_float4x4))
        setupVisualStyleInternal()
    }
    
    /// Internal visual style setup
    private func setupVisualStyleInternal() {
        let mesh = MeshResource.generatePlane(width: 0.15, depth: 0.15)
        var material = UnlitMaterial(color: .systemBlue)
        material.color = .init(tint: .systemBlue.withAlphaComponent(0.6))
        model = ModelComponent(mesh: mesh, materials: [material])
    }
    
    /// Basic tracking for RealityView (without ARKit integration)
    private func startBasicTracking() {
        // For RealityView, we simulate found state since we don't have direct ARView access
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isEnabled = true
        }
    }
}

/*
 Usage Example for RealityView:
 
 struct ContentView: View {
     var body: some View {
         RealityView { content in
             content.camera = .worldTracking
             
             let focusEntity = FocusEntity(content: content)
         }
     }
 }
 */
#endif