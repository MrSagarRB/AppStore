import SwiftUI

struct MainView: View {
    @ObservedObject var store: ClipStore

    @State private var scope: Scope? = .all
    @State private var query = ""
    @State private var selection: Set<UUID> = []
    @State private var toast: String?

    @State private var showFolderAlert = false
    @State private var folderName = ""
    @State private var renamingFolder: Folder?
    @State private var pendingMove: Set<UUID> = []

    @FocusState private var searchFocused: Bool

    private var currentScope: Scope { scope ?? .all }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } content: {
            clipList
                .navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 520)
        } detail: {
            detail
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4, y: 1)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(renamingFolder == nil ? "New Folder" : "Rename Folder", isPresented: $showFolderAlert) {
            TextField("Name", text: $folderName)
            Button("Cancel", role: .cancel) { pendingMove = [] }
            Button(renamingFolder == nil ? "Create" : "Rename", action: commitFolder)
        }
        .onChange(of: scope) { selection = [] }
        .onAppear {
            // Debug aid: `ClipMind --select-first` opens with the newest clip selected.
            if CommandLine.arguments.contains("--select-first"), let first = store.filtered(.all, query: "").first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scope = .all
                    selection = [first.id]
                }
            }
        }
        .background(
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
        )
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $scope) {
            Section("Library") {
                Label("All Clips", systemImage: "tray.full")
                    .badge(store.count(.all)).tag(Scope.all)
                Label("Pinned", systemImage: "pin")
                    .badge(store.count(.pinned)).tag(Scope.pinned)
            }
            Section("Types") {
                ForEach(ClipKind.allCases, id: \.self) { kind in
                    Label(kind.pluralLabel, systemImage: kind.symbol)
                        .badge(store.count(.kind(kind))).tag(Scope.kind(kind))
                }
            }
            Section {
                ForEach(store.folders) { folder in
                    Label(folder.name, systemImage: "folder")
                        .badge(store.count(.folder(folder.id)))
                        .tag(Scope.folder(folder.id))
                        .dropDestination(for: String.self) { strings, _ in
                            let ids = Set(strings.compactMap(UUID.init(uuidString:)))
                            store.move(ids, to: folder.id)
                            return !ids.isEmpty
                        }
                        .contextMenu {
                            Button("Rename…") {
                                renamingFolder = folder
                                folderName = folder.name
                                showFolderAlert = true
                            }
                            Button("Delete Folder", role: .destructive) {
                                if scope == .folder(folder.id) { scope = .all }
                                store.deleteFolder(folder.id)
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Folders")
                    Spacer()
                    Button(action: beginNewFolder) { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                        .help("New Folder")
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: List

    private var clipList: some View {
        let items = store.filtered(currentScope, query: query)
        let showSections = currentScope == .all && query.isEmpty && items.contains { $0.isPinned }

        return VStack(spacing: 0) {
            searchField
            Divider()
            if items.isEmpty {
                emptyState
            } else {
                List(selection: $selection) {
                    if showSections {
                        Section("Pinned") { rows(items.filter(\.isPinned)) }
                        Section("Recent") { rows(items.filter { !$0.isPinned }) }
                    } else {
                        rows(items)
                    }
                }
                .listStyle(.inset)
                .contextMenu(forSelectionType: UUID.self) { ids in
                    contextMenu(for: ids)
                } primaryAction: { ids in
                    if let id = ids.first { copy(id) }
                }
                .onKeyPress(.return) {
                    guard selection.count == 1, let id = selection.first else { return .ignored }
                    copy(id)
                    return .handled
                }
                .onDeleteCommand { store.remove(selection); selection = [] }
            }
        }
    }

    private func rows(_ items: [ClipItem]) -> some View {
        ForEach(items) { item in
            ClipRow(store: store, item: item).tag(item.id)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            switch currentScope {
            case .pinned:
                ContentUnavailableView("No Pinned Clips", systemImage: "pin",
                                       description: Text("Pin a clip to keep it here and out of the history limit."))
            case .folder:
                ContentUnavailableView("Empty Folder", systemImage: "folder",
                                       description: Text("Drag clips here, or right-click a clip and choose Move to Folder."))
            default:
                ContentUnavailableView("Nothing Copied Yet", systemImage: "paperclip",
                                       description: Text("Copy text, code, a link or an image and it will show up here."))
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<UUID>) -> some View {
        if !ids.isEmpty {
            let allPinned = ids.allSatisfy { store.item($0)?.isPinned == true }
            if ids.count == 1, let id = ids.first {
                Button("Copy") { copy(id) }
                Divider()
            }
            Button(allPinned ? "Unpin" : "Pin", systemImage: allPinned ? "pin.slash" : "pin") {
                store.setPinned(ids, !allPinned)
            }
            FolderMenu(store: store, ids: ids) { pendingMove = ids; beginNewFolder() }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                store.remove(ids)
                selection.subtract(ids)
            }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if selection.count == 1, let id = selection.first {
            DetailView(store: store, id: id, onCopy: { copy(id) }) {
                pendingMove = [id]
                beginNewFolder()
            }
            .id(id)
        } else if selection.count > 1 {
            ContentUnavailableView("\(selection.count) Clips Selected", systemImage: "square.stack",
                                   description: Text("Right-click to pin, move or delete them together."))
        } else {
            ContentUnavailableView("Select a Clip", systemImage: "doc.on.clipboard",
                                   description: Text("Double-click or press Return to copy it again."))
        }
    }

    // MARK: Actions

    private func copy(_ id: UUID) {
        guard let item = store.item(id) else { return }
        ClipboardMonitor.shared.copy(item)
        withAnimation { toast = "Copied to clipboard" }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { toast = nil }
        }
    }

    private func beginNewFolder() {
        renamingFolder = nil
        folderName = ""
        showFolderAlert = true
    }

    private func commitFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { pendingMove = []; renamingFolder = nil }
        guard !name.isEmpty else { return }
        if let renamingFolder {
            store.renameFolder(renamingFolder.id, to: name)
        } else {
            let folder = store.addFolder(name)
            if !pendingMove.isEmpty { store.move(pendingMove, to: folder.id) }
        }
    }
}
