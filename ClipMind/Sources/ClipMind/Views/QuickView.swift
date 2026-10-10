import SwiftUI

/// The menu-bar popover (also ⌘⇧V): search, arrow keys, Return to copy.
struct QuickView: View {
    @ObservedObject var store: ClipStore
    let close: () -> Void
    let openMain: () -> Void
    let openSettings: () -> Void

    @State private var query = ""
    @State private var selected: UUID?
    @FocusState private var focused: Bool

    private var results: [ClipItem] {
        Array(store.filtered(.all, query: query, pinnedFirst: true).prefix(60))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clips", text: $query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { copySelected() }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            Divider()

            if results.isEmpty {
                ContentUnavailableView(query.isEmpty ? "Nothing Copied Yet" : "No Matches",
                                       systemImage: query.isEmpty ? "paperclip" : "magnifyingglass")
            } else {
                ScrollViewReader { proxy in
                    List(selection: $selected) {
                        ForEach(results) { item in
                            ClipRow(store: store, item: item)
                                .tag(item.id)
                                .id(item.id)
                                .onTapGesture { copy(item) }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selected) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }

            Divider()
            HStack {
                Button("Open ClipMind", action: openMain)
                Spacer()
                Button { openSettings() } label: { Image(systemName: "gearshape") }
                    .help("Settings")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .help("Quit ClipMind")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .frame(width: 380, height: 520)
        .onAppear {
            DispatchQueue.main.async { focused = true }
            selected = results.first?.id
        }
        .onChange(of: query) { selected = results.first?.id }
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selected } ?? (delta > 0 ? -1 : results.count)
        selected = results[min(max(current + delta, 0), results.count - 1)].id
    }

    private func copySelected() {
        if let item = results.first(where: { $0.id == selected }) ?? results.first { copy(item) }
    }

    private func copy(_ item: ClipItem) {
        ClipboardMonitor.shared.copy(item)
        close()
    }
}
