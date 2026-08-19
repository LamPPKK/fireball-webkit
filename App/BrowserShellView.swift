import SwiftUI
import UIKit

struct BrowserShellView: View {
    private enum FocusedControl: Hashable {
        case address
    }

    @Bindable var store: BrowserStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var addressControlHeight: CGFloat = 48
    @State private var address = ""
    @State private var showTabs = false
    @State private var showLibrary = false
    @State private var showSettings = false
    @State private var commandRouter = BrowserCommandRouter()
    @FocusState private var focusedControl: FocusedControl?

    var body: some View {
        ZStack {
            Color.fireballBackground.ignoresSafeArea()

            if !store.isReady {
                loadingView
            } else if store.selectedProfileIsLocked {
                lockedView
            } else {
                browserChrome
            }

            if store.privacyShieldVisible {
                privacyShield
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showTabs) {
            TabGridView(store: store, isPresented: $showTabs)
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView(store: store, isPresented: $showLibrary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
        .alert("Fireball", isPresented: errorBinding) {
            Button("Dismiss", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "The operation could not be completed.")
        }
        .confirmationDialog(
            "Open another app?",
            isPresented: externalURLBinding,
            titleVisibility: .visible
        ) {
            if let url = store.pendingExternalURL {
                Button("Open \(url.scheme?.uppercased() ?? "Link")") {
                    UIApplication.shared.open(url)
                    store.pendingExternalURL = nil
                }
            }
            Button("Cancel", role: .cancel) { store.pendingExternalURL = nil }
        } message: {
            Text(store.pendingExternalURL?.absoluteString ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            store.releaseBackgroundSessions()
        }
        .onChange(of: store.selectedTabID) { _, _ in syncAddress() }
        .onChange(of: store.activeSession?.currentURL) { _, _ in syncAddress() }
        .onChange(of: commandRouter.sequence) { _, _ in handleCommand() }
        .focusedSceneValue(\.browserCommandRouter, commandRouter)
    }

    private var browserChrome: some View {
        VStack(spacing: 0) {
            statusRail
            ZStack(alignment: .top) {
                if let session = store.activeSession {
                    BrowserWebView(session: session)
                        .id(session.tabID)
                        .background(Color.fireballBackground)
                    if session.isLoading {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(Color.fireballGreen)
                                .frame(width: max(2, proxy.size.width * session.estimatedProgress), height: 2)
                                .animation(.easeOut(duration: 0.2), value: session.estimatedProgress)
                        }
                        .frame(height: 2)
                    }
                } else {
                    FireballHomeView(store: store)
                }
            }
            bottomToolbar
        }
    }

    private var statusRail: some View {
        HStack(spacing: 10) {
            FireballBrandMark(size: 30)
            Text("Fireball")
                .font(.headline.weight(.black))
                .foregroundStyle(Color.fireballCream)
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                contextBadge(
                    store.activeProfile?.name.uppercased() ?? "NO PROFILE",
                    systemImage: "person.crop.circle",
                    accent: .fireballGreen
                )
                contextBadge(
                    store.selectedSpace?.name.uppercased() ?? "NO SPACE",
                    systemImage: store.selectedSpace?.storageMode == .ephemeral ? "eye.slash" : "square.stack.3d.up",
                    accent: store.selectedSpace?.storageMode == .ephemeral ? .fireballOrange : .fireballMuted
                )
            }
            Spacer()
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                Label(store.syncStatus.label, systemImage: "icloud")
                    .foregroundStyle(syncColor)
            }
            Label(
                "\(store.tabsInSelectedSpace.count)",
                systemImage: "square.on.square"
            )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.fireballMuted)
                .lineLimit(2)
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 48)
        .background(Color.fireballPanel.opacity(0.98))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.fireballBorder).frame(height: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Browser status")
        .accessibilityValue(statusAccessibilityValue)
        .accessibilityIdentifier("browser.status")
    }

