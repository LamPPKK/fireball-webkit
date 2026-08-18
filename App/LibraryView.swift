import SwiftUI

struct LibraryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case bookmarks = "Bookmarks"
        case history = "History"
        var id: String { rawValue }
    }

    @Bindable var store: BrowserStore
    @Binding var isPresented: Bool
    @State private var section: Section = .bookmarks

    private var profileBookmarks: [Bookmark] {
        guard let profileID = store.activeProfile?.id else { return [] }
        return store.bookmarks.filter { $0.profileID == profileID }
    }

    private var profileHistory: [HistoryVisit] {
        guard let profileID = store.activeProfile?.id else { return [] }
        return store.history.filter { $0.profileID == profileID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fireballBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Library section", selection: $section) {
                        ForEach(Section.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(16)

                    if section == .bookmarks {
                        bookmarksList
                    } else {
                        historyList
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if section == .history && !profileHistory.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear", role: .destructive) {
                            if let profileID = store.activeProfile?.id {
                                store.clearHistory(for: profileID)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Done")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var bookmarksList: some View {
        Group {
            if profileBookmarks.isEmpty {
                emptyState("No bookmarks", icon: "bookmark")
            } else {
                List {
                    ForEach(profileBookmarks) { bookmark in
                        libraryRow(title: bookmark.title, url: bookmark.url, icon: "bookmark.fill")
                            .swipeActions {
                                Button("Delete", role: .destructive) { store.removeBookmark(bookmark.id) }
                            }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var historyList: some View {
        Group {
            if profileHistory.isEmpty {
                emptyState("No regular history", icon: "clock")
            } else {
                List(profileHistory) { visit in
                    libraryRow(title: visit.title, url: visit.url, icon: "clock.arrow.circlepath")
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func libraryRow(title: String, url: URL, icon: String) -> some View {
        Button {
            try? store.navigate(url.absoluteString)
            isPresented = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.fireballGreen)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).lineLimit(1)
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(Color.fireballMuted)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ title: String, icon: String) -> some View {
        ContentUnavailableView(title, systemImage: icon, description: Text("Private activity never appears here."))
            .foregroundStyle(Color.fireballMuted)
    }
}
