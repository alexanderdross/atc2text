import SwiftUI

/// Oberflaeche der Phase-0-Test-App.
///
/// Zeigt die Textausgabe im Scratchpad-Stil. CDU ist der Standard, der
/// Notizblock-Stil laesst sich in den Einstellungen umschalten. Die Auswahl
/// bleibt ueber AppStorage erhalten.
struct ContentView: View {
    @State private var transcriber = LiveTranscriber()
    @AppStorage("scratchpadStil") private var stilRoh: String = ScratchpadStil.cdu.rawValue
    @AppStorage("crtEffekt") private var crtEffekt: Bool = true
    @AppStorage("demoDaten") private var demoDaten: Bool = false
    @State private var zeigeEinstellungen = false

    private var stil: ScratchpadStil { ScratchpadStil(rawValue: stilRoh) ?? .cdu }
    private var design: ScratchpadDesign { .fuer(stil) }

    /// Beispiel-Mitschrift zur Vorschau der Phase-1-Darstellung mit Sprecher und
    /// Rufzeichen. Kein Live-Transkript.
    private var demoZeilen: [Transkriptzeile] {
        let jetzt = Date()
        let roh: [(offset: TimeInterval, sprecher: Sprecher, text: String, rz: String?)] = [
            (-196, .atc, "D-EABC, Langen Information, radar contact, QNH 1013", "D-EABC"),
            (-190, .eigen, "QNH 1013, D-EABC", "D-EABC"),
            (-165, .atc, "D-EABC, traffic 2 o'clock, 3 miles, opposite direction", "D-EABC"),
            (-158, .eigen, "Looking for traffic, ABC", "ABC"),
            (-96, .atc, "ABC, steigen Sie Flugflaeche 75, direkt KEMPTEN", "ABC"),
            (-89, .eigen, "Climb FL75, direct KEMPTEN, ABC", "ABC"),
            (-12, .atc, "D-EABC, contact Muenchen Radar 128.955, servus", "D-EABC")
        ]
        return roh.map { eintrag in
            Transkriptzeile(
                zeit: jetzt.addingTimeInterval(eintrag.offset),
                text: eintrag.text,
                sprecher: eintrag.sprecher,
                rufzeichen: eintrag.rz
            )
        }
    }

    private var anzuzeigendeZeilen: [Transkriptzeile] {
        demoDaten ? demoZeilen : transcriber.zeilen
    }

    var body: some View {
        ZStack {
            design.hintergrund.ignoresSafeArea()

            VStack(spacing: 12) {
                kopf
                statusZeile
                blatt
                aufnahmeKnopf
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            EinstellungenView(stilRoh: $stilRoh, crtEffekt: $crtEffekt, demoDaten: $demoDaten)
        }
    }

    // MARK: Kopf

    private var kopf: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(design.titel)
                    .font(.system(.title3, design: design.fontDesign).weight(.bold))
                    .foregroundStyle(design.vordergrund)
                Text(design.untertitel)
                    .font(.caption)
                    .foregroundStyle(design.gedaempft)
            }
            Spacer()
            if transcriber.laeuft {
                HStack(spacing: 6) {
                    PulsPunkt(farbe: Color(hex: 0xFF4D4D))
                        .frame(width: 9, height: 9)
                    Text("REC")
                        .font(.system(size: 11, design: .monospaced).weight(.semibold))
                        .foregroundStyle(design.gedaempft)
                }
            }
            Button {
                zeigeEinstellungen = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(design.gedaempft)
            }
            .padding(.leading, 8)
        }
    }

    // MARK: Eingang und Pegel

    private var statusZeile: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "cable.connector")
                        .font(.system(size: 12))
                    Text(transcriber.eingangsName)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(design.vordergrund)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(design.vordergrund.opacity(0.08), in: Capsule())

                HStack(spacing: 8) {
                    Text("PEGEL")
                        .font(.system(size: 10))
                        .foregroundStyle(design.gedaempft)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(design.vordergrund.opacity(0.14))
                            Capsule()
                                .fill(design.pegel)
                                .frame(width: geo.size.width * CGFloat(transcriber.eingangsPegel))
                        }
                    }
                    .frame(height: 6)
                }
            }

            Text(transcriber.statusText)
                .font(.caption2)
                .foregroundStyle(design.gedaempft)
        }
    }

    // MARK: Textausgabe

    private var blatt: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if demoDaten {
                        Text("Beispieldaten, keine Live-Aufnahme")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(design.akzent)
                            .padding(.vertical, 8)
                    } else if transcriber.zeilen.isEmpty && transcriber.teilTranskript.isEmpty {
                        Text("noch kein Text")
                            .font(design.schrift)
                            .foregroundStyle(design.gedaempft)
                            .padding(.vertical, 10)
                    }

                    ForEach(anzuzeigendeZeilen) { zeile in
                        ZeileView(zeile: zeile, design: design)
                    }

                    if !demoDaten, !transcriber.teilTranskript.isEmpty {
                        ZeileView(
                            zeile: Transkriptzeile(zeit: Date(), text: transcriber.teilTranskript),
                            design: design,
                            vorlaeufig: true
                        )
                    }

                    if stil == .cdu {
                        HStack(spacing: 8) {
                            Text(">")
                                .font(design.schrift)
                                .foregroundStyle(design.akzent)
                            BlinkCursor(farbe: design.akzent)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }

                    Color.clear.frame(height: 1).id("ende")
                }
                .padding(.vertical, 8)
                .padding(.trailing, 14)
                .padding(.leading, stil == .notizblock ? 46 : 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: transcriber.zeilen.count) { _, _ in
                withAnimation { proxy.scrollTo("ende", anchor: .bottom) }
            }
            .onChange(of: transcriber.teilTranskript) { _, _ in
                proxy.scrollTo("ende", anchor: .bottom)
            }
        }
        .background {
            ZStack(alignment: .topLeading) {
                design.blatt
                if let randlinie = design.randlinie {
                    randlinie
                        .opacity(0.85)
                        .frame(width: 2)
                        .padding(.leading, 34)
                }
            }
        }
        .overlay {
            if stil == .cdu && crtEffekt {
                ScanlineOverlay()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Aufnahme-Knopf

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
            Text(knopfText)
                .font(design.schrift.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(knopfVordergrund)
                .background(knopfHintergrund, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(knopfRand, lineWidth: 1.5)
                }
        }
    }

    private var knopfText: String {
        if transcriber.laeuft {
            return stil == .cdu ? "STOP" : "Aufnahme stoppen"
        } else {
            return stil == .cdu ? "AUFNAHME STARTEN" : "Aufnahme starten"
        }
    }

    private var knopfVordergrund: Color {
        switch stil {
        case .cdu:
            return design.vordergrund
        case .notizblock:
            return .white
        }
    }

    private var knopfHintergrund: Color {
        switch stil {
        case .cdu:
            return .clear
        case .notizblock:
            return transcriber.laeuft ? Color(hex: 0xE05A4D) : design.akzent
        }
    }

    private var knopfRand: Color {
        stil == .cdu ? design.vordergrund : .clear
    }
}

