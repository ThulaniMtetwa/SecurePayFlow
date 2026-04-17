import Foundation

enum SecurityLayer: String, CaseIterable, Identifiable {
    case nfcReader
    case biometricGate
    case secureEnclave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nfcReader: "NFC Reader"
        case .biometricGate: "Biometric Gate"
        case .secureEnclave: "Secure Enclave"
        }
    }

    var icon: String {
        switch self {
        case .nfcReader: "wave.3.right"
        case .biometricGate: "faceid"
        case .secureEnclave: "lock.shield"
        }
    }

    var layerDescription: String {
        switch self {
        case .nfcReader:
            "Core NFC gives third-party developers read-only access to NFC tags. " +
            "Card emulation (making the phone act as a contactless card) is reserved " +
            "exclusively for Apple's Wallet app. There is no public entitlement for " +
            "Host Card Emulation on iOS."

        case .biometricGate:
            "In a standard Apple Pay transaction, the Secure Enclave must verify " +
            "the user's identity via FaceID, TouchID, or passcode before the Secure " +
            "Element processes payment. Express Transit skips this step entirely " +
            "to allow fast tap-and-go at transit turnstiles."

        case .secureEnclave:
            "Mastercard cryptographically binds the transaction amount to the signed " +
            "payload using asymmetric signatures. If an attacker alters the amount, " +
            "the signature breaks. Visa omits this check for transit transactions, " +
            "allowing data to be tampered with in flight."
        }
    }

    /// What Express Transit changes about this layer
    var expressTransitImpact: String {
        switch self {
        case .nfcReader:
            "Express Transit uses card emulation (unavailable to third-party apps) " +
            "to respond to transit terminal signals without any app being open."

        case .biometricGate:
            "Express Transit removes LocalAuthentication from the payment flow. " +
            "The NFC controller talks directly to the Secure Element with no " +
            "biometric challenge, no passcode, and works while the phone is locked."

        case .secureEnclave:
            "The Secure Element still signs the transaction, but Visa's protocol " +
            "does not bind the transaction amount to the signature for transit mode. " +
            "Attackers can modify the Card Transaction Qualifiers (CTQ) to falsely " +
            "indicate biometric verification was performed."
        }
    }
}
