import Observation
import WebKit

@MainActor
@Observable
final class BrowserSession {
    let tabID: TabID
    private(set) var profile: BrowserProfile
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
    @ObservationIgnored private var pendingContentRules: [WKContentRuleList]?

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

    var hasPendingPolicyChange: Bool {
        pendingContentRules != nil
    }

    func stagePolicy(profile: BrowserProfile, contentRules: [WKContentRuleList]) {
        guard profile.id == self.profile.id else { return }
        self.profile = profile
        pendingContentRules = profile.blockerEnabled ? contentRules : []
    }

    func applyPendingPolicy() {
        guard let pendingContentRules else { return }
        webView.configuration.userContentController.removeAllContentRuleLists()
        for rule in pendingContentRules {
            webView.configuration.userContentController.add(rule)
        }
        self.pendingContentRules = nil
    }

    func load(_ url: URL) {
        applyPendingPolicy()
        let policy: URLRequest.CachePolicy = profile.storageMode == .ephemeral
            ? .reloadIgnoringLocalCacheData
            : .useProtocolCachePolicy
        webView.load(URLRequest(url: url, cachePolicy: policy))
    }

    func goBack() {
        applyPendingPolicy()
        webView.goBack()
    }

    func goForward() {
        applyPendingPolicy()
        webView.goForward()
    }

    func reload() {
        applyPendingPolicy()
        webView.reload()
    }
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
