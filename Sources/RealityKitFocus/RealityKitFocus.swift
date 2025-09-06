import RealityKit
@preconcurrency import Combine
import Foundation

#if canImport(ARKit)
import ARKit
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@available(iOS 15.0, macOS 12.0, *)
public class FocusEntity: Entity, HasModel, HasAnchoring {
    
    public enum Style {
        case classic
        case modern
        case minimal
        case custom(ModelEntity)
    }
    
    public enum State {
        case initializing
        case tracking
        case found
        case hidden
    }
    
    private weak var arView: ARView?
    private var style: Style = .classic
    private var currentState: State = .initializing
    private var cancellables = Set<AnyCancellable>()
    
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
        let mesh = MeshResource.generateBox(size: [0.1, 0.1, 0.1])
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white.withAlphaComponent(0.8))
        
        model = ModelComponent(mesh: mesh, materials: [material])
    }
    
    private func setupModernStyle() {
        let mesh = MeshResource.generatePlane(width: 0.15, depth: 0.15)
        var material = UnlitMaterial(color: .systemBlue)
        material.color = .init(tint: .systemBlue.withAlphaComponent(0.6))
        
        model = ModelComponent(mesh: mesh, materials: [material])
    }
    
    private func setupMinimalStyle() {
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
        
        #if canImport(ARKit) && os(iOS)
        NotificationCenter.default.publisher(for: ARSession.wasInterruptedNotification)
            .sink { [weak self] _ in
                self?.handleTrackingStateChange()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: ARSession.interruptionEndedNotification)
            .sink { [weak self] _ in
                self?.handleTrackingStateChange()
            }
            .store(in: &cancellables)
        #endif
        
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] (_: Date) in
                self?.updateFocusPosition()
            }
            .store(in: &cancellables)
        
        setState(.tracking)
    }
    
    private func updateFocusPosition() {
        guard let arView = arView,
              currentState != .hidden else { return }
        
        #if canImport(ARKit) && os(iOS)
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        if let result = arView.raycast(from: screenCenter, allowing: .existingPlaneInfinite, alignment: .any).first {
            let transform = Transform(matrix: result.worldTransform)
            self.transform = transform
            
            updatePreviewPosition(transform)
            
            if currentState != .found {
                setState(.found)
            }
        } else {
            if currentState == .found {
                setState(.tracking)
            }
        }
        #else
        // For macOS or other platforms without ARKit, just set to found state
        if currentState != .found {
            setState(.found)
        }
        #endif
    }
    
    private func updatePreviewPosition(_ transform: Transform) {
        guard previewEnabled, let preview = modelPreview else { return }
        preview.updatePosition(transform)
    }
    
    private func setState(_ newState: State) {
        currentState = newState
        updateVisualForState()
        stateChangeHandler?(newState)
    }
    
    private func updateVisualForState() {
        switch currentState {
        case .initializing:
            isEnabled = false
            modelPreview?.hide()
        case .tracking:
            isEnabled = true
            transform.scale = SIMD3<Float>(0.8, 0.8, 0.8)
            modelPreview?.hide()
        case .found:
            isEnabled = true
            transform.scale = SIMD3<Float>(1.0, 1.0, 1.0)
            if previewEnabled {
                modelPreview?.show()
            }
        case .hidden:
            isEnabled = false
            modelPreview?.hide()
        }
    }
    
    private func handleTrackingStateChange() {
        // Handle ARKit tracking state changes if needed
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
            setState(.tracking)
        }
        return self
    }
    
    public func hide() {
        setState(.hidden)
    }
    
    public func show() {
        if currentState == .hidden {
            setState(.tracking)
        }
    }
    
    public func remove() {
        cancellables.removeAll()
        arView?.scene.removeAnchor(self)
        removeFromParent()
    }
    
    public func triggerPlacement() {
        guard currentState == .found else { return }
        placementHandler?(self, transform.translation)
    }
    
    deinit {
        cancellables.removeAll()
    }
}
