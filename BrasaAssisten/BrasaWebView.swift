import SwiftUI
import WebKit

@MainActor
final class BrasaBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var isLoading = true
    @Published var errorText: String?
    @Published var pageTitle = "Brasa Poker"

    let webView: WKWebView
    private static let home = URL(string: "https://brasa.poker/")!

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        openHome()
    }

    func openHome() {
        errorText = nil
        webView.load(URLRequest(url: Self.home, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 25))
    }
    func reload() { errorText = nil; webView.reload() }
    func back() {
        if webView.canGoBack { webView.goBack() }
        else { openHome() }
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorText = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        pageTitle = webView.title ?? "Brasa Poker"
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        if (error as NSError).code != NSURLErrorCancelled { errorText = error.localizedDescription }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        if (error as NSError).code != NSURLErrorCancelled { errorText = error.localizedDescription }
    }
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

struct BrowserView: UIViewRepresentable {
    @ObservedObject var browser: BrasaBrowser
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