    private var bottomToolbar: some View {
        VStack(spacing: 9) {
            navigationAndAddressRow

            HStack(spacing: 8) {
                Button { showTabs = true } label: {
                    Label("Tabs", systemImage: "square.grid.2x2")
                }
                .accessibilityIdentifier("browser.tabs")
                Spacer()
                Button { store.toggleBookmarkForActiveTab() } label: {
                    Label(
                        "Bookmark",
                        systemImage: store.isBookmarked(store.activeTab?.url) ? "bookmark.fill" : "bookmark"
                    )
                }
                .disabled(store.activeTab?.url == nil || store.activeTab?.isPrivate == true)
                if let url = store.activeTab?.url {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("browser.share")
                }
                Button { showLibrary = true } label: {
                    Label("Library", systemImage: "books.vertical")
                }
                .accessibilityIdentifier("browser.library")
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("browser.settings")
            }
            .buttonStyle(FireballCompactButtonStyle())
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.fireballBorder)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.fireballBackground)
    }

    @ViewBuilder
    private var navigationAndAddressRow: some View {
        if horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    navigationButtons
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    addressField
                    goButton
                }
            }
        } else {
            HStack(spacing: 6) {
                navigationButtons
                addressField
                goButton
            }
        }
    }

    @ViewBuilder
    private var navigationButtons: some View {
        toolButton("chevron.left", label: "Back", enabled: store.activeSession?.canGoBack == true) {
            store.activeSession?.goBack()
        }
        toolButton("chevron.right", label: "Forward", enabled: store.activeSession?.canGoForward == true) {
            store.activeSession?.goForward()
        }
        toolButton(
            store.activeSession?.isLoading == true ? "xmark" : "arrow.clockwise",
            label: store.activeSession?.isLoading == true ? "Stop" : "Reload"
        ) {
            if store.activeSession?.isLoading == true {
                store.activeSession?.stopLoading()
            } else {
                store.activeSession?.reload()
            }
        }
        toolButton("house", label: "Home") { store.openHome() }
    }

    private var addressField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(focusedControl == .address ? Color.fireballGreen : Color.fireballMuted)
                .accessibilityHidden(true)
            TextField("Address", text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit(navigate)
                .font(.body.weight(.medium))
                .lineLimit(1)
                .accessibilityLabel("Address and search")
                .accessibilityHint("Enter a website address or search terms")
                .accessibilityIdentifier("browser.omnibox")
                .focused($focusedControl, equals: .address)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: max(48, addressControlHeight))
        .background(Color.fireballRaised, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(focusedControl == .address ? Color.fireballGreen : Color.fireballBorder, lineWidth: 1)
        }
    }

    private var goButton: some View {
        Button(action: navigate) {
            Image(systemName: "arrow.up.right")
                .font(.headline.weight(.black))
                .frame(width: 48, height: max(48, addressControlHeight))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.fireballBackground)
        .background(Color.fireballGreen, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityLabel("Go")
        .accessibilityHint("Open the address or search")
        .accessibilityIdentifier("browser.go")
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            FireballBrandMark(size: 72)
            ProgressView().tint(Color.fireballGreen).controlSize(.large)
            Text("INITIALIZING PRIVATE STORES")
                .font(.caption.monospaced().weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.fireballMuted)
        }
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(Color.fireballGreen)
            Text("PROFILE LOCKED")
                .font(.title2.monospaced().weight(.black))
            Text("Authenticate to reveal \(store.activeProfile?.name ?? "this profile").")
                .foregroundStyle(Color.fireballMuted)
            Button("Unlock") { Task { await store.unlockActiveProfileIfNeeded() } }
                .buttonStyle(.borderedProminent)
                .tint(Color.fireballGreen)
                .foregroundStyle(Color.fireballBackground)
                .controlSize(.large)
            Button("Recover with device authentication") {
                Task { await store.recoverActiveProfileAccess() }
            }
            .buttonStyle(.bordered)
            .tint(Color.fireballMuted)
        }
        .padding(28)
        .fireballPanel()
        .padding(24)
    }

    private var privacyShield: some View {
        ZStack {
            Color.fireballBackground.ignoresSafeArea()
            FireballTrajectory()
            VStack(spacing: 12) {
                FireballBrandMark(size: 104)
                Text("Fireball")
                    .font(.title2.weight(.black))
                Text("CONTENT HIDDEN")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(Color.fireballMuted)
            }
        }
        .accessibilityLabel("Fireball content hidden while the app is inactive")
    }

    private func toolButton(
        _ symbol: String,
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.35))
        .accessibilityLabel(label)
    }

    private func contextBadge(_ title: String, systemImage: String, accent: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.monospaced().weight(.bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(Color.fireballRaised, in: Capsule())
            .overlay { Capsule().stroke(Color.fireballBorder) }
    }

    private func navigate() {
        do {
            try store.navigate(address)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func syncAddress() {
        address = store.activeSession?.currentURL?.absoluteString ?? store.activeTab?.url?.absoluteString ?? ""
    }

    private func handleCommand() {
        guard let request = commandRouter.request else { return }
        switch request {
        case .newTab:
            _ = store.createTab()
            syncAddress()
            focusedControl = .address
        case .closeTab:
            guard let tabID = store.selectedTabID else { return }
            store.closeTab(tabID)
            syncAddress()
        case .focusAddress:
            syncAddress()
            focusedControl = .address
        case .goBack:
            store.activeSession?.goBack()
        case .goForward:
            store.activeSession?.goForward()
        case .reload:
            store.activeSession?.reload()
        case .home:
            store.openHome()
            syncAddress()
        case .showTabs:
            showTabs = true
        case .toggleBookmark:
            store.toggleBookmarkForActiveTab()
        }
    }

    private var statusAccessibilityValue: String {
        let profile = store.activeProfile?.name ?? "No profile"
        let space = store.selectedSpace?.name ?? "No space"
        let tabCount = store.tabsInSelectedSpace.count
        return "Profile \(profile), space \(space), \(tabCount) tab\(tabCount == 1 ? "" : "s"), sync \(store.syncStatus.label)"
    }

    private var syncColor: Color {
        switch store.syncStatus {
        case .available: .fireballGreen
        case .starting, .syncing: .yellow
        case .localOnly: .fireballMuted
        case .degraded: .fireballOrange
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    private var externalURLBinding: Binding<Bool> {
        Binding(
            get: { store.pendingExternalURL != nil },
            set: { if !$0 { store.pendingExternalURL = nil } }
        )
    }
}

private struct FireballCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .frame(minWidth: 48, minHeight: 48)
            .contentShape(Rectangle())
            .foregroundStyle(configuration.isPressed ? Color.fireballGreen : Color.fireballCream)
            .background(
                configuration.isPressed ? Color.fireballRaised : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
