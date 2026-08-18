import SwiftUI

struct FireballHomeView: View {
    @Bindable var store: BrowserStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var profileBookmarks: [Bookmark] {
        guard let profileID = store.activeProfile?.id else { return [] }
        return Array(store.bookmarks.filter { $0.profileID == profileID }.prefix(6))
    }

    private var profileHistory: [HistoryVisit] {
        guard let profileID = store.activeProfile?.id else { return [] }
        return Array(store.history.filter { $0.profileID == profileID }.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero

                if !profileBookmarks.isEmpty {
                    FireballSectionLabel(title: "Bookmarks", index: "01")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(profileBookmarks) { bookmark in
                            homeLink(title: bookmark.title, url: bookmark.url, icon: "bookmark.fill")
                        }
                    }
                }

                if !profileHistory.isEmpty {
                    FireballSectionLabel(title: "Recent", index: "02")
                    VStack(spacing: 1) {
                        ForEach(profileHistory) { visit in
                            Button {
                                try? store.navigate(visit.url.absoluteString)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(Color.fireballMuted)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(visit.title).lineLimit(1)
                                        Text(visit.url.host() ?? visit.url.absoluteString)
                                            .font(.caption)
                                            .foregroundStyle(Color.fireballMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(Color.fireballGreen)
                                }
                                .padding(13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Open in the current tab")
                        }
                    }
                    .fireballPanel()
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 32)
        }
        .background {
            LinearGradient(
                colors: [Color.fireballBackground, Color(red: 0.05, green: 0.08, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityIdentifier("browser.home")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroMetadata
            Text("A QUIET PLACE\nFOR A LOUD WEB.")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Profiles keep website data apart. Private spaces leave no restorable tabs. History stays local unless you explicitly enable iCloud sync.")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.fireballMuted)
                .frame(maxWidth: 590, alignment: .leading)
        }
        .padding(24)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.fireballPanel
                Circle()
                    .fill(Color.fireballOrange.opacity(0.18))
                    .frame(width: 190, height: 190)
                    .offset(x: 54, y: 72)
                Circle()
                    .stroke(Color.fireballGreen.opacity(0.36), lineWidth: 1)
                    .frame(width: 94, height: 94)
                    .offset(x: -38, y: 30)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12))
        }
    }

    @ViewBuilder
    private var heroMetadata: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                versionLabel
                searchProviderLabel
            }
        } else {
            HStack {
                versionLabel
                Spacer()
                searchProviderLabel
            }
        }
    }

    private var versionLabel: some View {
        Text("BROWSER / 0.1")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.fireballGreen)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var searchProviderLabel: some View {
        Text(store.activeProfile?.searchProvider.displayName.uppercased() ?? "BRAVE SEARCH")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.fireballMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func homeLink(title: String, url: URL, icon: String) -> some View {
        Button {
            try? store.navigate(url.absoluteString)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(Color.fireballGreen)
                Text(title)
                    .font(.subheadline.monospaced().weight(.bold))
                    .lineLimit(2)
                Text(url.host() ?? url.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(Color.fireballMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(14)
        }
        .buttonStyle(.plain)
        .fireballPanel()
    }
}
