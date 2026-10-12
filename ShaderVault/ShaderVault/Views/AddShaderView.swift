import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddShaderView: View {
    var onSave: (ShaderProject) -> Void
    @Environment(\.colorScheme) var scheme
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var type: ShaderType = .surface
    @State private var pipeline: RenderPipeline = .urp
    @State private var format: ShaderFormat = .hlsl
    @State private var tagsText = ""
    @State private var code = ""
    @State private var parsedProps: [ShaderProperty] = []
    @State private var showFilePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var mediaImages: [(UIImage, String)] = []

    var body: some View {
        NavigationStack {
            ZStack {
                SV.background(scheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        infoSection
                        codeSection
                        if !parsedProps.isEmpty { propsPreview }
                        mediaSection
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Nuevo Shader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(SV.textSecondary(scheme))
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "shader") ?? .plainText,
                    UTType(filenameExtension: "hlsl") ?? .plainText,
                    UTType(filenameExtension: "cginc") ?? .plainText,
                    .plainText
                ]
            ) { result in
                if case .success(let url) = result {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let content = try? String(contentsOf: url) {
                        code = content
                        parseCode()
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, items in
                Task { await loadPhotos(items) }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Informacion General")
                    .font(SV.heading(13))
                    .foregroundStyle(SV.textPrimary(scheme))
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(SV.border(scheme)).frame(height: 1)
            }

            VStack(spacing: 14) {
                fieldGroup("NOMBRE") {
                    TextField("Ej: Holographic Dissolve", text: $name)
                        .svField(scheme)
                }
                fieldGroup("DESCRIPCION") {
                    TextField("Que hace el shader...", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .svField(scheme)
                }
                HStack(spacing: 10) {
                    fieldGroup("TIPO") {
                        Picker("", selection: $type) {
                            ForEach(ShaderType.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.menu)
                        .svField(scheme)
                    }
                    fieldGroup("PIPELINE") {
                        Picker("", selection: $pipeline) {
                            ForEach(RenderPipeline.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.menu)
                        .svField(scheme)
                    }
                }
                fieldGroup("TAGS") {
                    TextField("VFX, TOON, ANIMATED (coma)", text: $tagsText)
                        .svField(scheme)
                }
            }
            .padding(16)
        }
        .svCard()
    }

    // MARK: - Code Section

    private var codeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Codigo del Shader")
                    .font(SV.heading(13))
                    .foregroundStyle(SV.textPrimary(scheme))
                Spacer()
                SVBadge(text: "DOM", color: SV.emerald)
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(SV.border(scheme)).frame(height: 1)
            }

            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if code.isEmpty {
                        Text("Pega tu codigo .shader / .hlsl aqui...")
                            .font(SV.mono(12))
                            .foregroundStyle(SV.textTertiary(scheme))
                            .padding(.top, 14)
                            .padding(.leading, 16)
                    }
                    TextEditor(text: $code)
                        .font(SV.mono(12))
                        .foregroundStyle(SV.textPrimary(scheme))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(10)
                        .onChange(of: code) { _, _ in parseCode() }
                }
                .background(SV.surface(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SV.border(scheme), lineWidth: 1)
                )

                HStack {
                    Rectangle()
                        .fill(SV.border(scheme))
                        .frame(height: 1)
                    Text("O")
                        .font(SV.label(9))
                        .tracking(1)
                        .foregroundStyle(SV.textTertiary(scheme))
                    Rectangle()
                        .fill(SV.border(scheme))
                        .frame(height: 1)
                }

                Button {
                    showFilePicker = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 30))
                            .foregroundStyle(SV.textTertiary(scheme))
                        Text("Importar archivo .shader")
                            .font(SV.label(12))
                            .foregroundStyle(SV.textSecondary(scheme))
                        Text(".shader · .hlsl · .cginc · .compute")
                            .font(SV.body(10))
                            .foregroundStyle(SV.textTertiary(scheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            .foregroundStyle(SV.border(scheme))
                    )
                }
            }
            .padding(16)
        }
        .svCard()
    }

    // MARK: - Props Preview

    private var propsPreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Propiedades Detectadas")
                    .font(SV.heading(13))
                    .foregroundStyle(SV.textPrimary(scheme))
                Spacer()
                Text("\(parsedProps.count)")
                    .font(SV.mono(12))
                    .foregroundStyle(SV.emerald)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SV.emerald.opacity(0.06))
                    .clipShape(Capsule())
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(SV.border(scheme)).frame(height: 1)
            }

            ForEach(parsedProps) { prop in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prop.displayName)
                            .font(SV.label(11))
                            .foregroundStyle(SV.textSecondary(scheme))
                        Text(prop.varName)
                            .font(SV.mono(9))
                            .foregroundStyle(SV.emerald)
                    }
                    Spacer()
                    Text(prop.type.rawValue)
                        .font(SV.mono(9))
                        .foregroundStyle(SV.violet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(SV.violet.opacity(0.06))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(alignment: .top) {
                    Rectangle().fill(SV.border(scheme)).frame(height: 1)
                }
            }
        }
        .svCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Media Section

    private var mediaSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Media")
                    .font(SV.heading(13))
                    .foregroundStyle(SV.textPrimary(scheme))
                Spacer()
            }
            .padding(16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(SV.border(scheme)).frame(height: 1)
            }

            VStack(spacing: 12) {
                if !mediaImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(mediaImages.indices, id: \.self) { i in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: mediaImages[i].0)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    Button {
                                        mediaImages.remove(at: i)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white)
                                            .shadow(radius: 4)
                                    }
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                }

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 20,
                    matching: .any(of: [.images, .videos])
                ) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 28))
                            .foregroundStyle(SV.textTertiary(scheme))
                        Text("Seleccionar fotos o videos")
                            .font(SV.label(12))
                            .foregroundStyle(SV.textSecondary(scheme))
                        Text(".png · .jpg · .gif · .mp4 · .mov")
                            .font(SV.body(10))
                            .foregroundStyle(SV.textTertiary(scheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            .foregroundStyle(SV.border(scheme))
                    )
                }
            }
            .padding(16)
        }
        .svCard()
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 8) {
                Text("Guardar Shader")
                    .font(SV.label(13))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .padding(8)
                    .background(Color.black.opacity(0.15))
                    .clipShape(Circle())
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(SV.emeraldGradient)
            .clipShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
            .shadow(color: SV.emerald.opacity(0.3), radius: 16, y: 8)
        }
        .disabled(name.isEmpty && code.isEmpty)
        .opacity(name.isEmpty && code.isEmpty ? 0.5 : 1)
    }

    // MARK: - Helpers

    private func parseCode() {
        parsedProps = ShaderParser.parseProperties(from: code)
        if name.isEmpty, let parsed = ShaderParser.parseName(from: code) {
            name = parsed
        }
    }

    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }

        var project = ShaderProject(
            name: name.isEmpty ? "Sin Nombre" : name,
            description: description,
            type: type,
            pipeline: pipeline,
            format: format,
            tags: tags,
            code: code,
            properties: parsedProps
        )

        var fileNames: [String] = []
        for (img, originalName) in mediaImages {
            if let data = img.jpegData(compressionQuality: 0.85) {
                let saved = StorageService.shared.saveMedia(
                    data: data, fileName: originalName, projectId: project.id
                )
                fileNames.append(saved)
            }
        }
        project.mediaFileNames = fileNames

        onSave(project)
        dismiss()
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                let name = "media_\(UUID().uuidString.prefix(8)).jpg"
                await MainActor.run {
                    mediaImages.append((img, name))
                }
            }
        }
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(SV.label(8))
                .tracking(1.2)
                .foregroundStyle(SV.textSecondary(scheme))
            content()
        }
    }
}

// MARK: - Field Modifier

struct SVFieldModifier: ViewModifier {
    let scheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SV.border(scheme).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SV.border(scheme), lineWidth: 1)
            )
    }
}

extension View {
    func svField(_ scheme: ColorScheme) -> some View {
        modifier(SVFieldModifier(scheme: scheme))
    }
}
