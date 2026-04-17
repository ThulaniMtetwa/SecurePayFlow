import SwiftUI

struct NFCReaderView: View {
    @State private var viewModel = NFCReaderViewModel()
    private let layer = SecurityLayer.nfcReader

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    layerInfoSection
                    scanButtonsSection
                    resultsSection
                }
                .padding()
            }
            .navigationTitle(layer.title)
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

    private var scanButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.scanNDEF()
            } label: {
                Label("Scan NDEF Tag", systemImage: "wave.3.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning)

            Button {
                viewModel.scanISO7816()
            } label: {
                Label("Scan ISO 7816 / Contactless Card", systemImage: "creditcard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isScanning)

            if viewModel.isScanning {
                ProgressView("Waiting for NFC tag...")
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }

        if !viewModel.scanResults.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Scan Results")
                        .font(.headline)
                    Spacer()
                    Button("Clear", role: .destructive) {
                        viewModel.clearResults()
                    }
                    .font(.subheadline)
                }

                ForEach(viewModel.scanResults) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.blue, in: Capsule())

                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text(item.detail)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
