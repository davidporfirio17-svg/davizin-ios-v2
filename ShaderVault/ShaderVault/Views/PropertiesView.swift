import SwiftUI

struct PropertiesView: View {
    let properties: [ShaderProperty]
    @Environment(\.colorScheme) var scheme

    private var grouped: [(String, [ShaderProperty])] {
        let dict = Dictionary(grouping: properties) { $0.type.category }
        let order = ["Texturas", "Colores", "Rangos", "Floats", "Vectores"]
        return order.compactMap { key in
            guard let items = dict[key] else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(grouped, id: \.0) { category, props in
                VStack(spacing: 0) {
                    // Category header
                    HStack {
                        Text(category)
                            .font(SV.heading(12))
                            .foregroundStyle(SV.textPrimary(scheme))
                        Spacer()
                        Text(category.uppercased())
                            .font(SV.mono(8))
                            .tracking(0.8)
                            .foregroundStyle(colorForCategory(category))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colorForCategory(category).opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Properties
                    ForEach(props) { prop in
                        propertyRow(prop)
                    }
                }
                .svCard()
            }

            if properties.isEmpty {
                Text("Sin propiedades detectadas")
                    .font(SV.body(13))
                    .foregroundStyle(SV.textTertiary(scheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .svCard()
            }
        }
    }

    @ViewBuilder
    private func propertyRow(_ prop: ShaderProperty) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(prop.displayName)
                    .font(SV.label(11))
                    .foregroundStyle(SV.textSecondary(scheme))
                Text(prop.varName)
                    .font(SV.mono(10))
                    .foregroundStyle(SV.emerald)
            }
            Spacer()
            propertyValue(prop)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(SV.border(scheme)).frame(height: 1)
        }
    }

    @ViewBuilder
    private func propertyValue(_ prop: ShaderProperty) -> some View {
        switch prop.type {
        case .color:
            let components = parseColorComponents(prop.defaultValue)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(
                        red: components.0,
                        green: components.1,
                        blue: components.2
                    ))
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(SV.border(scheme), lineWidth: 1)
                    )
                Text(prop.defaultValue)
                    .font(SV.mono(10))
                    .foregroundStyle(SV.textPrimary(scheme))
            }

        case .range:
            if let min = prop.min, let max = prop.max {
                let val = Double(prop.defaultValue) ?? min
                let pct = max > min ? (val - min) / (max - min) : 0
                HStack(spacing: 6) {
                    Text(String(format: "%.1f", min))
                        .font(SV.mono(9))
                        .foregroundStyle(SV.textTertiary(scheme))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(SV.border(scheme))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [SV.emerald, SV.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(width: 60, height: 4)
                    Text(String(format: "%.1f", max))
                        .font(SV.mono(9))
                        .foregroundStyle(SV.textTertiary(scheme))
                }
            } else {
                Text(prop.defaultValue)
                    .font(SV.mono(10))
                    .foregroundStyle(SV.textPrimary(scheme))
            }

        default:
            Text(prop.defaultValue)
                .font(SV.mono(10))
                .foregroundStyle(SV.textPrimary(scheme))
        }
    }

    private func parseColorComponents(_ value: String) -> (Double, Double, Double) {
        let cleaned = value
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return (
            cleaned.count > 0 ? cleaned[0] : 0,
            cleaned.count > 1 ? cleaned[1] : 0,
            cleaned.count > 2 ? cleaned[2] : 0
        )
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Texturas": return SV.gold
        case "Colores": return SV.emerald
        case "Rangos": return SV.cyan
        case "Floats": return SV.violet
        case "Vectores": return SV.rose
        default: return SV.violet
        }
    }
}
