import Foundation

struct AccountInfo: Equatable {
    let email: String?
    let planType: String?

    var subtitle: String {
        [email, planType?.capitalized]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }
}

struct UsageWindow: Identifiable, Equatable {
    let id: String
    let limitID: String
    let limitName: String?
    let kind: String
    let usedPercent: Double
    let windowDurationMinutes: Int?
    let resetsAt: Date?

    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    var remainingPercentText: String {
        "\(Int(remainingPercent.rounded()))%"
    }

    var displayName: String {
        let baseName: String
        if let limitName, !limitName.isEmpty {
            baseName = limitName
        } else if limitID == "codex" {
            baseName = "GPT"
        } else {
            baseName = limitID.replacingOccurrences(of: "_", with: " ").capitalized
        }

        guard let windowDurationMinutes else { return baseName }

        let period: String
        switch windowDurationMinutes {
        case 0..<120:
            period = "\(windowDurationMinutes) min"
        case 120..<1440:
            period = "\(windowDurationMinutes / 60) ore"
        case 1440..<10000:
            period = "\(windowDurationMinutes / 1440) giorni"
        default:
            period = "settimanale"
        }

        return "\(baseName) · \(period)"
    }

    var resetText: String? {
        guard let resetsAt else { return nil }
        return "Reset \(resetsAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

enum UsagePayloadParser {
    static func parseAccount(from response: [String: Any]) -> AccountInfo? {
        guard
            let result = response["result"] as? [String: Any],
            let account = result["account"] as? [String: Any]
        else {
            return nil
        }

        return AccountInfo(
            email: account["email"] as? String,
            planType: account["planType"] as? String
        )
    }

    static func requiresOpenAIAuth(from response: [String: Any]) -> Bool {
        let result = response["result"] as? [String: Any]
        return result?["requiresOpenaiAuth"] as? Bool ?? true
    }

    static func parseWindows(from response: [String: Any]) -> [UsageWindow] {
        guard let result = response["result"] as? [String: Any] else { return [] }

        var windows: [UsageWindow] = []

        if let grouped = result["rateLimitsByLimitId"] as? [String: Any] {
            for (limitID, rawValue) in grouped {
                guard let limit = rawValue as? [String: Any] else { continue }
                windows.append(contentsOf: parseLimit(limit, fallbackID: limitID))
            }
        } else if let limit = result["rateLimits"] as? [String: Any] {
            windows.append(contentsOf: parseLimit(limit, fallbackID: "codex"))
        }

        return windows.sorted { lhs, rhs in
            if lhs.limitID == "codex", rhs.limitID != "codex" { return true }
            if lhs.limitID != "codex", rhs.limitID == "codex" { return false }
            if lhs.limitID != rhs.limitID { return lhs.limitID < rhs.limitID }
            return lhs.kind < rhs.kind
        }
    }

    private static func parseLimit(_ limit: [String: Any], fallbackID: String) -> [UsageWindow] {
        let limitID = limit["limitId"] as? String ?? fallbackID
        let limitName = limit["limitName"] as? String

        return ["primary", "secondary"].compactMap { kind in
            guard let window = limit[kind] as? [String: Any] else { return nil }

            let used = (window["usedPercent"] as? NSNumber)?.doubleValue
            guard let used else { return nil }

            let duration = (window["windowDurationMins"] as? NSNumber)?.intValue
            let resetTimestamp = (window["resetsAt"] as? NSNumber)?.doubleValue

            return UsageWindow(
                id: "\(limitID)-\(kind)",
                limitID: limitID,
                limitName: limitName,
                kind: kind,
                usedPercent: used,
                windowDurationMinutes: duration,
                resetsAt: resetTimestamp.map(Date.init(timeIntervalSince1970:))
            )
        }
    }
}
