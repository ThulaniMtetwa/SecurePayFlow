import LocalAuthentication

/// Wraps LocalAuthentication framework to demonstrate the biometric
/// challenge that Express Transit bypasses in transit payment flows.
final class BiometricAuthManager {

    enum AuthResult {
        case success
        case failure(String)
        case unavailable(String)
    }

    enum BiometricType {
        case faceID
        case touchID
        case opticID
        case none

        var displayName: String {
            switch self {
            case .faceID: "Face ID"
            case .touchID: "Touch ID"
            case .opticID: "Optic ID"
            case .none: "None"
            }
        }

        var icon: String {
            switch self {
            case .faceID: "faceid"
            case .touchID: "touchid"
            case .opticID: "opticid"
            case .none: "lock.slash"
            }
        }
    }

    /// Returns the biometric type available on this device.
    func availableBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        return switch context.biometryType {
        case .faceID: .faceID
        case .touchID: .touchID
        case .opticID: .opticID
        default: .none
        }
    }

    /// Evaluates biometric authentication, simulating the check that
    /// the Secure Enclave performs in a standard Apple Pay transaction.
    ///
    /// In Express Transit mode, this entire step is skipped. The Secure
    /// Element processes the payment without ever asking the Secure
    /// Enclave to verify the user.
    func authenticate(reason: String) async -> AuthResult {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel Payment"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let message = error?.localizedDescription ?? "Biometric authentication is not available."
            return .unavailable(message)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? .success : .failure("Authentication was not successful.")
        } catch {
            let laError = error as? LAError
            if laError?.code == .userCancel || laError?.code == .appCancel {
                return .failure("Authentication cancelled.")
            }
            return .failure(error.localizedDescription)
        }
    }

    /// Evaluates device owner authentication (biometrics with passcode fallback).
    /// This represents the strongest user verification available on-device.
    func authenticateWithPasscodeFallback(reason: String) async -> AuthResult {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel Payment"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let message = error?.localizedDescription ?? "Device authentication is not available."
            return .unavailable(message)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success ? .success : .failure("Authentication was not successful.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
