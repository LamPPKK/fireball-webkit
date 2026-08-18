import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    let session: BrowserSession

    func makeUIView(context: Context) -> WKWebView {
        session.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
