import SwiftUI

struct ShaderDetailView: View {
    let project: ShaderProject
    var onUpdate: (ShaderProject) -> Void
    @Environment(\.colorScheme) var scheme
    @Environment(\.dismiss) var dismiss
    @State private var showCode = true

    var body: some View {
        ZStack {
            SV.background(scheme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headerSection
                    if !project.code.isEmpty {
                        toggleSection
                        if showCode {
                            CodeView(code: project.code, fileName: "\(project.name).shader")
                        } else {
                            PropertiesView(properties: project.properties)
                        }
                    }
                    if !project.mediaFileNames.isEmpty {
                        mediaSection
                    }
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = project.code
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15))
                        .foregroundStyle(SV.emerald)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("01")
                    .font(SV.mono(11))
                    .foregroundStyle(SV.emerald.opacity(0.3))
                SVBadge(text: "\(project.format.rawValue) · \(project.pipeline.rawValue)", color: SV.emerald)
            }

            Text(project.name)
                .font(SV.display(32))
                .foregroundStyle(SV.textPrimary(scheme))

            Text(project.description)
                .font(SV.body(14))
                .foregroundStyle(SV.textSecondary(scheme))
                .lineSpacing(4)

            HStack(spacing: 6) {
                SVBadge(text: project.type.rawValue, color: SV.emerald)
                SVBadge(text: project.pipeline.rawValue, color: SV.violet)
                ForEach(project.tags.prefix(2), id: \.self) { tag in
                    SVBadge(text: tag, color: SV.gold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Toggle

    private var toggleSection: some View {
        HStack(spacing: 4) {
            toggleButton("Codigo", icon: "chevron.left.forwardslash.chevron.right", active: showCode) {
                withAnimation(.spring(response: 0.35)) { showCode = true }
            }
            toggleButton("Propiedades", icon: "slider.horizontal.3", active: !showCode) {
                withAnimation(.spring(response: 0.35)) { showCode = false }
            }
        }
        .padding(3)
        .background(SV.border(scheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func toggleButton(_ title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(SV.label(11))
            }
            .foregroundStyle(active ? Color.black : SV.textTertiary(scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(active ? SV.emeraldGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("02")
                    .font(SV.mono(11))
                    .foregroundStyle(SV.emerald.opacity(0.3))
                Text("Media")
                    .font(SV.heading(15))
                    .foregroundStyle(SV.textPrimary(scheme))
            }

            MediaGalleryView(fileNames: project.mediaFileNames, projectId: project.id)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text("SHADER VAULT · \(project.name.uppercased())")
                .font(SV.label(7))
                .tracking(1.5)
                .foregroundStyle(SV.textTertiary(scheme))
            Spacer()
            Text("\(project.properties.count) properties")
                .font(SV.mono(9))
                .foregroundStyle(SV.emerald)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(SV.emerald.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(20)
        .svCard()
    }
}
