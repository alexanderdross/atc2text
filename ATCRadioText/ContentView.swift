import SwiftUI

/// Minimaloberflaeche der Phase-0-Test-App.
///
/// Zeigt aktiven Eingang, Pegel und das Live-Transkript. Ein Knopf startet und
/// stoppt die Aufnahme. Mehr braucht der Machbarkeitsnachweis nicht.
struct ContentView: View {
    @State private var transcriber = LiveTranscriber()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                statusBereich
                pegelBereich
                transkriptBereich
                Spacer()
                aufnahmeKnopf
            }
            .padding()
            .navigationTitle("ATC Phase 0")
        }
    }

    private var statusBereich: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Eingang")
                    .font(.headline)
                Spacer()
                Text(transcriber.eingangsName)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Status")
                    .font(.headline)
                Spacer()
                Text(transcriber.statusText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pegelBereich: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pegel")
                .font(.headline)
            ProgressView(value: Double(transcriber.eingangsPegel))
                .progressViewStyle(.linear)
        }
    }

    private var transkriptBereich: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Transkript")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(transcriber.transkript.isEmpty ? "noch kein Text" : transcriber.transkript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !transcriber.teilTranskript.isEmpty {
                        Text(transcriber.teilTranskript)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
    }

    private var aufnahmeKnopf: some View {
        Button {
            Task {
                if transcriber.laeuft {
                    await transcriber.stop()
                } else {
                    await transcriber.start()
                }
            }
        } label: {
            Text(transcriber.laeuft ? "Stoppen" : "Aufnahme starten")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(transcriber.laeuft ? .red : .accentColor)
    }
}

#Preview {
    ContentView()
}
