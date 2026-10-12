import Foundation

struct ShaderProject: Identifiable, Codable {
    var id: UUID
    var name: String
    var description: String
    var type: ShaderType
    var pipeline: RenderPipeline
    var format: ShaderFormat
    var tags: [String]
    var code: String
    var properties: [ShaderProperty]
    var mediaFileNames: [String]
    var created: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        description: String = "",
        type: ShaderType = .surface,
        pipeline: RenderPipeline = .urp,
        format: ShaderFormat = .hlsl,
        tags: [String] = [],
        code: String = "",
        properties: [ShaderProperty] = [],
        mediaFileNames: [String] = [],
        created: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.pipeline = pipeline
        self.format = format
        self.tags = tags
        self.code = code
        self.properties = properties
        self.mediaFileNames = mediaFileNames
        self.created = created
    }
}

enum ShaderType: String, Codable, CaseIterable {
    case surface = "Surface"
    case unlit = "Unlit"
    case postProcess = "Post-Process"
    case compute = "Compute"
    case shaderGraph = "Shader Graph"
    case vfxGraph = "VFX Graph"
}

enum RenderPipeline: String, Codable, CaseIterable {
    case urp = "URP"
    case hdrp = "HDRP"
    case builtIn = "Built-in"
}

enum ShaderFormat: String, Codable, CaseIterable {
    case hlsl = "HLSL"
    case shaderGraph = "Shader Graph"
    case cg = "CG"
    case glsl = "GLSL"
}
