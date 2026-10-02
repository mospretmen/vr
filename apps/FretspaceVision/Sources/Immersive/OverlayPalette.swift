import SwiftUI
import MusicTheory

/// Central color language for the overlay. Chord tones and scale degrees get
/// distinct, consistent hues so muscle memory forms around color.
enum OverlayPalette {
    static func color(for role: HighlightRole) -> Color {
        switch role {
        case .chordTone(let tone):
            switch tone {
            case .root:     return .orange
            case .third:    return .cyan
            case .fifth:    return .green
            case .seventh:  return .purple
            case .extended: return .pink
            }
        case .scaleDegree(let degree):
            // Root pops; other degrees stay quiet so chord tones read instantly.
            return degree == 1 ? .orange : Color.white.opacity(0.55)
        case .exerciseStep(let isCurrent):
            return isCurrent ? .mint : Color.white.opacity(0.35)
        }
    }

    /// Marker radius in meters — chord tones slightly larger than scale context dots.
    static func radius(for role: HighlightRole) -> Float {
        switch role {
        case .chordTone(.root):              return 0.0065
        case .chordTone:                     return 0.0055
        case .scaleDegree(1):                return 0.0055
        case .scaleDegree:                   return 0.0042
        case .exerciseStep(isCurrent: true): return 0.0075
        case .exerciseStep:                  return 0.0042
        }
    }

    static func label(
        for highlight: FretboardHighlight,
        style: LabelStyle,
        scale: Scale? = nil
    ) -> String? {
        switch style {
        case .none:
            return nil
        case .noteNames:
            return highlight.note.pitchClass.name()
        case .degrees:
            switch highlight.role {
            case .scaleDegree(let d):
                // Spelled degrees (♭3, ♭7…) when the scale context is known.
                if let scale,
                   let spelled = Modes.degreeLabel(of: highlight.note.pitchClass, in: scale) {
                    return spelled
                }
                return "\(d)"
            case .chordTone(let tone):
                switch tone {
                case .root: return "R"
                case .third: return "3"
                case .fifth: return "5"
                case .seventh: return "7"
                case .extended: return "+"
                }
            case .exerciseStep(let isCurrent):
                return isCurrent ? highlight.note.pitchClass.name() : nil
            }
        }
    }
}
