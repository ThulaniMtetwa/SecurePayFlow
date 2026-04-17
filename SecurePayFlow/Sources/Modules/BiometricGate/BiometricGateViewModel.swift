import Foundation

@Observable
final class BiometricGateViewModel {

    enum PaymentFlowState: Equatable {
        case idle
        case terminalDetected
        case awaitingBiometric
        case authenticated
        case paymentComplete
        case expressTransitBypass
        case failed(String)
    }

    private(set) var flowState: PaymentFlowState = .idle
    private(set) var biometricType: BiometricAuthManager.BiometricType = .none
    private(set) var isExpressTransitMode = false

    let mockTransaction = MockTransaction(
        amount: "R 150.00",
        merchant: "Gautrain Station",
        cardLast4: "4921"
    )

    private let authManager = BiometricAuthManager()

    struct MockTransaction {
        let amount: String
        let merchant: String
        let cardLast4: String
    }

    func onAppear() {
        biometricType = authManager.availableBiometricType()
    }

    /// Simulates the standard Apple Pay flow where biometric
    /// verification is required before the Secure Element proceeds.
    func simulateStandardPayment() async {
        isExpressTransitMode = false
        flowState = .terminalDetected

        try? await Task.sleep(for: .seconds(1))
        flowState = .awaitingBiometric

        let result = await authManager.authenticate(
            reason: "Authorise payment of \(mockTransaction.amount) to \(mockTransaction.merchant)"
        )

        switch result {
        case .success:
            flowState = .authenticated
            try? await Task.sleep(for: .seconds(0.8))
            flowState = .paymentComplete

        case .failure(let message):
            flowState = .failed(message)

        case .unavailable(let message):
            flowState = .failed(message)
        }
    }

    /// Simulates the Express Transit flow where the Secure Element
    /// processes the payment without any biometric challenge.
    /// No LAContext evaluation occurs. This is the flow the hack exploits.
    func simulateExpressTransitPayment() async {
        isExpressTransitMode = true
        flowState = .terminalDetected

        try? await Task.sleep(for: .seconds(0.5))
        flowState = .expressTransitBypass

        try? await Task.sleep(for: .seconds(0.8))
        flowState = .paymentComplete
    }

    func reset() {
        flowState = .idle
        isExpressTransitMode = false
    }
}
