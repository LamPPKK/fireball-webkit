import SwiftUI

struct SettingsView: View {
    @Bindable var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHistoryConsent = false
    @State private var showDeleteProfile = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                privacySection
                syncSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.fireballBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
        Section("Active profile") {
            if let profile = store.activeProfile {
                LabeledContent("Name", value: profile.name)
                LabeledContent("Storage", value: profile.storageMode == .persistent ? "Persistent / isolated" : "Private / memory")

                Picker("Search engine", selection: searchProviderBinding(profile)) {
                    ForEach(SearchProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .disabled(profile.storageMode == .ephemeral)

                if profile.storageMode == .persistent && store.regularProfiles.count > 1 {
                    Button("Delete profile", role: .destructive) { showDeleteProfile = true }
                }
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            if let profile = store.activeProfile {
                Toggle("Content blocker", isOn: blockerBinding(profile))
                    .disabled(profile.storageMode == .ephemeral)
                LabeledContent("Rules", value: store.blockerStatus)
                Button("Check for rule updates") {
                    Task { await store.refreshBlockerRules() }
                }

                if profile.storageMode == .persistent {
                    Toggle("Require biometrics", isOn: biometricBinding(profile))
                }
            }
            LabeledContent("Private tabs", value: "Never restored")
            LabeledContent("Telemetry", value: "None")
        }
    }

    private var syncSection: some View {
        Section("iCloud private database") {
            LabeledContent("Status", value: store.syncStatus.label)
            Text(store.syncStatus.detail)
                .font(.caption)
                .foregroundStyle(Color.fireballMuted)
            Button(store.settings.historySyncEnabled ? "Disable history sync" : "Enable history sync") {
                if store.settings.historySyncEnabled {
                    store.setHistorySyncEnabled(false)
                } else {
                    showHistoryConsent = true
                }
            }
            Text("Profiles, spaces, regular tabs and bookmarks sync when iCloud is available. History is opt-in and retained for 90 days.")
                .font(.caption)
                .foregroundStyle(Color.fireballMuted)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Application", value: "Fireball Browser")
            LabeledContent("Version", value: "0.1.0")
            Link("Privacy policy", destination: URL(string: "https://lamppkk.github.io/fireball-webkit/privacy.html")!)
            Link("Support", destination: URL(string: "https://lamppkk.github.io/fireball-webkit/support.html")!)
        }
    }

    private func searchProviderBinding(_ profile: BrowserProfile) -> Binding<SearchProvider> {
        Binding(
            get: { store.profiles.first(where: { $0.id == profile.id })?.searchProvider ?? .brave },
            set: { store.updateSearchProvider($0, for: profile.id) }
        )
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
