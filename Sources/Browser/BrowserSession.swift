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
    @ObservationIgnored var onWebContentProcessTerminated: ((BrowserSession) -> Void)?
    @ObservationIgnored var onDownloadStarted: ((WKDownload, DownloadID?) -> Void)?
    @ObservationIgnored private var pendingContentRules: [WKContentRuleList]?
    @ObservationIgnored private var recoveryPolicy = WebContentProcessRecoveryPolicy()
    @ObservationIgnored private var webViewDelegate: BrowserSessionWebViewDelegate?

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
        let delegate = BrowserSessionWebViewDelegate(session: self)
        webViewDelegate = delegate
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate
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
        currentURL = url
        recoveryPolicy.userRequestedReload()
        loadRequest(url)
    }

    private func loadRequest(_ url: URL) {
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
        recoveryPolicy.userRequestedReload()
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
        recoveryPolicy.navigationDidFinish()
        synchronize()
        onNavigationFinished?(self)
    }

    func webContentProcessDidTerminate() {
        onWebContentProcessTerminated?(self)
    }

    func beginDownload(_ download: WKDownload, resuming id: DownloadID? = nil) {
        onDownloadStarted?(download, id)
    }

    func resumeDownload(from data: Data, id: DownloadID) {
        webView.resumeDownload(fromResumeData: data) { [weak self] download in
            self?.beginDownload(download, resuming: id)
        }
    }

    func recoverFromWebContentProcessTermination(isActive: Bool) -> WebContentProcessRecoveryDecision {
        let candidate = webView.url ?? currentURL
        let isRestorable = candidate.map {
            URLPolicy(searchProvider: profile.searchProvider).allowsNavigation(to: $0)
        } ?? false
        let decision = recoveryPolicy.decision(isActive: isActive, hasRestorableURL: isRestorable)

        switch decision {
        case .reload:
            if let candidate {
                loadRequest(candidate)
            }
        case .discard, .reportFailure:
            stopLoading()
            isLoading = false
            onStateChange?(self)
        }
        return decision
    }
}

@MainActor
private final class BrowserSessionWebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    private weak var session: BrowserSession?

    init(session: BrowserSession) {
        self.session = session
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        session?.synchronize()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
        session?.synchronize()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        session?.navigationDidFinish()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
        session?.synchronize()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: any Error
    ) {
        session?.synchronize()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        session?.webContentProcessDidTerminate()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let session else { return .cancel }
        if navigationAction.shouldPerformDownload,
           BrowserDownloadResponsePolicy.allowsDownloadURL(navigationAction.request.url) {
            session.applyPendingPolicy()
            return .download
        }
        switch URLPolicy(searchProvider: session.profile.searchProvider)
            .disposition(for: navigationAction.request.url) {
        case .web:
            session.applyPendingPolicy()
            return .allow
        case .externalConfirmation:
            if let url = navigationAction.request.url {
                session.onExternalURL?(url)
            }
            return .cancel
        case .blocked:
            return .cancel
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        guard let session,
              URLPolicy(searchProvider: session.profile.searchProvider)
                .allowsNavigation(to: navigationResponse.response.url) else {
            return .cancel
        }
        let disposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?
            .lowercased()
        return BrowserDownloadResponsePolicy.shouldDownload(
            canShowMIMEType: navigationResponse.canShowMIMEType,
            contentDisposition: disposition
        ) ? .download : .allow
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        session?.beginDownload(download)
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        session?.beginDownload(download)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let session,
              navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else { return nil }
        switch URLPolicy(searchProvider: session.profile.searchProvider).disposition(for: url) {
        case .web:
            session.onOpenNewTab?(url)
        case .externalConfirmation:
            session.onExternalURL?(url)
        case .blocked:
            break
        }
        return nil
    }
}
