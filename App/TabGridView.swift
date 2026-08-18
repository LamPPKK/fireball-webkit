import SwiftUI

struct TabGridView: View {
    @Bindable var store: BrowserStore
    @Binding var isPresented: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var newProfileName = ""
    @State private var showNewProfile = false

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fireballBackground.ignoresSafeArea()
                if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        spaceSidebar
                            .frame(width: 230)
                        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
                        tabGrid
                    }
                } else {
                    VStack(spacing: 0) {
                        spaceRail
                        tabGrid
                    }
                }
            }
            .navigationTitle("Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("New private space", systemImage: "eye.slash") {
                            store.createPrivateSpace()
                        }
                        Button("New profile", systemImage: "person.crop.circle.badge.plus") {
                            showNewProfile = true
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Create space or profile")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
            .alert("New profile", isPresented: $showNewProfile) {
                TextField("Profile name", text: $newProfileName)
                Button("Create") {
                    store.createProfile(name: newProfileName)
                    newProfileName = ""
                }
                Button("Cancel", role: .cancel) { newProfileName = "" }
            } message: {
                Text("Profiles use separate persistent WebKit data stores.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var spaceRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.spaces) { space in
                    spaceButton(space, compact: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.fireballPanel)
    }

    private var spaceSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            FireballSectionLabel(title: "Spaces", index: "01")
                .padding(.horizontal, 16)
                .padding(.top, 18)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.spaces) { space in
                        spaceButton(space, compact: false)
                    }
                }
                .padding(.horizontal, 10)
            }
            Spacer(minLength: 0)
        }
        .background(Color.fireballPanel)
    }

    private var tabGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.tabsInSelectedSpace) { tab in
                    tabCard(tab)
                }
                newTabCard
            }
            .padding(16)
        }
    }

    private func spaceButton(_ space: BrowserSpace, compact: Bool) -> some View {
        Button {
            Task { await store.selectSpace(space.id) }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(space.storageMode == .ephemeral ? Color.fireballOrange : Color.fireballGreen)
                    .frame(width: 7, height: 7)
                Text(space.name.uppercased())
                Spacer(minLength: compact ? 0 : 8)
                Text("\(store.tabs.filter { $0.spaceID == space.id }.count)")
                    .foregroundStyle(Color.fireballMuted)
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .padding(.horizontal, 13)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: 40, alignment: .leading)
            .background(
                store.selectedSpaceID == space.id ? Color.fireballRaised : Color.clear,
                in: RoundedRectangle(cornerRadius: compact ? 20 : 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 20 : 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
    }

    private func tabCard(_ tab: BrowserTab) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                store.activateTab(tab.id)
                isPresented = false
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Color.fireballRaised
                        if let image = store.thumbnail(for: tab.id) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                                    .font(.system(size: 25, weight: .light))
                                    .foregroundStyle(tab.isPrivate ? Color.fireballOrange : Color.fireballGreen)
                                Text(tab.url?.host() ?? "HOME")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.fireballMuted)
                            }
                        }
                    }
                    .frame(height: 118)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(tab.title)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Text(tab.url?.absoluteString ?? "Fireball home")
                            .font(.caption2)
                            .foregroundStyle(Color.fireballMuted)
                            .lineLimit(1)
                    }
                    .padding(12)
                }
                .background(Color.fireballPanel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(store.selectedTabID == tab.id ? Color.fireballGreen : Color.white.opacity(0.1), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Button {
                store.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(tab.title)")
            .padding(4)
        }
    }

    private var newTabCard: some View {
        Button {
            _ = store.createTab()
            isPresented = false
        } label: {
            VStack(spacing: 11) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .light))
                Text("NEW TAB")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Color.fireballGreen)
            .frame(maxWidth: .infinity, minHeight: 176)
            .background(Color.fireballPanel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.fireballGreen.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New tab")
        .accessibilityIdentifier("tabs.new")
    }
}
