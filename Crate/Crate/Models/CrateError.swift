import Foundation

enum CrateError: LocalizedError {
    case missingKernel
    case runtimeNotReady

    var errorDescription: String? {
        switch self {
        case .missingKernel:
            "Kernel binary not found in app bundle. Ensure vmlinuz is included as a resource."
        case .runtimeNotReady:
            "Container runtime is not ready. Check logs for initialization errors."
        }
    }
}
