import Foundation
import Combine

@Observable
final class NFCReaderViewModel {

    private(set) var scanResults: [ScanResultItem] = []
    private(set) var isScanning = false
    private(set) var errorMessage: String?

    private let sessionManager = NFCSessionManager()
    private var cancellables = Set<AnyCancellable>()

    struct ScanResultItem: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let category: Category

        enum Category: String {
            case ndef = "NDEF Record"
            case tag = "Tag Info"
            case iso7816 = "ISO 7816"
        }
    }

    init() {
        sessionManager.resultSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleResult(result)
            }
            .store(in: &cancellables)
    }

    func scanNDEF() {
        resetState()
        isScanning = true
        sessionManager.startNDEFScan()
    }

    func scanISO7816() {
        resetState()
        isScanning = true
        sessionManager.startISO7816Scan()
    }

    func clearResults() {
        resetState()
    }

    private func resetState() {
        scanResults = []
        errorMessage = nil
        isScanning = false
    }

    private func handleResult(_ result: NFCSessionManager.ScanResult) {
        isScanning = false

        switch result {
        case .ndef(let records):
            scanResults = records.map { record in
                ScanResultItem(
                    title: record.type,
                    detail: "Format: \(record.typeNameFormat)\nPayload: \(record.payload)",
                    category: .ndef
                )
            }

        case .iso7816(let atr, let aid, let responseData):
            var items: [ScanResultItem] = [
                ScanResultItem(title: "Historical Bytes (ATR)", detail: atr, category: .iso7816)
            ]
            if let aid {
                items.append(ScanResultItem(title: "Initial Selected AID", detail: aid, category: .iso7816))
            }
            if let responseData {
                items.append(ScanResultItem(title: "Response Data", detail: responseData, category: .iso7816))
            }
            scanResults.append(contentsOf: items)

        case .tagInfo(let type, let identifier):
            scanResults.append(
                ScanResultItem(title: type, detail: "UID: \(identifier)", category: .tag)
            )

        case .error(let message):
            errorMessage = message
        }
    }
}
