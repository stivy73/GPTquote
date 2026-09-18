import AppKit
import SwiftUI

private enum MenuBarIndicatorStyle: String {
    case percentage
    case gauge
}

private enum GaugeColorMode: String {
    case trafficLight
    case monochrome
}

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

private enum MenuBarGaugeIcon {
    static func image(remainingPercent: Double?, colorMode: GaugeColorMode) -> NSImage {
        guard let remainingPercent else {
            let fallback = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Utilizzo non disponibile")!
            fallback.isTemplate = true
            return fallback
        }

        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let center = CGPoint(x: 11, y: 10)
        let radius: CGFloat = 8
        let lineWidth: CGFloat = 2.3
        let lower = Double.pi
        let upper = 0.0

        context.setLineCap(.round)
        context.setLineWidth(lineWidth)

        if colorMode == .trafficLight {
            drawArc(context, center: center, radius: radius, start: lower, end: 2 * .pi / 3, color: .systemRed)
            drawArc(context, center: center, radius: radius, start: 2 * .pi / 3 - 0.06, end: .pi / 3, color: .systemYellow)
            drawArc(context, center: center, radius: radius, start: .pi / 3 - 0.06, end: upper, color: .systemGreen)
        } else {
            drawArc(context, center: center, radius: radius, start: lower, end: upper, color: .labelColor)
        }

        let value = min(100, max(0, remainingPercent)) / 100
        let angle = lower + (upper - lower) * value
        let needleLength = radius - 2.5
        let endpoint = CGPoint(
            x: center.x + cos(angle) * needleLength,
            y: center.y + sin(angle) * needleLength
        )
        let needleColor = colorMode == .trafficLight ? statusColor(for: remainingPercent) : .labelColor

        context.setStrokeColor(needleColor.cgColor)
        context.setLineWidth(1.8)
        context.move(to: center)
        context.addLine(to: endpoint)
        context.strokePath()
        context.setFillColor(needleColor.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 1.8, y: center.y - 1.8, width: 3.6, height: 3.6))

        image.unlockFocus()
        image.isTemplate = colorMode == .monochrome
        return image
    }

    private static func drawArc(
        _ context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        start: Double,
        end: Double,
        color: NSColor
    ) {
        context.setStrokeColor(color.cgColor)
        context.addArc(
            center: center,
            radius: radius,
            startAngle: CGFloat(start),
            endAngle: CGFloat(end),
            clockwise: true
        )
        context.strokePath()
    }

    private static func statusColor(for remainingPercent: Double) -> NSColor {
        switch remainingPercent {
        case 0..<20: return .systemRed
        case 20..<50: return .systemYellow
        default: return .systemGreen
        }
    }
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
    @AppStorage("menuBarIndicatorStyle") private var menuBarIndicatorStyle = MenuBarIndicatorStyle.percentage.rawValue
    @AppStorage("menuBarGaugeColorMode") private var menuBarGaugeColorMode = GaugeColorMode.trafficLight.rawValue

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(store: store)
                .frame(width: 330)
        } label: {
            HStack(spacing: 3) {
                Image(nsImage: MenuBarChatGPTIcon.image)
                    .renderingMode(.template)
                if indicatorStyle == .percentage {
                    Text(store.menuBarPercentText)
                        .monospacedDigit()
                } else {
                    Image(nsImage: MenuBarGaugeIcon.image(
                        remainingPercent: store.preferredWindow?.remainingPercent,
                        colorMode: gaugeColorMode
                    ))
                    .renderingMode(gaugeColorMode == .monochrome ? .template : .original)
                }
            }
            .accessibilityLabel(store.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }

    private var indicatorStyle: MenuBarIndicatorStyle {
        MenuBarIndicatorStyle(rawValue: menuBarIndicatorStyle) ?? .percentage
    }

    private var gaugeColorMode: GaugeColorMode {
        GaugeColorMode(rawValue: menuBarGaugeColorMode) ?? .trafficLight
    }
}

private struct UsageMenuView: View {
    @ObservedObject var store: UsageStore
    @AppStorage("menuBarIndicatorStyle") private var menuBarIndicatorStyle = MenuBarIndicatorStyle.percentage.rawValue
    @AppStorage("menuBarGaugeColorMode") private var menuBarGaugeColorMode = GaugeColorMode.trafficLight.rawValue

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

            Menu {
                Picker("Nel menu", selection: $menuBarIndicatorStyle) {
                    Text("Percentuale precisa").tag(MenuBarIndicatorStyle.percentage.rawValue)
                    Text("Lancetta").tag(MenuBarIndicatorStyle.gauge.rawValue)
                }

                if indicatorStyle == .gauge {
                    Divider()

                    Picker("Colori lancetta", selection: $menuBarGaugeColorMode) {
                        Text("Verde, giallo, rosso").tag(GaugeColorMode.trafficLight.rawValue)
                        Text("Monocromatica").tag(GaugeColorMode.monochrome.rawValue)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .help("Aspetto dell’indicatore nel menu")

            Button("Esci") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
    }

    private var indicatorStyle: MenuBarIndicatorStyle {
        MenuBarIndicatorStyle(rawValue: menuBarIndicatorStyle) ?? .percentage
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
