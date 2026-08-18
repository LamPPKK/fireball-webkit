import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    let session: BrowserSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> WKWebView {
        session.webView.navigationDelegate = context.coordinator
        return session.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
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
            session.synchronize()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
            session.synchronize()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            URLPolicy().allowsNavigation(to: navigationAction.request.url) ? .allow : .cancel
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url,
               URLPolicy().allowsNavigation(to: url) {
                session.load(url)
            }
            return nil
        }
    }
}
