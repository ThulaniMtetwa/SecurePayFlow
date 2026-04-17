import CoreNFC
import Combine

/// Wraps Core NFC tag reading sessions, demonstrating the extent of
/// third-party NFC access on iOS. Card emulation is not available.
final class NFCSessionManager: NSObject {

    enum ScanResult {
        case ndef([NDEFRecord])
        case iso7816(atr: String, aid: String?, responseData: String?)
        case tagInfo(type: String, identifier: String)
        case error(String)
    }

    struct NDEFRecord: Identifiable {
        let id = UUID()
        let typeNameFormat: String
        let type: String
        let payload: String
    }

    let resultSubject = PassthroughSubject<ScanResult, Never>()

    private var ndefSession: NFCNDEFReaderSession?
    private var tagSession: NFCTagReaderSession?

    // MARK: - NDEF Scanning

    func startNDEFScan() {
        guard NFCNDEFReaderSession.readingAvailable else {
            resultSubject.send(.error("NFC reading is not available on this device."))
            return
        }

        ndefSession = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: true)
        ndefSession?.alertMessage = "Hold your iPhone near an NFC tag."
        ndefSession?.begin()
    }

    // MARK: - ISO 7816 Tag Scanning

    func startISO7816Scan() {
        guard NFCTagReaderSession.readingAvailable else {
            resultSubject.send(.error("NFC tag reading is not available on this device."))
            return
        }

        tagSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: .main)
        tagSession?.alertMessage = "Hold your iPhone near an NFC tag or contactless card."
        tagSession?.begin()
    }

    func invalidate() {
        ndefSession?.invalidate()
        tagSession?.invalidate()
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCSessionManager: NFCNDEFReaderSessionDelegate {

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let records: [NDEFRecord] = messages.flatMap { message in
            message.records.map { record in
                NDEFRecord(
                    typeNameFormat: record.typeNameFormat.displayName,
                    type: String(data: record.type, encoding: .utf8) ?? record.type.hexString,
                    payload: Self.parsePayload(record)
                )
            }
        }
        resultSubject.send(.ndef(records))
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as? NFCReaderError
        guard nfcError?.code != .readerSessionInvalidationErrorUserCanceled else { return }
        resultSubject.send(.error(error.localizedDescription))
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}
}

// MARK: - NFCTagReaderSessionDelegate

extension NFCSessionManager: NFCTagReaderSessionDelegate {

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as? NFCReaderError
        guard nfcError?.code != .readerSessionInvalidationErrorUserCanceled else { return }
        resultSubject.send(.error(error.localizedDescription))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }

            if let error {
                self.resultSubject.send(.error("Connection failed: \(error.localizedDescription)"))
                session.invalidate(errorMessage: "Connection failed.")
                return
            }

            switch tag {
            case .iso7816(let iso7816Tag):
                let atr = iso7816Tag.historicalBytes?.hexString ?? "N/A"
                let identifier = iso7816Tag.identifier.hexString

                self.resultSubject.send(.iso7816(
                    atr: atr,
                    aid: iso7816Tag.initialSelectedAID,
                    responseData: nil
                ))
                self.resultSubject.send(.tagInfo(type: "ISO 7816", identifier: identifier))
                session.alertMessage = "ISO 7816 tag detected."
                session.invalidate()

            case .iso15693(let iso15693Tag):
                let identifier = iso15693Tag.identifier.hexString
                self.resultSubject.send(.tagInfo(type: "ISO 15693", identifier: identifier))
                session.alertMessage = "ISO 15693 tag detected."
                session.invalidate()

            case .miFare(let miFareTag):
                let identifier = miFareTag.identifier.hexString
                let family: String = switch miFareTag.mifareFamily {
                case .ultralight: "Ultralight"
                case .plus: "Plus"
                case .desfire: "DESFire"
                default: "Unknown"
                }
                self.resultSubject.send(.tagInfo(type: "MiFare \(family)", identifier: identifier))
                session.alertMessage = "MiFare tag detected."
                session.invalidate()

            case .feliCa(let feliCaTag):
                let identifier = feliCaTag.currentIDm.hexString
                self.resultSubject.send(.tagInfo(type: "FeliCa", identifier: identifier))
                session.alertMessage = "FeliCa tag detected."
                session.invalidate()

            @unknown default:
                self.resultSubject.send(.error("Unknown tag type."))
                session.invalidate(errorMessage: "Unsupported tag.")
            }
        }
    }
}

// MARK: - Helpers

private extension NFCSessionManager {
    static func parsePayload(_ record: NFCNDEFPayload) -> String {
        if let url = record.wellKnownTypeURIPayload()?.absoluteString {
            return url
        }
        let (text, _) = record.wellKnownTypeTextPayload()
        if let text {
            return text
        }
        return record.payload.hexString
    }
}

extension NFCTypeNameFormat {
    var displayName: String {
        switch self {
        case .empty: "Empty"
        case .nfcWellKnown: "NFC Well Known"
        case .media: "Media"
        case .absoluteURI: "Absolute URI"
        case .nfcExternal: "NFC External"
        case .unknown: "Unknown"
        case .unchanged: "Unchanged"
        @unknown default: "Unknown (\(rawValue))"
        }
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
