import SwiftUI

struct BrowserShellView: View {
    @State private var session = BrowserSession(
        profile: BrowserProfile(id: ProfileID(rawValue: "default"), storageMode: .persistent)
    )
    @State private var address = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.03).ignoresSafeArea()

            VStack(spacing: 0) {
                statusRail
                BrowserWebView(session: session)
                    .background(Color.black)
                bottomOmnibox
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if session.currentURL == nil {
                session.load(URL(string: "https://duckduckgo.com")!)
            }
        }
        .alert("Navigation blocked", isPresented: errorBinding) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The address is not allowed.")
        }
    }

    private var statusRail: some View {
        HStack(spacing: 12) {
            Text("FIREBALL")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .tracking(1.8)
            Rectangle().fill(Color.green).frame(width: 24, height: 2)
            Text(session.profile.storageMode == .ephemeral ? "PRIVATE / NONPERSISTENT" : "PROFILE / DEFAULT")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(session.isLoading ? "LOADING" : "READY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(session.isLoading ? Color.orange : Color.green)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(Color.black.opacity(0.72))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
    }

    private var bottomOmnibox: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                toolButton("chevron.left", enabled: session.canGoBack, action: session.goBack)
                toolButton("chevron.right", enabled: session.canGoForward, action: session.goForward)
                toolButton("arrow.clockwise", enabled: true, action: session.reload)

                TextField("Search or enter address", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(navigate)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.16)))

                Button(action: navigate) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.black)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 4))
                .accessibilityLabel("Go")
            }

            HStack {
                Label("ONE TAB", systemImage: "rectangle")
                Spacer()
                Text(session.pageTitle ?? session.currentURL?.host() ?? "NEW SESSION")
                    .lineLimit(1)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .onChange(of: session.currentURL) { _, newURL in
            if let newURL { address = newURL.absoluteString }
        }
    }

    private func toolButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 36, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.35))
    }

    private func navigate() {
        do {
            let url = try URLPolicy().resolve(address)
            session.load(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
