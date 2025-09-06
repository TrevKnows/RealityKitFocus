import RealityKit
import Foundation

@available(iOS 15.0, macOS 12.0, *)
public class ModelPreview: Entity, HasModel, HasAnchoring {
    
    private var originalModel: ModelEntity
    private var transparencyLevel: Float = 0.5
    private var originalMaterials: [Material] = []
    
    public init(model: ModelEntity, transparency: Float = 0.5) {
        self.originalModel = model
        self.transparencyLevel = max(0.0, min(1.0, transparency))
        super.init()
        setupPreview()
    }
    
    required init() {
        fatalError("Use init(model:transparency:) instead")
    }
    
    private func setupPreview() {
        anchoring = AnchoringComponent(.world(transform: matrix_identity_float4x4))
        copyModelStructure()
        applyTransparency()
    }
    
    private func copyModelStructure() {
        guard let originalModelComponent = originalModel.model else { return }
        
        originalMaterials = originalModelComponent.materials
        
        let transparentMaterials = originalMaterials.map { material -> Material in
            createTransparentMaterial(from: material)
        }
        
        model = ModelComponent(
            mesh: originalModelComponent.mesh,
            materials: transparentMaterials
        )
        
        transform = originalModel.transform
    }
    
    private func createTransparentMaterial(from material: Material) -> Material {
        switch material {
        case var unlitMaterial as UnlitMaterial:
            unlitMaterial.color = .init(
                tint: unlitMaterial.color.tint.withAlphaComponent(CGFloat(transparencyLevel)),
                texture: unlitMaterial.color.texture
            )
            return unlitMaterial
            
        case var simpleMaterial as SimpleMaterial:
            simpleMaterial.color = .init(
                tint: simpleMaterial.color.tint.withAlphaComponent(CGFloat(transparencyLevel)),
                texture: simpleMaterial.color.texture
            )
            simpleMaterial.metallic = .init(floatLiteral: 0.0)
            simpleMaterial.roughness = .init(floatLiteral: 0.8)
            return simpleMaterial
            
        default:
            var unlitMaterial = UnlitMaterial()
            unlitMaterial.color = .init(tint: .white.withAlphaComponent(CGFloat(transparencyLevel)))
            return unlitMaterial
        }
    }
    
    public func updatePreview(with newModel: ModelEntity) {
        originalModel = newModel
        setupPreview()
    }
    
    public func setTransparency(_ level: Float) {
        transparencyLevel = max(0.0, min(1.0, level))
        applyTransparency()
    }
    
    private func applyTransparency() {
        guard let modelComponent = model else { return }
        
        let transparentMaterials = modelComponent.materials.map { material -> Material in
            createTransparentMaterial(from: material)
        }
        
        model?.materials = transparentMaterials
    }
    
    public func updatePosition(_ transform: Transform) {
        self.transform = transform
    }
    
    public func hide() {
        isEnabled = false
    }
    
    public func show() {
        isEnabled = true
    }
}