import SwiftUI

struct MediaGalleryView: View {
    let fileNames: [String]
    let projectId: UUID
    @Environment(\.colorScheme) var scheme
    @State private var selectedImage: UIImage?

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(fileNames, id: \.self) { fileName in
                mediaItem(fileName)
            }
        }
        .overlay {
            if let img = selectedImage {
                fullscreenViewer(img)
            }
        }
    }

    private func mediaItem(_ fileName: String) -> some View {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let isVideo = ["mp4", "webm", "mov"].contains(ext)

        return ZStack {
            SV.surface(scheme)

            if let img = StorageService.shared.loadMediaImage(fileName: fileName, projectId: projectId) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: isVideo ? "play.rectangle.fill" : "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(SV.textTertiary(scheme))
            }

            if isVideo {
                ZStack {
                    Color.black.opacity(0.3)
                    Circle()
                        .fill(SV.emerald.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.black)
                                .offset(x: 1)
                        )
                        .shadow(color: SV.emerald.opacity(0.3), radius: 8)
                }
            }
        }
        .aspectRatio(16/10, contentMode: .fill)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SV.border(scheme), lineWidth: 1)
        )
        .onTapGesture {
            if !isVideo,
               let img = StorageService.shared.loadMediaImage(fileName: fileName, projectId: projectId) {
                withAnimation(.spring(response: 0.3)) {
                    selectedImage = img
                }
            }
        }
    }

    private func fullscreenViewer(_ img: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        selectedImage = nil
                    }
                }

            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(24)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedImage = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(20)
                Spacer()
            }
        }
        .transition(.opacity)
    }
}
