import SwiftUI

/// Einstiegspunkt der Phase-0-Test-App.
///
/// Reine SwiftUI-App ohne Scene-Delegate. Zweck ist ausschliesslich der
/// Machbarkeitsnachweis fuer USB-Audio-Eingang und Live-Transkription.
@main
struct ATCPhase0App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
