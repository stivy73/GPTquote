import AppKit
import SwiftUI

private enum MenuBarChatGPTIcon {
    static let image: NSImage = {
        let fallback = NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "ChatGPT")!
        guard
            let url = Bundle.main.url(forResource: "MenuBarChatGPT", withExtension: "png"),
            let source = NSImage(contentsOf: url)
        else {
            fallback.isTemplate = true
            return fallback
        }

        let image = NSImage(size: NSSize(width: 22, height: 22))
        image.lockFocus()
        source.draw(in: NSRect(x: 0, y: 0, width: 22, height: 22))
        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}

private enum ArchetipiDigitaliLogo {
    static let image: NSImage = {
        let fallback = NSImage(systemSymbolName: "building.2", accessibilityDescription: "Archetipi Digitali")!
        guard
            let url = Bundle.main.url(forResource: "ArchetipiDigitaliLogo", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return fallback
        }
        return image
    }()
}

@main
struct GPTUsageMenuApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(store: store)
                .frame(width: 330)
        } label: {
            HStack(spacing: 3) {
                Image(nsImage: MenuBarChatGPTIcon.image)
                    .renderingMode(.template)
                Text(store.menuBarPercentText)
                    .monospacedDigit()
            }
            .accessibilityLabel(store.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct UsageMenuView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            content

            Divider()

            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("GPTquote")
                    .font(.headline)
                if let account = store.account, !account.subtitle.isEmpty {
                    Text(account.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Quote ChatGPT e Codex")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://www.archetipi-digitali.it")!) {
                    Image(nsImage: ArchetipiDigitaliLogo.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 46)
                }
                .buttonStyle(.plain)
                .help("Visita archetipi-digitali.it")
                .accessibilityLabel("Visita il sito Archetipi Digitali")

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .starting:
            statusRow(text: "Connessione a Codex…", showsProgress: true)

        case .signedOut:
            VStack(alignment: .leading, spacing: 12) {
                Text("Collega il tuo account ChatGPT per leggere le quote disponibili.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Accedi con ChatGPT") {
                    store.login()
                }
                .buttonStyle(.borderedProminent)
            }

        case .waitingForLogin:
            VStack(alignment: .leading, spacing: 10) {
                statusRow(text: "Completa l’accesso nel browser…", showsProgress: true)
                Button("Riapri il login") {
                    store.login()
                }
                .buttonStyle(.link)
            }

        case .ready:
            VStack(spacing: 10) {
                ForEach(store.windows) { window in
                    UsageWindowRow(window: window)
                }
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label("Impossibile aggiornare", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Riprova") { store.refresh() }
                    if store.account == nil {
                        Button("Accedi") { store.login() }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let date = store.lastUpdated {
                Text("Aggiornato \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if store.account != nil {
                Button("Disconnetti") { store.logout() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.account == nil || store.isRefreshing)
            .help("Aggiorna")

            Button("Esci") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
    }

    private func statusRow(text: String, showsProgress: Bool) -> some View {
        HStack(spacing: 10) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct UsageWindowRow: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(window.remainingPercentText) rimasto")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            ProgressView(value: window.remainingPercent, total: 100)
                .tint(progressColor)

            if let resetText = window.resetText {
                Text(resetText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(11)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private var progressColor: Color {
        switch window.remainingPercent {
        case 0..<20: return .red
        case 20..<40: return .orange
        default: return .accentColor
        }
    }
}
