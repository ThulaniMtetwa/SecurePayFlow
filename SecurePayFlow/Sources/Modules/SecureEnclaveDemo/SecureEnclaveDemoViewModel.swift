import Foundation
import CryptoKit

@Observable
final class SecureEnclaveDemoViewModel {

    enum DemoState: Equatable {
        case idle
        case keyGenerated
        case signed
        case verified
        case tamperDetected
        case error(String)

        static func == (lhs: DemoState, rhs: DemoState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.keyGenerated, .keyGenerated),
                 (.signed, .signed),
                 (.verified, .verified),
                 (.tamperDetected, .tamperDetected):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private(set) var state: DemoState = .idle
    private(set) var isEnclaveAvailable = false
    private(set) var publicKeyHex: String?
    private(set) var signatureHex: String?
    private(set) var payloadPreview: String?
    private(set) var verificationResult: Bool?
    private(set) var tamperVerificationResult: Bool?
    private(set) var originalAmount: String?
    private(set) var tamperedAmount: String?

    private let manager = SecureEnclaveManager()
    private var privateKey: CryptoKit.SecureEnclave.P256.Signing.PrivateKey?
    private var signatureResult: SecureEnclaveManager.SignatureResult?

    let mockPayload = SecureEnclaveManager.TransactionPayload(
        amount: 1_000_000, // R 10,000.00 in cents
        currency: "ZAR",
        merchantId: "MERCHANT_TRANSIT_001",
        timestamp: .now,
        transactionId: UUID().uuidString
    )

    func onAppear() {
        isEnclaveAvailable = manager.isAvailable
    }

    /// Step 1: Generate a P-256 key pair in the Secure Enclave.
    func generateKey() {
        do {
            let key = try manager.generateKeyPair()
            privateKey = key
            publicKeyHex = key.publicKey.derRepresentation.hexString
            state = .keyGenerated
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Step 2: Sign the mock transaction payload.
    /// The amount is included in the signed data, just as Mastercard requires.
    func signPayload() {
        guard let privateKey else {
            state = .error("Generate a key pair first.")
            return
        }

        do {
            let result = try manager.signTransaction(mockPayload, with: privateKey)
            signatureResult = result
            signatureHex = result.signature.hexString
            originalAmount = result.originalPayload.displayAmount
            payloadPreview = String(data: result.payloadData, encoding: .utf8)
            state = .signed
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Step 3: Verify the untampered payload. Signature should be valid.
    func verifyOriginal() {
        guard let result = signatureResult else {
            state = .error("Sign a payload first.")
            return
        }

        do {
            let isValid = try manager.verify(
                payloadData: result.payloadData,
                signature: result.signature,
                publicKeyData: result.publicKeyData
            )
            verificationResult = isValid
            state = .verified
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Step 4: Tamper with the amount (simulating the attack) and verify.
    /// The signature should now be INVALID because the payload changed.
    func verifyTampered() {
        guard let result = signatureResult else {
            state = .error("Sign a payload first.")
            return
        }

        do {
            // Attacker changes amount from R10,000 to R1.50 (transit fare)
            let tamperedAmountCents = 150
            let (_, isValid) = try manager.verifyTamperedPayload(
                originalResult: result,
                tamperedAmount: tamperedAmountCents
            )
            tamperVerificationResult = isValid
            tamperedAmount = "R 1.50"
            state = .tamperDetected
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        publicKeyHex = nil
        signatureHex = nil
        payloadPreview = nil
        verificationResult = nil
        tamperVerificationResult = nil
        originalAmount = nil
        tamperedAmount = nil
        privateKey = nil
        signatureResult = nil
        try? manager.deleteKey()
    }
}
