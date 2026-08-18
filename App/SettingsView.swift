import SwiftUI

struct SettingsView: View {
    @Bindable var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHistoryConsent = false
    @State private var showDeleteProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fireballBackground.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 22) {
                        profileSection
                        privacySection
                        syncSection
                        aboutSection
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Done")
                }
            }
            .confirmationDialog(
                "Sync browsing history with iCloud?",
                isPresented: $showHistoryConsent,
                titleVisibility: .visible
            ) {
                Button("Enable 90-day history sync") { store.setHistorySyncEnabled(true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Visited URLs, page titles and visit times will be stored in your private iCloud database. Cookies, passwords and private tabs are never included.")
            }
            .confirmationDialog(
                "Delete this profile?",
                isPresented: $showDeleteProfile,
                titleVisibility: .visible
            ) {
                if let profile = store.activeProfile {
                    Button("Delete \(profile.name)", role: .destructive) {
                        Task { await store.deleteProfile(profile.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Fireball will remove the profile's tabs, bookmarks, history, Keychain lock and local WebKit website data.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var profileSection: some View {
        settingsSection("Active profile", index: "01") {
            if let profile = store.activeProfile {
                settingsValue("Name", value: profile.name)
                settingsValue(
                    "Storage",
                    value: profile.storageMode == .persistent
                        ? "Persistent / isolated"
                        : "Private / memory"
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Search engine")
                        .font(.body.weight(.semibold))
                    Menu {
                        ForEach(SearchProvider.allCases, id: \.self) { provider in
                            Button {
                                store.updateSearchProvider(provider, for: profile.id)
                            } label: {
                                if profile.searchProvider == provider {
                                    Label(provider.displayName, systemImage: "checkmark")
                                } else {
                                    Text(provider.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(profile.searchProvider.displayName)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(Color.fireballGreen)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .background(
                            Color.fireballRaised,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .accessibilityLabel("Search engine")
                    .accessibilityValue(profile.searchProvider.displayName)
                }
                .disabled(profile.storageMode == .ephemeral)

                if profile.storageMode == .persistent && store.regularProfiles.count > 1 {
                    settingsButton("Delete profile", systemImage: "trash", role: .destructive) {
                        showDeleteProfile = true
                    }
                }
            }
        }
    }

    private var privacySection: some View {
        settingsSection("Privacy", index: "02") {
            if let profile = store.activeProfile {
                Toggle("Content blocker", isOn: blockerBinding(profile))
                    .font(.body)
                    .frame(minHeight: 48)
                    .disabled(profile.storageMode == .ephemeral)

                settingsValue("Rules", value: store.blockerStatus)
                settingsButton("Update rules", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await store.refreshBlockerRules() }
                }

                if profile.storageMode == .persistent {
                    Toggle("Biometric lock", isOn: biometricBinding(profile))
                        .font(.body)
                        .frame(minHeight: 48)
                }
            }
            settingsValue("Private tabs", value: "Never restored")
            settingsValue("Telemetry", value: "None")
        }
    }

    private var syncSection: some View {
        settingsSection("iCloud private database", index: "03") {
            settingsValue("Status", value: store.syncStatus.label)
            Text(store.syncStatus.detail)
                .font(.body)
                .foregroundStyle(Color.fireballMuted)
                .fixedSize(horizontal: false, vertical: true)
            settingsButton(
                store.settings.historySyncEnabled ? "Disable history sync" : "History sync",
                systemImage: "icloud"
            ) {
                if store.settings.historySyncEnabled {
                    store.setHistorySyncEnabled(false)
                } else {
                    showHistoryConsent = true
                }
            }
            Text("Profiles, spaces, regular tabs and bookmarks sync when iCloud is available. History is opt-in and retained for 90 days.")
                .font(.body)
                .foregroundStyle(Color.fireballMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutSection: some View {
        settingsSection("About", index: "04") {
            settingsValue("Application", value: "Fireball Browser")
            settingsValue("Version", value: "0.1.0")
            settingsLink(
                "Privacy policy",
                systemImage: "hand.raised",
                destination: URL(string: "https://lamppkk.github.io/fireball-webkit/privacy.html")!
            )
            settingsLink(
                "Support",
                systemImage: "questionmark.circle",
                destination: URL(string: "https://lamppkk.github.io/fireball-webkit/support.html")!
            )
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        index: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FireballSectionLabel(title: title, index: index)
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.fireballPanel,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.1))
            }
        }
    }

    private func settingsValue(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(value)
                .font(.body)
                .foregroundStyle(Color.fireballMuted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func settingsButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private func settingsLink(_ title: String, systemImage: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private func blockerBinding(_ profile: BrowserProfile) -> Binding<Bool> {
        Binding(
            get: { store.profiles.first(where: { $0.id == profile.id })?.blockerEnabled ?? false },
            set: { store.setBlockerEnabled($0, for: profile.id) }
        )
    }

    private func biometricBinding(_ profile: BrowserProfile) -> Binding<Bool> {
        Binding(
            get: { store.biometricLockEnabled(for: profile.id) },
            set: { enabled in
                Task { await store.setBiometricLockEnabled(enabled, for: profile.id) }
            }
        )
    }
}
