import SwiftUI
import WebKit

enum ShopWebDestination: String {
    case doing = "/orders?state=doing"
    case waiting = "/orders?state=waiting"
    case approvals = "/approvals?status=PENDING"
}

// The server handles sign-in, permissions and writes exactly as it does in Safari.
struct ShopWebScreen: View {
    @Environment(\.presentationMode) private var presentation
    @StateObject private var browser: ShopWebBrowser
    let theme: ThemePreset

    init(theme: ThemePreset, destination: ShopWebDestination? = nil) {
        self.theme = theme
        _browser = StateObject(wrappedValue: ShopWebBrowser(destination: destination))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { presentation.wrappedValue.dismiss() } label: {
                    Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Đóng"))
                Text("Nghiệp vụ").font(.headline).accessibilityAddTraits(.isHeader).frame(maxWidth: .infinity, alignment: .leading)
                Button { browser.webView.goBack() } label: {
                    Image(systemName: "chevron.backward").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Quay lại"))
                .disabled(!browser.canGoBack)
                Button { browser.goHome() } label: {
                    Image(systemName: "house").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Về trang chính"))
            }.padding(.horizontal)
                .foregroundColor(Color(argb: theme.ink.argb))
                .background(Color(argb: theme.surface.argb))
            Divider()
            if let message = browser.error {
                Text(message).font(.footnote).padding()
            }
            ShopWebView(browser: browser)
        }
        .accentColor(Color(argb: theme.focus.argb))
        .foregroundColor(Color(argb: theme.ink.argb))
        .background(Color(argb: theme.background.argb).ignoresSafeArea())
    }
}

private struct ShopWebView: UIViewRepresentable {
    let browser: ShopWebBrowser
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

private final class ShopWebBrowser: NSObject, ObservableObject, WKNavigationDelegate {
    private let home = URL(string: "https://app.barberpos-tiem.win/")!
    let webView: WKWebView
    @Published var error: String?
    @Published var canGoBack = false
    private var destination: ShopWebDestination?

    init(destination: ShopWebDestination?) {
        self.destination = destination
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.load(URLRequest(url: home))
    }

    func goHome() {
        error = nil
        destination = nil
        // Start a new GET rather than reloading a page that may come from a form submission.
        var request = URLRequest(url: home)
        request.httpMethod = "GET"
        webView.load(request)
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, url.scheme == home.scheme,
              url.host == home.host, url.port == nil || url.port == 443 else {
            error = "Chỉ mở được địa chỉ HTTPS của máy chủ BarberPOS."
            decisionHandler(.cancel)
            return
        }
        if action.targetFrame == nil, action.request.httpMethod == "GET" {
            webView.load(action.request)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        canGoBack = webView.canGoBack
        guard destination != nil, webView.url == home else { return }
        webView.evaluateJavaScript("Boolean(document.querySelector('nav.bottom-nav'))") { [weak self] result, _ in
            guard let self = self, (result as? Bool) == true,
                  webView.url == self.home, let destination = self.destination,
                  let url = URL(string: destination.rawValue, relativeTo: self.home)?.absoluteURL else { return }
            self.destination = nil
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse,
           http.statusCode >= 500 {
            error = "Máy chủ BarberPOS báo lỗi HTTP \(http.statusCode). Hãy thử lại sau."
        }
        if !response.canShowMIMEType {
            error = "Để tải tệp, hãy mở BarberPOS trong Safari."
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        error = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError failure: Error) {
        showFailure(failure)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError failure: Error) {
        showFailure(failure)
    }

    private func showFailure(_ failure: Error) {
        let failure = failure as NSError
        guard failure.domain != NSURLErrorDomain || failure.code != NSURLErrorCancelled else { return }
        error = "Không kết nối được máy chủ BarberPOS. Kiểm tra mạng và thử lại."
    }
}
