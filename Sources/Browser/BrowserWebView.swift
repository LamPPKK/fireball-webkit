import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    let session: BrowserSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> WKWebView {
        session.webView.navigationDelegate = context.coordinator
        session.webView.uiDelegate = context.coordinator
        return session.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let session: BrowserSession

        init(session: BrowserSession) {
            self.session = session
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            session.synchronize()
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
            session.synchronize()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            session.navigationDidFinish()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
            session.synchronize()
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: any Error
        ) {
            session.synchronize()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
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
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                switch URLPolicy(searchProvider: session.profile.searchProvider).disposition(for: url) {
                case .web:
                    session.onOpenNewTab?(url)
                case .externalConfirmation:
                    session.onExternalURL?(url)
                case .blocked:
                    break
                }
            }
            return nil
        }
    }
}
