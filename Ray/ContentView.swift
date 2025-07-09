import SwiftUI
import WebKit

class BrowserTab: NSObject, ObservableObject, Identifiable {

    let id = UUID()
    let webView = WKWebView()
    var url: URL
    var updateSearchText: ((String) -> Void)?

    @Published var title: String = "New Tab"
    @Published var favicon: UIImage?
    @Published var loadingProgress: Double = 0.0

    init(url: URL, updateSearchText: ((String) -> Void)? = nil) {
        self.url = url
        self.updateSearchText = updateSearchText
        super.init()
        setupObservers()
        webView.load(URLRequest(url: url))
    }

    private func setupObservers() {
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
    }

    deinit {
        webView.removeObserver(self, forKeyPath: "title")
        webView.removeObserver(self, forKeyPath: "URL")
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "title" {
            DispatchQueue.main.async {
                self.title = self.webView.title ?? "New Tab"
            }
        } else if keyPath == "URL" {
            DispatchQueue.main.async {
                self.title = self.webView.title ?? "New Tab"
                self.updateSearchText?(self.webView.url?.absoluteString ?? "")
            }
            fetchFavicon()
        } else if keyPath == "estimatedProgress" {
            DispatchQueue.main.async {
                self.loadingProgress = self.webView.estimatedProgress
            }
        }
    }

    private func fetchFavicon() {
        guard let host = webView.url?.host,
              let faviconURL = URL(string: "https://\(host)/favicon.ico") else { return }

        URLSession.shared.dataTask(with: faviconURL) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.favicon = image
                }
            }
        }.resume()
    }
}

struct ContentView: View {
    @State private var tabs: [BrowserTab] = {
        let firstTab = BrowserTab(url: URL(string: "https://duckduckgo.com")!)
        return [firstTab]
    }()

    @State private var selectedTabID: UUID = {
        let firstTab = BrowserTab(url: URL(string: "https://duckduckgo.com")!)
        return firstTab.id
    }()
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(tabs) { tab in
                                HStack {
                                    if let icon = tab.favicon {
                                        Image(uiImage: icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                            .cornerRadius(3)
                                    }

                                    Text(tab.title)
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    if tab.loadingProgress < 1.0 {
                                        ZStack {
                                            Circle()
                                                .stroke(lineWidth: 2)
                                                .foregroundColor(.white.opacity(0.3))
                                                .frame(width: 14, height: 14)

                                            Circle()
                                                .trim(from: 0, to: tab.loadingProgress)
                                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                                .rotationEffect(.degrees(-90))
                                                .foregroundColor(.white)
                                                .frame(width: 14, height: 14)
                                        }
                                    }

                                    Spacer()

                                    Button(action: {
                                        closeTab(tab.id)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(tab.id == selectedTabID ? Color("BlueG") : Color("BlueG").opacity(0.6))
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                .onTapGesture {
                                    selectedTabID = tab.id
                                }
                            }
                        }
                        .padding()
                    }
                    Spacer()
                }
                .frame(width: 220)
                .background(Color("BlueG").opacity(0.3))
                .cornerRadius(20)
                .padding()

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        TextField("Anything...", text: $searchText, onCommit: {
                            loadSearchOrURL()
                        })
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color("BlueG"))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .padding(.vertical, 12)

                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .padding(12)
                                .background(Color("BlueG"))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }

                        Button(action: goForward) {
                            Image(systemName: "chevron.right")
                                .padding(12)
                                .background(Color("BlueG"))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }

                        Button(action: addNewTab) {
                            Image(systemName: "plus")
                                .padding(.all, 12)
                                .background(Color("BlueG"))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 0)
                    }

                    if let selectedTab = tabs.first(where: { $0.id == selectedTabID }) {
                        WebViewWrapper(webView: selectedTab.webView)
                            .id(selectedTab.id)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .onChange(of: selectedTabID) { newValue in
                                if let selectedTab = tabs.first(where: { $0.id == newValue }) {
                                    searchText = selectedTab.webView.url?.absoluteString ?? ""
                                }
                            }
                            .onAppear {
                                if selectedTab.webView.url == nil {
                                    selectedTab.webView.load(URLRequest(url: selectedTab.url))
                                }
                                searchText = selectedTab.webView.url?.absoluteString ?? ""
                            }
                    } else {
                        Text("No tab selected")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    

    func addNewTab() {
        let newTab = BrowserTab(url: URL(string: "https://duckduckgo.com")!) {
            self.searchText = $0
        }
        tabs.append(newTab)
        selectedTabID = newTab.id
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if let first = tabs.first {
            selectedTabID = first.id
        }
    }

    func loadSearchOrURL() {
        if selectedTabID == UUID(), tabs.isEmpty {
            let url = URL(string: "https://www.duckduckgo.com/search?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            let newTab = BrowserTab(url: url) {
                self.searchText = $0
            }
            tabs.append(newTab)
            selectedTabID = newTab.id
            return
        }
        guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        let webView = tabs[index].webView
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to detect if it's a valid URL without scheme
        if text.contains(".") && !text.contains(" ") {
            var urlString = text
            if !text.starts(with: "http://") && !text.starts(with: "https://") {
                urlString = "https://\(text)"
            }
            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
                searchText = url.absoluteString
                return
            }
        }

        // Otherwise, treat it as a search
        if let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.duckduckgo.com/search?q=\(query)") {
            webView.load(URLRequest(url: url))
            searchText = url.absoluteString
        }
    }

    func goBack() {
        if let tab = tabs.first(where: { $0.id == selectedTabID }),
           tab.webView.canGoBack {
            tab.webView.goBack()
        }
    }

    func goForward() {
        if let tab = tabs.first(where: { $0.id == selectedTabID }),
           tab.webView.canGoForward {
            tab.webView.goForward()
        }
    }
}


#Preview {
    ContentView()
}
