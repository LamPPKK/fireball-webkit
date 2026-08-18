import SwiftUI
import UIKit

struct BrowserShellView: View {
    @Bindable var store: BrowserStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var address = ""
    @State private var showTabs = false
    @State private var showLibrary = false
    @State private var showSettings = false

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
    }

    private var browserChrome: some View {
        VStack(spacing: 0) {
            statusRail
            ZStack(alignment: .top) {
                if let session = store.activeSession {
                    BrowserWebView(session: session)
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
            Text("FIREBALL")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .tracking(1.8)
            Rectangle().fill(Color.fireballGreen).frame(width: 22, height: 2)
            Text(store.activeProfile?.name.uppercased() ?? "NO PROFILE")
                .foregroundStyle(Color.fireballMuted)
            Text("/")
                .foregroundStyle(Color.white.opacity(0.24))
            Text(store.selectedSpace?.name.uppercased() ?? "NO SPACE")
                .foregroundStyle(store.selectedSpace?.storageMode == .ephemeral ? Color.fireballOrange : .secondary)
            Spacer()
            if horizontalSizeClass == .regular {
                Text(store.syncStatus.label)
                    .foregroundStyle(syncColor)
            }
            Text("\(store.tabsInSelectedSpace.count) TAB\(store.tabsInSelectedSpace.count == 1 ? "" : "S")")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .background(Color.fireballPanel)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
    }

    private var bottomToolbar: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
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

                TextField("Search or enter address", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(navigate)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .background(Color.fireballRaised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.14))
                    }
                    .accessibilityLabel("Address and search")
                    .accessibilityIdentifier("browser.omnibox")

                Button(action: navigate) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.fireballBackground)
                .background(Color.fireballGreen, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityLabel("Go")
            }

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
                Button { showLibrary = true } label: {
                    Label("Library", systemImage: "books.vertical")
                }
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("browser.settings")
            }
            .buttonStyle(FireballCompactButtonStyle())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView().tint(Color.fireballGreen).controlSize(.large)
            Text("INITIALIZING PRIVATE STORES")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
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
                .font(.system(size: 24, weight: .black, design: .monospaced))
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
            VStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(Color.fireballOrange)
                Text("FIREBALL")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .tracking(3)
                Text("CONTENT HIDDEN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
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
                .font(.system(size: 14, weight: .bold))
                .frame(width: 44, height: 46)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.35))
        .accessibilityLabel(label)
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
            .frame(minWidth: 44, minHeight: 36)
            .foregroundStyle(configuration.isPressed ? Color.fireballGreen : Color.primary)
            .background(
                configuration.isPressed ? Color.fireballRaised : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}
