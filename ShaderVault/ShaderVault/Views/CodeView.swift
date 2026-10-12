import SwiftUI

struct CodeView: View {
    let code: String
    let fileName: String
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(SV.rose).frame(width: 8, height: 8)
                    Circle().fill(SV.gold).frame(width: 8, height: 8)
                    Circle().fill(SV.emerald).frame(width: 8, height: 8)
                }
                Spacer()
                Text(fileName)
                    .font(SV.mono(10))
                    .foregroundStyle(SV.textTertiary(scheme))
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(SV.textTertiary(scheme))
                        .padding(6)
                        .background(SV.border(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(SV.surface(scheme))
            .overlay(alignment: .bottom) {
                Rectangle().fill(SV.border(scheme)).frame(height: 1)
            }

            // Code body
            ScrollView([.horizontal, .vertical]) {
                Text(highlightedCode)
                    .font(SV.mono(11))
                    .lineSpacing(6)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 420)
            .background(scheme == .dark
                ? Color(red: 0.043, green: 0.043, blue: 0.078)
                : Color(red: 0.97, green: 0.98, blue: 0.98))
        }
        .svCard()
    }

    private var highlightedCode: AttributedString {
        var result = AttributedString()
        let lines = code.components(separatedBy: "\n")

        for (i, line) in lines.enumerated() {
            // Line number
            var num = AttributedString(String(format: "%3d  ", i + 1))
            num.foregroundColor = UIColor(SV.textTertiary(.dark)).withAlphaComponent(0.3)
            num.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            result += num

            // Highlighted line
            result += highlightLine(line)

            if i < lines.count - 1 {
                result += AttributedString("\n")
            }
        }
        return result
    }

    private func highlightLine(_ line: String) -> AttributedString {
        var attr = AttributedString(line)
        attr.foregroundColor = UIColor(SV.textSecondary(.dark))
        attr.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let keywords = ["Shader", "Properties", "SubShader", "Tags", "LOD", "CGPROGRAM", "ENDCG",
                        "FallBack", "Pass", "void", "struct", "return", "if", "else", "for",
                        "while", "clip", "discard", "inout", "#pragma", "#include"]
        let types = ["float", "float2", "float3", "float4", "half", "half2", "half3", "half4",
                     "fixed", "fixed2", "fixed3", "fixed4", "int", "uint", "sampler2D",
                     "samplerCUBE", "SurfaceOutputStandard", "SurfaceOutput", "Input",
                     "Color", "2D", "Range", "Float", "Vector", "Cube"]
        let functions = ["tex2D", "saturate", "dot", "pow", "lerp", "smoothstep", "normalize",
                         "cross", "reflect", "mul", "abs", "frac", "floor", "ceil", "clamp",
                         "step", "max", "min", "sin", "cos", "length"]

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") {
            attr.foregroundColor = UIColor(SV.textTertiary(.dark))
            return attr
        }

        for kw in keywords {
            applyColor(to: &attr, word: kw, in: line, color: UIColor(SV.violet))
        }
        for ty in types {
            applyColor(to: &attr, word: ty, in: line, color: UIColor(SV.cyan))
        }
        for fn in functions {
            applyColor(to: &attr, word: fn, in: line, color: UIColor(SV.emerald))
        }

        // Properties (_VarName)
        let propPattern = try? NSRegularExpression(pattern: #"\b_\w+"#)
        if let matches = propPattern?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            for match in matches {
                if let range = Range(match.range, in: line),
                   let attrRange = attr.range(of: String(line[range])) {
                    attr[attrRange].foregroundColor = UIColor(SV.sky)
                }
            }
        }

        // Numbers
        let numPattern = try? NSRegularExpression(pattern: #"\b\d+\.?\d*f?\b"#)
        if let matches = numPattern?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            for match in matches {
                if let range = Range(match.range, in: line),
                   let attrRange = attr.range(of: String(line[range])) {
                    attr[attrRange].foregroundColor = UIColor(SV.rose)
                }
            }
        }

        // Strings
        let strPattern = try? NSRegularExpression(pattern: #""[^"]*""#)
        if let matches = strPattern?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            for match in matches {
                if let range = Range(match.range, in: line),
                   let attrRange = attr.range(of: String(line[range])) {
                    attr[attrRange].foregroundColor = UIColor(SV.gold)
                }
            }
        }

        return attr
    }

    private func applyColor(to attr: inout AttributedString, word: String, in line: String, color: UIColor) {
        let pattern = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b")
        if let matches = pattern?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            for match in matches {
                if let range = Range(match.range, in: line),
                   let attrRange = attr.range(of: String(line[range])) {
                    attr[attrRange].foregroundColor = color
                }
            }
        }
    }
}
