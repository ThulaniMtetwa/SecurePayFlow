import SwiftUI

struct BiometricGateView: View {
    @State private var viewModel = BiometricGateViewModel()
    private let layer = SecurityLayer.biometricGate

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    layerInfoSection
                    biometricStatusSection
                    flowButtonsSection
                    flowVisualisationSection
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

    private var biometricStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.biometricType.icon)
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text("Device Biometric")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.biometricType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            transactionBadge
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var transactionBadge: some View {
        VStack(alignment: .trailing) {
            Text(viewModel.mockTransaction.amount)
                .font(.headline)
            Text(viewModel.mockTransaction.merchant)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var flowButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.simulateStandardPayment() }
            } label: {
                VStack(spacing: 4) {
                    Label("Standard Apple Pay Flow", systemImage: "lock.shield")
                    Text("Requires biometric verification")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.flowState != .idle)

            Button {
                Task { await viewModel.simulateExpressTransitPayment() }
            } label: {
                VStack(spacing: 4) {
                    Label("Express Transit Flow", systemImage: "tram")
                    Text("Skips biometric verification entirely")
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(viewModel.flowState != .idle)

            if viewModel.flowState != .idle {
                Button("Reset") {
                    viewModel.reset()
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var flowVisualisationSection: some View {
        if viewModel.flowState != .idle {
            VStack(alignment: .leading, spacing: 16) {
                Text("Payment Flow")
                    .font(.headline)

                flowStep(
                    "NFC Terminal Detected",
                    icon: "wave.3.right",
                    isActive: true,
                    isComplete: viewModel.flowState != .terminalDetected
                )

                if viewModel.isExpressTransitMode {
                    flowStep(
                        "Biometric Check SKIPPED",
                        icon: "faceid",
                        isActive: viewModel.flowState == .expressTransitBypass,
                        isComplete: viewModel.flowState == .paymentComplete,
                        isWarning: true
                    )
                } else {
                    flowStep(
                        "Awaiting Biometric Verification",
                        icon: "faceid",
                        isActive: viewModel.flowState == .awaitingBiometric,
                        isComplete: viewModel.flowState == .authenticated
                            || viewModel.flowState == .paymentComplete
                    )
                }

                flowStep(
                    "Secure Element Processes Payment",
                    icon: "creditcard",
                    isActive: viewModel.flowState == .authenticated
                        || viewModel.flowState == .expressTransitBypass,
                    isComplete: viewModel.flowState == .paymentComplete
                )

                if viewModel.flowState == .paymentComplete {
                    Label(
                        viewModel.isExpressTransitMode
                            ? "Payment completed with NO user verification"
                            : "Payment completed with biometric verification",
                        systemImage: viewModel.isExpressTransitMode
                            ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.isExpressTransitMode ? .orange : .green)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        (viewModel.isExpressTransitMode ? Color.orange : Color.green).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }

                if case .failed(let message) = viewModel.flowState {
                    Label(message, systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Helpers

    private func flowStep(
        _ title: String,
        icon: String,
        isActive: Bool,
        isComplete: Bool,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(stepColor(isActive: isActive, isComplete: isComplete, isWarning: isWarning))
                    .frame(width: 36, height: 36)

                Image(systemName: isComplete ? "checkmark" : icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive || isComplete ? .primary : .secondary)
                .strikethrough(isWarning && isComplete)
        }
    }

    private func stepColor(isActive: Bool, isComplete: Bool, isWarning: Bool) -> Color {
        if isWarning { return .orange }
        if isComplete { return .green }
        if isActive { return .blue }
        return .gray.opacity(0.4)
    }
}
