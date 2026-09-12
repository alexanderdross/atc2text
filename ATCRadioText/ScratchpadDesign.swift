import SwiftUI

/// Verfuegbare Darstellungen der Textausgabe.
///
/// CDU ist der Standard, Notizblock die alternative, hellere Schreibblock-Optik.
/// Die Auswahl wird in den Einstellungen umgeschaltet und ueber AppStorage
/// gespeichert.
enum ScratchpadStil: String, CaseIterable, Identifiable {
    case cdu
    case notizblock

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cdu: return "CDU"
        case .notizblock: return "Notizblock"
        }
    }
}

/// Farb- und Schriftpalette fuer einen Stil. Aus dem abgenommenen Mockup.
struct ScratchpadDesign {
    let hintergrund: Color
    let blatt: Color
    let vordergrund: Color
    let gedaempft: Color
    let akzent: Color
    let pegel: Color
    /// Rote Randlinie des Notizblocks. Bei CDU nil.
    let randlinie: Color?
    let trennlinie: Color
    let monospace: Bool
    let grossschrift: Bool
    let titel: String
    let untertitel: String

    var schrift: Font {
        .system(.body, design: monospace ? .monospaced : .default)
    }

    var fontDesign: Font.Design {
        monospace ? .monospaced : .default
    }

    static func fuer(_ stil: ScratchpadStil) -> ScratchpadDesign {
        switch stil {
        case .cdu:
            return ScratchpadDesign(
                hintergrund: Color(hex: 0x04100A),
                blatt: Color(hex: 0x05130C),
                vordergrund: Color(hex: 0x37F59A),
                gedaempft: Color(hex: 0x1F8A5A),
                akzent: Color(hex: 0xFFC64D),
                pegel: Color(hex: 0x37F59A),
                randlinie: nil,
                trennlinie: Color(hex: 0x37F59A).opacity(0.10),
                monospace: true,
                grossschrift: true,
                titel: "ATC SCRATCHPAD",
                untertitel: "LIVE TRANSCRIPT"
            )
        case .notizblock:
            return ScratchpadDesign(
                hintergrund: Color(hex: 0x0F151C),
                blatt: Color(hex: 0x131B24),
                vordergrund: Color(hex: 0xE8EEF4),
                gedaempft: Color(hex: 0x7D8B9A),
                akzent: Color(hex: 0x5FA8FF),
                pegel: Color(hex: 0x46C17D),
                randlinie: Color(hex: 0xE05A4D),
                trennlinie: Color.white.opacity(0.06),
                monospace: false,
                grossschrift: false,
                titel: "ATC Mitschrift",
                untertitel: "Live Transkript"
            )
        }
    }
}

extension Color {
    /// Erzeugt eine Farbe aus einem RGB-Hexwert, zum Beispiel 0x37F59A.
    init(hex: UInt32) {
        let rot = Double((hex >> 16) & 0xFF) / 255
        let gruen = Double((hex >> 8) & 0xFF) / 255
        let blau = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: rot, green: gruen, blue: blau, opacity: 1)
    }
}
