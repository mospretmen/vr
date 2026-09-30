import RealityKit
import SwiftUI
import MusicTheory
import FretboardKit

/// The "chord aura": particles emanating from the guitar body when a chord
/// sounds in listen mode. Color language follows chord quality; intensity
/// follows recognition confidence (a proxy for playing dynamics until
/// per-frame RMS is plumbed through).
@MainActor
enum ChordAuraEntity {
    /// Approximate soundhole position in local fretboard space: a bit past
    /// the end of the neck, centered. Good enough until body anchoring exists.
    static func emitterPosition(geometry: FretboardGeometry) -> SIMD3<Float> {
        SIMD3<Float>(Float(geometry.scaleLength * 0.78), 0, 0)
    }

    static func make(for chord: Chord, geometry: FretboardGeometry, intensity: Float) -> Entity {
        let entity = Entity()
        entity.name = "chordAura"
        entity.position = emitterPosition(geometry: geometry)

        var particles = ParticleEmitterComponent()
        particles.emitterShape = .sphere
        particles.emitterShapeSize = SIMD3<Float>(repeating: 0.06)
        particles.birthLocation = .surface
        particles.mainEmitter.birthRate = 250 * intensity
        particles.mainEmitter.lifeSpan = 1.2
        particles.mainEmitter.size = 0.004
        particles.mainEmitter.spreadingAngle = .pi
        particles.speed = 0.12 * intensity
        particles.mainEmitter.dampingFactor = 2.0
        particles.mainEmitter.color = .evolving(
            start: .single(UIColor(color(for: chord.quality))),
            end: .single(UIColor(color(for: chord.quality)).withAlphaComponent(0))
        )
        entity.components.set(particles)
        return entity
    }

    /// Emotional color language per quality — warm for major, cool for minor,
    /// amber for dominants, violet for the tense qualities.
    static func color(for quality: ChordQuality) -> Color {
        switch quality {
        case .major, .major7:            .orange
        case .minor, .minor7:            .indigo
        case .dominant7:                 .yellow
        case .diminished, .diminished7,
             .minor7b5:                  .purple
        case .augmented:                 .red
        default:                         .teal
        }
    }
}
