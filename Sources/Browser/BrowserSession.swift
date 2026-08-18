import Observation
import WebKit

@MainActor
@Observable
final class BrowserSession {
    let tabID: TabID
    let profile: BrowserProfile
    let webView: WKWebView
    var currentURL: URL?
    var pageTitle: String?
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var estimatedProgress = 0.0

    @ObservationIgnored var onStateChange: ((BrowserSession) -> Void)?
    @ObservationIgnored var onNavigationFinished: ((BrowserSession) -> Void)?
    @ObservationIgnored var onOpenNewTab: ((URL) -> Void)?
    @ObservationIgnored var onExternalURL: ((URL) -> Void)?

    init(
        tabID: TabID,
        profile: BrowserProfile,
        dataStore: WKWebsiteDataStore,
        contentRules: [WKContentRuleList] = []
    ) {
        self.tabID = tabID
        self.profile = profile
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        if profile.blockerEnabled {
            for rule in contentRules {
                configuration.userContentController.add(rule)
            }
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
    }

    func load(_ url: URL) {
        let policy: URLRequest.CachePolicy = profile.storageMode == .ephemeral
            ? .reloadIgnoringLocalCacheData
            : .useProtocolCachePolicy
        webView.load(URLRequest(url: url, cachePolicy: policy))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
    func stopLoading() { webView.stopLoading() }

    func synchronize() {
        currentURL = webView.url
        pageTitle = webView.title
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        estimatedProgress = webView.estimatedProgress
        onStateChange?(self)
    }

    func navigationDidFinish() {
        synchronize()
        onNavigationFinished?(self)
    }
}
