import SwiftUI
import WebKit

/// Observes only when the visible document changes; no private state or
/// network traffic is intercepted. The handler holds the browser weakly.
final class BrasaDOMEventProxy: NSObject, WKScriptMessageHandler {
    weak var browser: BrasaBrowser?
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name=="brasaVisibleDOMChanged", message.frameInfo.isMainFrame else {return}
        DispatchQueue.main.async { [weak self] in
            self?.browser?.domRevision += 1
        }
    }
}

@MainActor
final class BrasaBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var isLoading = true
    @Published var errorText: String?
    @Published var pageTitle = "Brasa Poker"
    @Published var domRevision = 0

    let webView: WKWebView
    private static let home = URL(string: "https://brasa.poker/")!

    override init() {
        let configuration = WKWebViewConfiguration()
        // Trigger a low-payload notification when visible DOM nodes are updated.
        // The full card extraction is still performed separately by CardScanner.
        let eventProxy=BrasaDOMEventProxy()
        let watchScript = #"""
        (() => {
          if(window.__brasaAssistenObserver || !document.documentElement)return;
          let timeout=null;
          const announce=()=>{
            try {window.webkit.messageHandlers.brasaVisibleDOMChanged.postMessage(1)}catch(_){}
          };
          const observer=new MutationObserver(()=>{
            if(timeout)clearTimeout(timeout);
            timeout=setTimeout(announce,180);
          });
          observer.observe(document.documentElement,{
            subtree:true,childList:true,characterData:true,attributes:true,
            attributeFilter:['class','style','aria-label']
          });
          window.__brasaAssistenObserver=observer;
          announce();
        })();
        """#
        configuration.userContentController.add(eventProxy,name:"brasaVisibleDOMChanged")
        configuration.userContentController.addUserScript(
            WKUserScript(source:watchScript,injectionTime:.atDocumentEnd,forMainFrameOnly:true))
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        eventProxy.browser=self
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
