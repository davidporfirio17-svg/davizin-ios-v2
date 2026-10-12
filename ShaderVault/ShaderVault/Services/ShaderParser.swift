import Foundation

struct ShaderParser {
    static func parseProperties(from code: String) -> [ShaderProperty] {
        var properties: [ShaderProperty] = []

        guard let blockMatch = code.range(
            of: #"Properties\s*\{([\s\S]*?)\n\s*\}"#,
            options: .regularExpression
        ) else { return properties }

        let block = String(code[blockMatch])

        let pattern = #"(\w+)\s*\(\s*"([^"]*)"\s*,\s*(\w+)(?:\s*\(([^)]*)\))?\s*\)\s*=\s*([^\n}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return properties }

        let nsBlock = block as NSString
        let matches = regex.matches(in: block, range: NSRange(location: 0, length: nsBlock.length))

        for match in matches {
            guard match.numberOfRanges >= 6 else { continue }

            let varName = nsBlock.substring(with: match.range(at: 1))
            let display = nsBlock.substring(with: match.range(at: 2))
            let typeStr = nsBlock.substring(with: match.range(at: 3))
            let typeArgs = match.range(at: 4).location != NSNotFound
                ? nsBlock.substring(with: match.range(at: 4))
                : nil
            let defaultVal = nsBlock.substring(with: match.range(at: 5))
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"\s*\{?\s*$"#, with: "", options: .regularExpression)

            let propType: PropertyType
            switch typeStr {
            case "Color": propType = .color
            case "2D": propType = .texture2D
            case "Cube": propType = .textureCube
            case "Float": propType = .float
            case "Int": propType = .int
            case "Range": propType = .range
            case "Vector": propType = .vector
            default: propType = .float
            }

            var minVal: Double?
            var maxVal: Double?
            if propType == .range, let args = typeArgs {
                let parts = args.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 {
                    minVal = Double(parts[0])
                    maxVal = Double(parts[1])
                }
            }

            properties.append(ShaderProperty(
                varName: varName,
                displayName: display,
                type: propType,
                defaultValue: defaultVal,
                min: minVal,
                max: maxVal
            ))
        }

        return properties
    }

    static func parseName(from code: String) -> String? {
        guard let match = code.range(
            of: #"Shader\s+"([^"]+)""#,
            options: .regularExpression
        ) else { return nil }

        let full = String(code[match])
        guard let nameMatch = full.range(of: #""([^"]+)""#, options: .regularExpression) else { return nil }
        var name = String(full[nameMatch]).replacingOccurrences(of: "\"", with: "")
        if let lastSlash = name.lastIndex(of: "/") {
            name = String(name[name.index(after: lastSlash)...])
        }
        return name
    }
}
