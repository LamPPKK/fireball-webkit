import Observation
import WebKit

@MainActor
@Observable
final class BrowserSession {
    let profile: BrowserProfile
    let webView: WKWebView
    var currentURL: URL?
    var pageTitle: String?
    var canGoBack = false
    var canGoForward = false
    var isLoading = false

    init(profile: BrowserProfile) {
        self.profile = profile
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = profile.storageMode == .ephemeral ? .nonPersistent() : .default()
        configuration.preferences.isElementFullscreenEnabled = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url, cachePolicy: profile.storageMode == .ephemeral ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    func synchronize() {
        currentURL = webView.url
        pageTitle = webView.title
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
    }
}
