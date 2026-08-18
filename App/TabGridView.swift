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
            .font(.caption.monospaced().weight(.bold))
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
        SwipeClosableTabCard(
            tab: tab,
            thumbnail: store.thumbnail(for: tab.id),
            isSelected: store.selectedTabID == tab.id,
            onOpen: {
                store.activateTab(tab.id)
                isPresented = false
            },
            onClose: {
                store.closeTab(tab.id)
            }
        )
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
                    .font(.caption.monospaced().weight(.bold))
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

private struct SwipeClosableTabCard: View {
    let tab: BrowserTab
    let thumbnail: UIImage?
    let isSelected: Bool
    let onOpen: () -> Void
    let onClose: () -> Void

    @State private var dragOffset = 0.0

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.fireballOrange.opacity(0.9))
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.fireballBackground)
                        .padding(.trailing, 24)
                }

            ZStack(alignment: .topTrailing) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack {
                            Color.fireballRaised
                            if let thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                                        .font(.system(size: 25, weight: .light))
                                        .foregroundStyle(tab.isPrivate ? Color.fireballOrange : Color.fireballGreen)
                                    Text(tab.url?.host() ?? "HOME")
                                        .font(.caption2.monospaced().weight(.bold))
                                        .foregroundStyle(Color.fireballMuted)
                                }
                            }
                        }
                        .frame(height: 118)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(tab.title)
                                .font(.caption.monospaced().weight(.bold))
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
                            .stroke(isSelected ? Color.fireballGreen : Color.white.opacity(0.1), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.title), \(tab.url?.host() ?? "Fireball home")")
                .accessibilityHint("Double-tap to open. Swipe left to close.")
                .accessibilityIdentifier("tab.card")
                .accessibilityAction(named: "Close tab") { onClose() }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.58), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(tab.title)")
                .accessibilityIdentifier("tab.close")
                .padding(4)
            }
            .offset(x: dragOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = min(0, max(-120, value.translation.width))
                }
                .onEnded { value in
                    let shouldClose = value.translation.width < -72 || value.predictedEndTranslation.width < -120
                    if shouldClose {
                        withAnimation(.easeIn(duration: 0.16)) { dragOffset = -320 }
                        onClose()
                    } else {
                        withAnimation(.snappy(duration: 0.22)) { dragOffset = 0 }
                    }
                }
        )
    }
}
