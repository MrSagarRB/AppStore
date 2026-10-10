import SwiftUI

extension Date {
    var relative: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}

/// Leading icon: a thumbnail for images, a tinted kind symbol for everything else.
struct ClipIcon: View {
    let item: ClipItem
    var size: CGFloat = 34

    var body: some View {
        Group {
            if item.kind == .image, let image = ImageLoader.image(for: item, maxPixel: Int(size * 2)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.kind.symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var tint: Color {
        switch item.kind {
        case .text: .gray
        case .code: .indigo
        case .url: .blue
        case .image: .orange
        }
    }
}

struct ClipRow: View {
    @ObservedObject var store: ClipStore
    let item: ClipItem

    var body: some View {
        HStack(spacing: 10) {
            ClipIcon(item: item)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.headline)
                    .font(.system(.body, design: item.kind == .code && item.title == nil ? .monospaced : .default))
                    .lineLimit(2)
                    .truncationMode(.tail)
                HStack(spacing: 6) {
                    if let folder = store.folder(item.folderID) {
                        Label(folder.name, systemImage: "folder")
                    }
                    if let app = item.sourceApp { Text(app) }
                    Text(item.lastUsedAt.relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .draggable(item.id.uuidString)
    }
}

/// "Move to Folder" submenu shared by the list context menu and the detail toolbar.
struct FolderMenu: View {
    @ObservedObject var store: ClipStore
    let ids: Set<UUID>
    let newFolder: () -> Void

    var body: some View {
        Menu {
            ForEach(store.folders) { folder in
                Button(folder.name) { store.move(ids, to: folder.id) }
            }
            if !store.folders.isEmpty { Divider() }
            Button("New Folder…", action: newFolder)
            Button("Remove from Folder") { store.move(ids, to: nil) }
        } label: {
            Label("Move to Folder", systemImage: "folder.badge.plus")
        }
    }
}
