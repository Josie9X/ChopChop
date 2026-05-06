import Foundation

enum AppConfig {
    static let userDefaultsBackendBaseURLKey = "BackendBaseURL"
    static let infoPlistBackendBaseURLKey = "BACKEND_BASE_URL"
    static let productionBackendBaseURLString = "https://sd7maaiccehg5j7macmeg.apigateway-cn-beijing.volceapi.com"
    static let defaultBackendBaseURLString = productionBackendBaseURLString

    static var backendBaseURL: URL {
        if let override = UserDefaults.standard.string(forKey: userDefaultsBackendBaseURLKey),
           let url = URL(string: override),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }

        if let bundled = Bundle.main.object(forInfoDictionaryKey: infoPlistBackendBaseURLKey) as? String,
           let url = URL(string: bundled),
           !bundled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }

        return URL(string: defaultBackendBaseURLString)!
    }

    static var runtimeNetworkSummary: String {
        #if DEBUG && targetEnvironment(simulator)
        "debug simulator -> \(backendBaseURL.absoluteString)"
        #elseif DEBUG
        "debug device -> \(backendBaseURL.absoluteString)"
        #else
        "production -> \(backendBaseURL.absoluteString)"
        #endif
    }

    static var networkLoggingEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
