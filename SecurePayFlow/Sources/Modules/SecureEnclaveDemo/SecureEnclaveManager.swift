import Foundation
import Security
import CryptoKit

/// Demonstrates Secure Enclave key operations to illustrate the asymmetric
/// cryptographic signing that Mastercard enforces (and Visa skips) for
/// transit transactions.
///
/// The Secure Enclave supports P-256 (secp256r1) key pairs. When we sign
/// a "transaction payload" and then verify it, we're demonstrating the
/// mechanism that would prevent the Express Transit attack: if the signed
/// payload includes the transaction amount, tampering with the amount
/// invalidates the signature.
final class SecureEnclaveManager {

    enum SEError: LocalizedError {
        case enclaveUnavailable
        case keyGenerationFailed(String)
        case signingFailed(String)
        case verificationFailed(String)
        case deletionFailed(String)

        var errorDescription: String? {
            switch self {
            case .enclaveUnavailable:
                "Secure Enclave is not available. This requires a physical device."
            case .keyGenerationFailed(let detail):
                "Key generation failed: \(detail)"
            case .signingFailed(let detail):
                "Signing failed: \(detail)"
            case .verificationFailed(let detail):
                "Verification failed: \(detail)"
            case .deletionFailed(let detail):
                "Key deletion failed: \(detail)"
            }
        }
    }

    struct TransactionPayload: Codable {
        let amount: Int // cents
        let currency: String
        let merchantId: String
        let timestamp: Date
        let transactionId: String

        var data: Data {
            get throws {
                try JSONEncoder().encode(self)
            }
        }

        var displayAmount: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            return formatter.string(from: NSNumber(value: Double(amount) / 100.0)) ?? "\(amount)"
        }
    }

    struct SignatureResult {
        let originalPayload: TransactionPayload
        let payloadData: Data
        let signature: Data
        let publicKeyData: Data
    }

    private static let keyTag = "com.securepayflow.demo.transaction-signing"

    /// Checks whether the Secure Enclave is available on this device.
    var isAvailable: Bool {
        SecureEnclave.isAvailable
    }

    // MARK: - Key Generation

    /// Generates a P-256 key pair in the Secure Enclave.
    /// The private key never leaves the Secure Enclave hardware.
    func generateKeyPair() throws -> SecureEnclave.P256.Signing.PrivateKey {
        guard isAvailable else {
            throw SEError.enclaveUnavailable
        }

        // Remove any existing key with this tag
        try? deleteKey()

        do {
            let privateKey = try SecureEnclave.P256.Signing.PrivateKey()
            return privateKey
        } catch {
            throw SEError.keyGenerationFailed(error.localizedDescription)
        }
    }

    // MARK: - Signing

    /// Signs a transaction payload using the Secure Enclave private key.
    ///
    /// This demonstrates what Mastercard's protocol does: the transaction
    /// amount and metadata are included in the signed data, so any
    /// tampering invalidates the signature.
    func signTransaction(
        _ payload: TransactionPayload,
        with privateKey: SecureEnclave.P256.Signing.PrivateKey
    ) throws -> SignatureResult {
        let payloadData: Data
        do {
            payloadData = try payload.data
        } catch {
            throw SEError.signingFailed("Failed to encode payload: \(error.localizedDescription)")
        }

        do {
            let signature = try privateKey.signature(for: payloadData)
            let publicKey = privateKey.publicKey

            return SignatureResult(
                originalPayload: payload,
                payloadData: payloadData,
                signature: signature.derRepresentation,
                publicKeyData: publicKey.derRepresentation
            )
        } catch {
            throw SEError.signingFailed(error.localizedDescription)
        }
    }

    // MARK: - Verification

    /// Verifies a signature against a payload using the public key.
    /// Returns true if the payload has not been tampered with.
    func verify(
        payloadData: Data,
        signature: Data,
        publicKeyData: Data
    ) throws -> Bool {
        do {
            let publicKey = try P256.Signing.PublicKey(derRepresentation: publicKeyData)
            let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
            return publicKey.isValidSignature(ecdsaSignature, for: payloadData)
        } catch {
            throw SEError.verificationFailed(error.localizedDescription)
        }
    }

    /// Demonstrates the attack scenario: modifies the transaction amount
    /// in the payload (simulating the bit-flip attack) and shows that
    /// verification fails because the signature no longer matches.
    func verifyTamperedPayload(
        originalResult: SignatureResult,
        tamperedAmount: Int
    ) throws -> (tamperedData: Data, isValid: Bool) {
        let tamperedPayload = TransactionPayload(
            amount: tamperedAmount,
            currency: originalResult.originalPayload.currency,
            merchantId: originalResult.originalPayload.merchantId,
            timestamp: originalResult.originalPayload.timestamp,
            transactionId: originalResult.originalPayload.transactionId
        )

        let tamperedData = try tamperedPayload.data

        let isValid = try verify(
            payloadData: tamperedData,
            signature: originalResult.signature,
            publicKeyData: originalResult.publicKeyData
        )

        return (tamperedData, isValid)
    }

    // MARK: - Cleanup

    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SEError.deletionFailed("OSStatus: \(status)")
        }
    }
}
