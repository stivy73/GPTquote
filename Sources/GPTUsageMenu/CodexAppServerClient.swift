import AppKit
import Foundation

final class CodexAppServerClient {
    enum ClientError: LocalizedError {
        case codexNotFound
        case notRunning
        case invalidResponse
        case server(String)
        case processExited(String)

        var errorDescription: String? {
            switch self {
            case .codexNotFound:
                return "Codex non è stato trovato. Installa o aggiorna l’app ChatGPT per macOS."
            case .notRunning:
                return "Il servizio locale Codex non è attivo."
            case .invalidResponse:
                return "Codex ha restituito una risposta non valida."
            case .server(let message):
                return message
            case .processExited(let message):
                return message.isEmpty ? "Il servizio locale Codex si è chiuso." : message
            }
        }
    }

    typealias Response = [String: Any]
    typealias Completion = (Result<Response, Error>) -> Void

    var onNotification: ((String, [String: Any]) -> Void)?

    private let queue = DispatchQueue(label: "it.stivy.GPTUsageMenu.codex-client")
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputBuffer = Data()
    private var errorBuffer = Data()
    private var pending: [Int: Completion] = [:]
    private var nextID = 1
    private var startCompletions: [(Result<Void, Error>) -> Void] = []
    private var isInitialized = false

    func start(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            if self.isInitialized, self.process?.isRunning == true {
                DispatchQueue.main.async { completion(.success(())) }
                return
            }

            self.startCompletions.append(completion)
            guard self.process == nil else { return }

            do {
                try self.launchProcess()
                self.sendRequestOnQueue(
                    method: "initialize",
                    params: [
                        "clientInfo": [
                            "name": "gpt_usage_menu",
                            "title": "GPT Usage Menu",
                            "version": "0.1.0"
                        ]
                    ]
                ) { result in
                    self.queue.async {
                        switch result {
                        case .success:
                            self.sendNotificationOnQueue(method: "initialized", params: [:])
                            self.isInitialized = true
                            self.finishStarting(with: .success(()))
                        case .failure(let error):
                            self.finishStarting(with: .failure(error))
                        }
                    }
                }
            } catch {
                self.finishStarting(with: .failure(error))
            }
        }
    }

    func request(method: String, params: [String: Any], completion: @escaping Completion) {
        queue.async {
            guard self.isInitialized, self.process?.isRunning == true else {
                DispatchQueue.main.async { completion(.failure(ClientError.notRunning)) }
                return
            }
            self.sendRequestOnQueue(method: method, params: params, completion: completion)
        }
    }

    func stop() {
        queue.async {
            self.process?.terminate()
            self.process = nil
            self.inputPipe = nil
            self.isInitialized = false
        }
    }

    private func launchProcess() throws {
        guard let executableURL = Self.findCodexExecutable() else {
            throw ClientError.codexNotFound
        }

        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("GPT Usage Menu/Codex", isDirectory: true)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()

        process.executableURL = executableURL
        process.arguments = [
            "app-server",
            "--stdio",
            "-c", "cli_auth_credentials_store=\"keyring\""
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = supportURL.path
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.consumeOutput(data) }
        }
        errors.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.appendError(data) }
        }
        process.terminationHandler = { [weak self] process in
            self?.queue.async { self?.handleTermination(status: process.terminationStatus) }
        }

        try process.run()
        self.process = process
        inputPipe = input
    }

    private func sendRequestOnQueue(method: String, params: [String: Any], completion: @escaping Completion) {
        let id = nextID
        nextID += 1
        pending[id] = completion
        writeJSON(["method": method, "id": id, "params": params])
    }

    private func sendNotificationOnQueue(method: String, params: [String: Any]) {
        writeJSON(["method": method, "params": params])
    }

    private func writeJSON(_ message: [String: Any]) {
        guard
            let inputPipe,
            JSONSerialization.isValidJSONObject(message),
            var data = try? JSONSerialization.data(withJSONObject: message)
        else {
            return
        }
        data.append(0x0A)
        inputPipe.fileHandleForWriting.write(data)
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)

        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newline]
            outputBuffer.removeSubrange(...newline)
            guard
                !line.isEmpty,
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let message = object as? [String: Any]
            else {
                continue
            }
            handleMessage(message)
        }
    }

    private func handleMessage(_ message: [String: Any]) {
        if let id = (message["id"] as? NSNumber)?.intValue, let completion = pending.removeValue(forKey: id) {
            if let error = message["error"] as? [String: Any] {
                let text = error["message"] as? String ?? "Errore restituito da Codex."
                DispatchQueue.main.async { completion(.failure(ClientError.server(text))) }
            } else {
                DispatchQueue.main.async { completion(.success(message)) }
            }
            return
        }

        if let method = message["method"] as? String {
            let params = message["params"] as? [String: Any] ?? [:]
            DispatchQueue.main.async { [weak self] in
                self?.onNotification?(method, params)
            }
        }
    }

    private func appendError(_ data: Data) {
        errorBuffer.append(data)
        if errorBuffer.count > 16_384 {
            errorBuffer.removeFirst(errorBuffer.count - 16_384)
        }
    }

    private func handleTermination(status: Int32) {
        let details = String(data: errorBuffer, encoding: .utf8)?
            .split(separator: "\n")
            .last
            .map(String.init) ?? ""
        let error = ClientError.processExited(details)
        let completions = pending.values
        pending.removeAll()
        process = nil
        inputPipe = nil
        isInitialized = false

        DispatchQueue.main.async {
            completions.forEach { $0(.failure(error)) }
        }

        if !startCompletions.isEmpty {
            finishStarting(with: .failure(error))
        }
    }

    private func finishStarting(with result: Result<Void, Error>) {
        let completions = startCompletions
        startCompletions.removeAll()
        DispatchQueue.main.async {
            completions.forEach { $0(result) }
        }
    }

    private static func findCodexExecutable() -> URL? {
        var candidates: [String] = []
        if let override = ProcessInfo.processInfo.environment["CODEX_EXECUTABLE"], !override.isEmpty {
            candidates.append(override)
        }
        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])

        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }
}
