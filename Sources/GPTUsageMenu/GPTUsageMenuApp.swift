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

private enum UsageIndicatorColor {
    static func nsColor(for remainingPercent: Double) -> NSColor {
        switch remainingPercent {
        case ..<34: return .systemRed
        case ..<67: return .systemYellow
        default: return .systemGreen
        }
    }

    static func swiftUIColor(for remainingPercent: Double) -> Color {
        Color(nsColor: nsColor(for: remainingPercent))
    }
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

        let size = NSSize(width: 24, height: 20)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: 12, y: 5)
            let radius: CGFloat = 9
            let lower = Double.pi
            let upper = 0.0

            context.setLineCap(.round)
            context.setLineWidth(2.5)

            if colorMode == .trafficLight {
                drawArc(context, center: center, radius: radius, start: lower, end: 2 * .pi / 3, color: .systemRed)
                drawArc(context, center: center, radius: radius, start: 2 * .pi / 3 - 0.06, end: .pi / 3, color: .systemYellow)
                drawArc(context, center: center, radius: radius, start: .pi / 3 - 0.06, end: upper, color: .systemGreen)
            } else {
                drawArc(context, center: center, radius: radius, start: lower, end: upper, color: .labelColor)
            }

            // 0% sits at the left end of the dial; 100% sits at the right end.
            let value = min(100, max(0, remainingPercent)) / 100
            let angle = lower + (upper - lower) * value
            let needleLength = radius - 2
            let endpoint = CGPoint(
                x: center.x + cos(angle) * needleLength,
                y: center.y + sin(angle) * needleLength
            )
            let needleColor = colorMode == .trafficLight ? UsageIndicatorColor.nsColor(for: remainingPercent) : .labelColor

            context.setStrokeColor(needleColor.cgColor)
            context.setLineWidth(2)
            context.move(to: center)
            context.addLine(to: endpoint)
            context.strokePath()
            context.setFillColor(needleColor.cgColor)
            context.fillEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
            return true
        }
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

}

private enum MenuBarPercentIcon {
    static func image(text: String, remainingPercent: Double) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UsageIndicatorColor.nsColor(for: remainingPercent)
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let size = NSSize(width: ceil(textSize.width), height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            let origin = NSPoint(
                x: 0,
                y: floor((rect.height - textSize.height) / 2) + 1
            )
            (text as NSString).draw(at: origin, withAttributes: attributes)
            return true
        }
        image.isTemplate = false
        return image
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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var store = UsageStore()
    @AppStorage("menuBarIndicatorStyle") private var menuBarIndicatorStyle = MenuBarIndicatorStyle.percentage.rawValue
    @AppStorage("menuBarGaugeColorMode") private var menuBarGaugeColorMode = GaugeColorMode.trafficLight.rawValue

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(store: store)
                .frame(width: 330)
        } label: {
            Image(nsImage: statusImage)
            .renderingMode(gaugeColorMode == .monochrome ? .template : .original)
            .accessibilityLabel(store.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }

    private var indicatorStyle: MenuBarIndicatorStyle {
        MenuBarIndicatorStyle(rawValue: menuBarIndicatorStyle) ?? .percentage
    }

    // MenuBarExtra extracts a single image from its label. Compose the entire
    // status item first so the second image cannot be discarded by SwiftUI.
    private var statusImage: NSImage {
        let foreground: NSColor = colorScheme == .dark ? .white : .black
        let remaining = store.preferredWindow?.remainingPercent
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: gaugeColorMode == .trafficLight
                ? remaining.map(UsageIndicatorColor.nsColor(for:)) ?? foreground : foreground
        ]
        let text = store.menuBarPercentText as NSString
        let textSize = text.size(withAttributes: attributes)
        let gauge = indicatorStyle == .gauge && remaining != nil
        let size = NSSize(width: 25 + (gauge ? 24 : ceil(textSize.width)), height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        let logoRect = NSRect(x: 0, y: 0, width: 22, height: 22)
        MenuBarChatGPTIcon.image.draw(in: logoRect)
        foreground.setFill()
        logoRect.fill(using: .sourceIn)
        if gauge {
            MenuBarGaugeIcon.image(remainingPercent: remaining, colorMode: gaugeColorMode)
                .draw(in: NSRect(x: 25, y: 1, width: 24, height: 20))
        } else {
            text.draw(at: NSPoint(x: 25, y: floor((22 - textSize.height) / 2)), withAttributes: attributes)
        }
        image.unlockFocus()
        image.isTemplate = gaugeColorMode == .monochrome
        return image
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

            indicatorSettings

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

    private var indicatorSettings: some View {
        HStack(spacing: 18) {
            Toggle("Lancetta", isOn: showsGauge)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("Colori", isOn: showsGaugeColors)
                .toggleStyle(.switch)
                .controlSize(.small)

            Spacer()
        }
        .font(.caption)
        .animation(.default, value: indicatorStyle)
    }

    private var indicatorStyle: MenuBarIndicatorStyle {
        MenuBarIndicatorStyle(rawValue: menuBarIndicatorStyle) ?? .percentage
    }

    private var showsGauge: Binding<Bool> {
        Binding(
            get: { indicatorStyle == .gauge },
            set: { menuBarIndicatorStyle = $0 ? MenuBarIndicatorStyle.gauge.rawValue : MenuBarIndicatorStyle.percentage.rawValue }
        )
    }

    private var showsGaugeColors: Binding<Bool> {
        Binding(
            get: { GaugeColorMode(rawValue: menuBarGaugeColorMode) != .monochrome },
            set: { menuBarGaugeColorMode = $0 ? GaugeColorMode.trafficLight.rawValue : GaugeColorMode.monochrome.rawValue }
        )
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
    @AppStorage("menuBarGaugeColorMode") private var menuBarGaugeColorMode = GaugeColorMode.trafficLight.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(window.remainingPercentText) rimasto")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(percentageColor)
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
        guard colorMode == .trafficLight else { return .accentColor }
        return UsageIndicatorColor.swiftUIColor(for: window.remainingPercent)
    }

    private var percentageColor: Color {
        guard colorMode == .trafficLight else { return .primary }
        return UsageIndicatorColor.swiftUIColor(for: window.remainingPercent)
    }

    private var colorMode: GaugeColorMode {
        GaugeColorMode(rawValue: menuBarGaugeColorMode) ?? .trafficLight
    }
}
