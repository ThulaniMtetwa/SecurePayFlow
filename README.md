# SecurePayFlow

A companion iOS demo app for the Medium article *"Express Transit's Trust Model: What iOS Engineers Should Know About NFC Payment Security."*

SecurePayFlow illustrates the three security layers that Apple's Express Transit vulnerability bypasses, giving iOS and fintech developers a hands-on understanding of each layer from the SDK side.

## Demo

[![SecurePayFlow Demo](https://img.youtube.com/vi/EPGygEG_dk4/maxresdefault.jpg)](https://youtube.com/shorts/EPGygEG_dk4)

## Modules

### 1. NFC Reader (Requires Paid Developer Account)
Scans and displays NFC tag metadata (NDEF records, ISO 7816 ATR bytes, tag type, UID). Demonstrates what Core NFC exposes to third-party developers and where Apple's entitlement wall stops you from accessing card emulation.

> **Note:** This module requires the `Near Field Communication Tag Reading` entitlement, which is only available with a paid Apple Developer Program membership ($99/year). The code compiles without the entitlement but NFC scanning will be unavailable at runtime. Modules 2 and 3 work without a paid account.

### 2. Biometric Gate
A mock "payment authorisation" flow using `LAContext` from the LocalAuthentication framework. Shows the exact biometric challenge that Express Transit skips when processing transit payments from a locked device.

Run both flows side by side:
- **Standard Apple Pay** -- prompts Face ID/Touch ID before the Secure Element processes payment
- **Express Transit** -- skips biometric verification entirely, demonstrating the step the hack exploits

### 3. Secure Enclave Operations
Generates a P-256 key pair inside the Secure Enclave, signs a mock transaction payload, then verifies the signature. Demonstrates the asymmetric cryptographic signing concept that Mastercard enforces (binding transaction amount to the signed payload) and that Visa omits for transit scenarios.

Walk through four steps:
1. **Generate Key Pair** -- creates P-256 keys in the Secure Enclave hardware
2. **Sign Transaction** -- signs a R 10,000.00 payload with the amount included in the signed data
3. **Verify Original** -- confirms the signature matches the untampered payload
4. **Simulate Tamper Attack** -- changes the amount to R 1.50 (a transit fare) and shows the signature verification fails

This is the key demo: it makes the Mastercard vs Visa cryptographic difference tangible.

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Physical device for Biometric Gate and Secure Enclave modules (Simulator does not support Secure Enclave or real biometric authentication)
- Paid Apple Developer Program membership for NFC Reader module only

## Setup

1. Clone the repository
2. Open `SecurePayFlow.xcodeproj` in Xcode
3. Select your development team under Signing & Capabilities
4. Add `Privacy - Face ID Usage Description` in the Info tab if not already present
5. Build and run on a physical device

### NFC Module Setup (Optional, requires paid account)

1. Add the **Near Field Communication Tag Reading** capability under Signing & Capabilities
2. Add `Privacy - NFC Scan Usage Description` in the Info tab
3. Add `com.apple.developer.nfc.readersession.iso7816.select-identifiers` as an Array in the Info tab with:
   - `325041592E5359532E4444463031`
   - `A0000000031010`
   - `A0000000041010`

## Architecture

MVVM with SwiftUI. Each module follows the same pattern:
- **View** -- SwiftUI view with state binding
- **ViewModel** -- `@Observable` class holding state and coordinating logic
- **Manager** -- Framework wrapper isolating platform APIs (Core NFC, LocalAuthentication, Security/CryptoKit)

## Background

In 2021, researchers at the University of Birmingham and the University of Surrey demonstrated that Apple's Express Transit feature, combined with a Visa card, could be exploited to steal arbitrary amounts from a locked iPhone. The attack bypasses three security layers:

1. **NFC access control** -- the phone is tricked into transit mode by replaying "magic bytes" from a Proxmark device
2. **Biometric verification** -- Express Transit skips the Secure Enclave's Face ID/Touch ID check entirely
3. **Cryptographic binding** -- Visa's protocol does not bind the transaction amount to the signed payload, unlike Mastercard's implementation

The vulnerability was presented at the 2022 IEEE Symposium on Security and Privacy and remains unpatched as of 2026. This project exists to make each of those layers visible and understandable from an iOS developer's perspective.

## Related

- [Medium article: Express Transit's Trust Model](link-pending)
- [SecurityKit](https://github.com/ThulaniMtetwa/SecurityKit) -- open-source iOS security framework
- [Practical EMV Relay Protection](https://practical_emv.gitlab.io/) -- original research by Radu et al. (IEEE S&P 2022)
- [Veritasium: How Secure Is Tap To Pay?](https://youtu.be/PPJ6NJkmDAo)

## License

MIT
