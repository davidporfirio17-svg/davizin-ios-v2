import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var scheme
    @State private var projects: [ShaderProject] = []
    @State private var selectedProject: ShaderProject?
    @State private var showAdd = false
    @State private var searchText = ""

    var filtered: [ShaderProject] {
        guard !searchText.isEmpty else { return projects }
        let q = searchText.lowercased()
        return projects.filter {
            $0.name.lowercased().contains(q)
            || $0.description.lowercased().contains(q)
            || $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SV.background(scheme).ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        headerSection
                        statsRow
                        gallerySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationDestination(item: $selectedProject) { project in
                ShaderDetailView(project: project, onUpdate: { updated in
                    if let idx = projects.firstIndex(where: { $0.id == updated.id }) {
                        projects[idx] = updated
                        StorageService.shared.saveProjects(projects)
                    }
                })
            }
            .sheet(isPresented: $showAdd) {
                AddShaderView { newProject in
                    StorageService.shared.addProject(newProject)
                    projects = StorageService.shared.loadProjects()
                }
            }
            .onAppear {
                projects = StorageService.shared.loadProjects()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        LogoView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SHADER")
                                .font(SV.heading(13))
                                .tracking(3)
                                .foregroundStyle(SV.textPrimary(scheme))
                            Text("VAULT")
                                .font(SV.label(7))
                                .tracking(1.5)
                                .foregroundStyle(SV.textTertiary(scheme))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(SV.emerald)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tus")
                    .font(SV.display(38))
                    .foregroundStyle(SV.textPrimary(scheme))
                Text("Shaders")
                    .font(.system(size: 42, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(SV.brandGradient)
            }
            .padding(.top, 8)

            Text("Tu biblioteca personal de shaders Unity. Codigo, propiedades, media — todo organizado.")
                .font(SV.body(14))
                .foregroundStyle(SV.textSecondary(scheme))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(projects.count)", label: "PROYECTOS", color: SV.emerald)
            Spacer()
            statItem(
                value: "\(projects.reduce(0) { $0 + $1.properties.count })",
                label: "PROPIEDADES",
                color: SV.violet
            )
            Spacer()
            statItem(
                value: "\(projects.reduce(0) { $0 + $1.mediaFileNames.count })",
                label: "MEDIA",
                color: SV.gold
            )
        }
        .padding(20)
        .svCard()
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(SV.display(28))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(SV.label(7))
                .tracking(2)
                .foregroundStyle(SV.textTertiary(scheme))
        }
    }

    // MARK: - Gallery

    private var gallerySection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("01")
                        .font(SV.mono(11))
                        .foregroundStyle(SV.emerald.opacity(0.3))
                    Text("Todos los Shaders")
                        .font(SV.heading(15))
                        .foregroundStyle(SV.textPrimary(scheme))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SV.textTertiary(scheme))
                    .font(.system(size: 14))
                TextField("Buscar shader...", text: $searchText)
                    .font(SV.body(14))
                    .foregroundStyle(SV.textPrimary(scheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SV.border(scheme).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if filtered.isEmpty {
                emptyState
            } else {
                ForEach(filtered) { project in
                    ShaderCardView(project: project)
                        .onTapGesture { selectedProject = project }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(SV.textTertiary(scheme))
            Text("Sin Shaders")
                .font(SV.heading(18))
                .foregroundStyle(SV.textSecondary(scheme))
            Text("Toca + para agregar tu primer shader")
                .font(SV.body(13))
                .foregroundStyle(SV.textTertiary(scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(SV.border(scheme))
        )
    }
}

// MARK: - Logo

struct LogoView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    AngularGradient(
                        colors: [SV.emerald, SV.violet, SV.gold, SV.emerald],
                        center: .center,
                        angle: .degrees(rotation)
                    )
                )
                .frame(width: 36, height: 36)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.027, green: 0.027, blue: 0.051))
                .frame(width: 30, height: 30)

            Text("SV")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(SV.emerald)
                .shadow(color: SV.emerald.opacity(0.5), radius: 6)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Shader Card

struct ShaderCardView: View {
    let project: ShaderProject
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 0) {
            // Preview
            ZStack {
                SV.surface(scheme)

                if let firstName = project.mediaFileNames.first,
                   let img = StorageService.shared.loadMediaImage(
                    fileName: firstName, projectId: project.id
                   ) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 28))
                            .foregroundStyle(SV.emerald.opacity(0.3))
                        Text("SIN PREVIEW")
                            .font(SV.label(9))
                            .tracking(1)
                            .foregroundStyle(SV.textTertiary(scheme))
                    }
                }

                // Badges
                VStack {
                    HStack {
                        Spacer()
                        SVBadge(text: project.type.rawValue, color: badgeColor)
                    }
                    Spacer()
                    HStack {
                        Text(project.format.rawValue)
                            .font(SV.label(8))
                            .tracking(1.2)
                            .foregroundStyle(SV.emerald)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
                .padding(10)
            }
            .aspectRatio(16/10, contentMode: .fill)
            .clipped()

            // Body
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(SV.heading(15))
                    .foregroundStyle(SV.textPrimary(scheme))
                    .lineLimit(1)

                Text(project.description)
                    .font(SV.body(12))
                    .foregroundStyle(SV.textTertiary(scheme))
                    .lineLimit(2)
                    .lineSpacing(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Tags
            HStack(spacing: 6) {
                ForEach(project.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(SV.label(7))
                        .tracking(0.8)
                        .foregroundStyle(SV.textTertiary(scheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            Capsule().stroke(SV.border(scheme), lineWidth: 1)
                        )
                }
                Spacer()
                Text("\(project.properties.count) props")
                    .font(SV.mono(10))
                    .foregroundStyle(SV.textTertiary(scheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(SV.border(scheme)).frame(height: 1)
            }
        }
        .svCard()
    }

    private var badgeColor: Color {
        switch project.type {
        case .unlit: return SV.gold
        case .postProcess: return SV.violet
        default: return SV.emerald
        }
    }
}