/// Eine einzelne Zeile der Textausgabe.
struct ZeileView: View {
    let zeile: Transkriptzeile
    let design: ScratchpadDesign
    var vorlaeufig: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(zeile.zeit, format: .dateTime.hour().minute().second())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(design.gedaempft)

            if let sprecher = zeile.sprecher {
                Text(sprecher == .atc ? "ATC" : "TX")
                    .font(.system(size: 10, design: .monospaced).weight(.semibold))
                    .foregroundStyle(sprecher == .atc ? design.gedaempft : design.akzent)
                    .frame(width: 28, alignment: .leading)
            }

            Text(inhalt)
                .font(design.schrift)
                .textCase(design.grossschrift ? .uppercase : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(design.trennlinie)
                .frame(height: 1)
        }
    }

    /// Text der Zeile. Hebt ab Phase 1 ein erkanntes Rufzeichen im Akzent hervor.
    private var inhalt: AttributedString {
        var text = AttributedString(zeile.text)
        text.foregroundColor = vorlaeufig ? design.gedaempft : design.vordergrund
        if let rufzeichen = zeile.rufzeichen, let bereich = text.range(of: rufzeichen) {
            text[bereich].foregroundColor = design.akzent
        }
        return text
    }
}

/// Einstellungen. Umschalten des Textausgabe-Stils.
struct EinstellungenView: View {
    @Binding var stilRoh: String
    @Binding var crtEffekt: Bool
    @Binding var demoDaten: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Darstellung der Textausgabe") {
                    Picker("Design", selection: $stilRoh) {
                        ForEach(ScratchpadStil.allCases) { stil in
                            Text(stil.name).tag(stil.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Toggle("CRT-Scanlines", isOn: $crtEffekt)
                } footer: {
                    Text("Dezente Zeilenraster ueber der Ausgabe. Wirkt nur im CDU-Stil.")
                }

                Section {
                    Toggle("Beispieldaten anzeigen", isOn: $demoDaten)
                } footer: {
                    Text("Zeigt eine Beispiel-Mitschrift mit Sprecher-Kennung und hervorgehobenem Rufzeichen. Nur zur Ansicht der spaeteren Phase-1-Darstellung, keine echte Transkription.")
                }

                Section {
                    Text("CDU ist die Standarddarstellung im avionischen Gruen. Notizblock ist die alternative, hellere Schreibblock-Optik.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

/// Dezente CRT-Scanlines fuer die CDU-Optik. Nur Zierde, ohne Interaktion.
struct ScanlineOverlay: View {
    var body: some View {
        Canvas { kontext, groesse in
            let abstand: CGFloat = 3
            var y: CGFloat = 0
            while y < groesse.height {
                let linie = CGRect(x: 0, y: y, width: groesse.width, height: 1)
                kontext.fill(Path(linie), with: .color(.black.opacity(0.16)))
                y += abstand
            }
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

/// Blinkender Cursor fuer die CDU-Editierzeile.
struct BlinkCursor: View {
    let farbe: Color
    @State private var an = true

    var body: some View {
        Rectangle()
            .fill(farbe)
            .frame(width: 9, height: 16)
            .opacity(an ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    an = false
                }
            }
    }
}

/// Pulsierender Punkt fuer die Aufnahmeanzeige.
struct PulsPunkt: View {
    let farbe: Color
    @State private var sichtbar = true

    var body: some View {
        Circle()
            .fill(farbe)
            .opacity(sichtbar ? 1 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    sichtbar = false
                }
            }
    }
}

#Preview {
    ContentView()
}
