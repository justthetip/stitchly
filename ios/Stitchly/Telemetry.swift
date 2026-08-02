import Foundation
import MetricKit

final class Telemetry: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = Telemetry()
    private let lock = NSLock()
    private var client: APIClient?
    private var observing = false

    func configure(client: APIClient) {
        lock.lock(); self.client = client
        if !observing { observing = true; MXMetricManager.shared.add(self) }
        lock.unlock()
        track("app_opened")
    }

    func track(_ event: String, properties: [String: String] = [:]) {
        lock.lock(); let client = self.client; lock.unlock()
        guard client?.token != nil, client?.token != "demo" else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        struct Body: Encodable { let event: String; let appVersion: String?; let buildNumber: String?; let properties: [String: String] }
        Task { let _: EmptyResponse? = try? await client?.request("/api/native-telemetry", method: "POST", body: Body(event: event, appVersion: version, buildNumber: build, properties: properties)) }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let crashCount = payloads.reduce(0) { $0 + ($1.crashDiagnostics?.count ?? 0) }
        track("metric_diagnostic_received", properties: [
            "payload_count": String(payloads.count),
            "crash_count": String(crashCount),
            "environment": "production",
        ])
    }
}
