import Foundation

struct ShaderProperty: Identifiable, Codable {
    var id: UUID
    var varName: String
    var displayName: String
    var type: PropertyType
    var defaultValue: String
    var min: Double?
    var max: Double?

    init(
        id: UUID = UUID(),
        varName: String,
        displayName: String,
        type: PropertyType,
        defaultValue: String,
        min: Double? = nil,
        max: Double? = nil
    ) {
        self.id = id
        self.varName = varName
        self.displayName = displayName
        self.type = type
        self.defaultValue = defaultValue
        self.min = min
        self.max = max
    }
}

enum PropertyType: String, Codable, CaseIterable {
    case color = "Color"
    case texture2D = "2D"
    case textureCube = "Cube"
    case float = "Float"
    case int = "Int"
    case range = "Range"
    case vector = "Vector"

    var category: String {
        switch self {
        case .color: return "Colores"
        case .texture2D, .textureCube: return "Texturas"
        case .range: return "Rangos"
        case .float, .int: return "Floats"
        case .vector: return "Vectores"
        }
    }
}
