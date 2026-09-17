import AppKit
import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    enum State: Equatable {
        case starting
        case signedOut
        case waitingForLogin
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .starting
    @Published private(set) var account: AccountInfo?
    @Published private(set) var windows: [UsageWindow] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    private let client = CodexAppServerClient()
    private var refreshTimer: Timer?
    private var didStart = false

    init() {
        client.onNotification = { [weak self] method, params in
            self?.handleNotification(method: method, params: params)
        }
        Task { @MainActor [weak self] in
            self?.start()
        }
    }

    var menuBarTitle: String {
        "GPT \(menuBarPercentText)"
    }

    var menuBarPercentText: String {
        guard let preferred = preferredWindow else {
            switch state {
            case .signedOut: return "–"
            case .failed: return "!"
            default: return "…"
            }
        }
        return preferred.remainingPercentText
    }

    var preferredWindow: UsageWindow? {
        windows.first(where: { $0.limitID == "codex" && $0.kind == "primary" }) ?? windows.first
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        state = .starting

        client.start { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.loadAccount()
                self.installRefreshTimer()
            case .failure(let error):
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        client.request(method: "account/rateLimits/read", params: [:]) { [weak self] result in
            guard let self else { return }
            self.isRefreshing = false
            switch result {
            case .success(let response):
                let parsed = UsagePayloadParser.parseWindows(from: response)
                guard !parsed.isEmpty else {
                    self.state = .failed("Nessuna quota disponibile per questo account.")
                    return
                }
                self.windows = parsed
                self.lastUpdated = Date()
                self.state = .ready
            case .failure(let error):
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func login() {
        state = .waitingForLogin
        client.request(
            method: "account/login/start",
            params: [
                "type": "chatgpt",
                "useHostedLoginSuccessPage": true,
                "appBrand": "chatgpt"
            ]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                guard
                    let payload = response["result"] as? [String: Any],
                    let urlText = payload["authUrl"] as? String,
                    let url = URL(string: urlText)
                else {
                    self.state = .failed("Codex non ha restituito il collegamento per il login.")
                    return
                }
                NSWorkspace.shared.open(url)
            case .failure(let error):
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func logout() {
        client.request(method: "account/logout", params: [:]) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.account = nil
                self.windows = []
                self.lastUpdated = nil
                self.state = .signedOut
            case .failure(let error):
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    private func loadAccount() {
        client.request(
            method: "account/read",
            params: ["refreshToken": false]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.account = UsagePayloadParser.parseAccount(from: response)
                if self.account == nil, UsagePayloadParser.requiresOpenAIAuth(from: response) {
                    self.windows = []
                    self.state = .signedOut
                } else {
                    self.refresh()
                }
            case .failure(let error):
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    private func installRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refreshTimer?.tolerance = 30
    }

    private func handleNotification(method: String, params: [String: Any]) {
        switch method {
        case "account/login/completed":
            if params["success"] as? Bool == true {
                state = .starting
                loadAccount()
            } else {
                state = .failed(params["error"] as? String ?? "Accesso a ChatGPT non riuscito.")
            }
        case "account/updated":
            loadAccount()
        case "account/rateLimits/updated":
            refresh()
        default:
            break
        }
    }
}
