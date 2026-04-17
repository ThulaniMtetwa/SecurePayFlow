import SwiftUI

struct ContentView: View {
    @State private var selectedTab: SecurityLayer = .nfcReader

    var body: some View {
        TabView(selection: $selectedTab) {
            NFCReaderView()
                .tabItem {
                    Label(SecurityLayer.nfcReader.title, systemImage: SecurityLayer.nfcReader.icon)
                }
                .tag(SecurityLayer.nfcReader)

            BiometricGateView()
                .tabItem {
                    Label(SecurityLayer.biometricGate.title, systemImage: SecurityLayer.biometricGate.icon)
                }
                .tag(SecurityLayer.biometricGate)

            SecureEnclaveDemoView()
                .tabItem {
                    Label(SecurityLayer.secureEnclave.title, systemImage: SecurityLayer.secureEnclave.icon)
                }
                .tag(SecurityLayer.secureEnclave)
        }
    }
}
