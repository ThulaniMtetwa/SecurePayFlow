import SwiftUI

struct SecureEnclaveDemoView: View {
    @State private var viewModel = SecureEnclaveDemoViewModel()
    private let layer = SecurityLayer.secureEnclave

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    layerInfoSection
                    availabilitySection
                    stepsSection
                    resultsSection
                }
                .padding()
            }
            .navigationTitle(layer.title)
            .onAppear { viewModel.onAppear() }
        }
    }

    // MARK: - Sections

    private var layerInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Security Layer", systemImage: layer.icon)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(layer.layerDescription)
                .font(.subheadline)

            DisclosureGroup("What Express Transit changes") {
                Text(layer.expressTransitImpact)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var availabilitySection: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.isEnclaveAvailable ? "checkmark.shield" : "xmark.shield")
                .font(.title2)
                .foregroundStyle(viewModel.isEnclaveAvailable ? .green : .red)

            VStack(alignment: .leading) {
                Text("Secure Enclave")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.isEnclaveAvailable ? "Available" : "Unavailable (Simulator)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var stepsSection: some View {
        VStack(spacing: 12) {
            stepButton(
                number: 1,
                title: "Generate Key Pair",
                subtitle: "Create P-256 keys in the Secure Enclave",
                icon: "key",
                action: viewModel.generateKey,
                isEnabled: viewModel.isEnclaveAvailable && viewModel.state == .idle
            )

            stepButton(
                number: 2,
                title: "Sign Transaction",
                subtitle: "Sign R 10,000.00 payload (amount included)",
                icon: "signature",
                action: viewModel.signPayload,
                isEnabled: viewModel.state == .keyGenerated
            )

            stepButton(
                number: 3,
                title: "Verify Original",
                subtitle: "Confirm signature matches untampered payload",
                icon: "checkmark.seal",
                action: viewModel.verifyOriginal,
                isEnabled: viewModel.state == .signed
            )

            stepButton(
                number: 4,
                title: "Simulate Tamper Attack",
                subtitle: "Change R 10,000 to R 1.50 and re-verify",
                icon: "exclamationmark.triangle",
                action: viewModel.verifyTampered,
                isEnabled: viewModel.state == .verified
            )

            if viewModel.state != .idle {
                Button("Reset All") {
                    viewModel.reset()
                }
                .font(.subheadline)
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if case .error(let message) = viewModel.state {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }

        if let publicKey = viewModel.publicKeyHex {
            resultCard(
                title: "Public Key (P-256)",
                content: publicKey.truncatedHex,
                icon: "key",
                color: .blue
            )
        }

        if let signature = viewModel.signatureHex {
            resultCard(
                title: "ECDSA Signature",
                content: signature.truncatedHex,
                icon: "signature",
                color: .purple
            )

            if let amount = viewModel.originalAmount {
                resultCard(
                    title: "Signed Amount",
                    content: amount,
                    icon: "banknote",
                    color: .green
                )
            }
        }

        if let isValid = viewModel.verificationResult {
            verificationBanner(
                title: "Original Payload Verification",
                isValid: isValid,
                detail: isValid
                    ? "Signature matches the payload. Transaction is authentic."
                    : "Signature does not match. This should not happen with untampered data."
            )
        }

        if let isValid = viewModel.tamperVerificationResult {
            verificationBanner(
                title: "Tampered Payload Verification",
                isValid: isValid,
                detail: isValid
                    ? "WARNING: Tampered payload was accepted. This is the Visa vulnerability."
                    : "Signature REJECTED. Amount was changed from \(viewModel.originalAmount ?? "R 10,000.00") to \(viewModel.tamperedAmount ?? "R 1.50"). This is how Mastercard's protocol prevents the attack."
            )

            if !isValid {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What happened")
                        .font(.headline)

                    Text(
                        "The Secure Enclave signed the original payload including the R 10,000.00 amount. " +
                        "When the attacker changed the amount to R 1.50 (simulating a transit fare), " +
                        "the signature no longer matched the altered data. The transaction would be " +
                        "rejected by the card network."
                    )
                    .font(.subheadline)

                    Text(
                        "Visa's protocol for transit transactions does not perform this check, " +
                        "which is why the researchers' bit-flip attack succeeds. Mastercard's " +
                        "implementation binds the amount cryptographically, making this " +
                        "tampering detectable."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Components

    private func stepButton(
        number: Int,
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void,
        isEnabled: Bool
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? .blue : .gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                    Text("\(number)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: icon)
                    .foregroundStyle(isEnabled ? .blue : .gray)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!isEnabled)
    }

    private func resultCard(
        title: String,
        content: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(content)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func verificationBanner(
        title: String,
        isValid: Bool,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: isValid ? "checkmark.circle" : "xmark.circle")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isValid ? .green : .red)

            Text(detail)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isValid ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

private extension String {
    var truncatedHex: String {
        if count > 64 {
            return String(prefix(32)) + "..." + String(suffix(32))
        }
        return self
    }
}
