import Foundation

let response: [String: Any] = [
    "result": [
        "rateLimitsByLimitId": [
            "codex": [
                "limitId": "codex",
                "limitName": NSNull(),
                "primary": [
                    "usedPercent": 50,
                    "windowDurationMins": 10_080,
                    "resetsAt": 1_790_069_723
                ],
                "secondary": NSNull()
            ],
            "codex_bengalfox": [
                "limitId": "codex_bengalfox",
                "limitName": "GPT-5.3-Codex-Spark",
                "primary": [
                    "usedPercent": 10,
                    "windowDurationMins": 300,
                    "resetsAt": 1_789_669_632
                ],
                "secondary": [
                    "usedPercent": 20,
                    "windowDurationMins": 10_080,
                    "resetsAt": 1_790_256_432
                ]
            ]
        ]
    ]
]

let windows = UsagePayloadParser.parseWindows(from: response)
precondition(windows.count == 3)
precondition(windows.first?.limitID == "codex")
precondition(windows.first?.remainingPercent == 50)
precondition(windows.contains(where: { $0.displayName == "GPT-5.3-Codex-Spark · 5 ore" }))
precondition(windows.contains(where: { $0.displayName == "GPT-5.3-Codex-Spark · settimanale" }))

print("Parser check passed: \(windows.count) usage windows")
