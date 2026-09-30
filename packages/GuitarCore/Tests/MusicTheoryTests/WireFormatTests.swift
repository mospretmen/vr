import Foundation
import Testing
@testable import MusicTheory

/// Contract tests: these JSON fixtures are byte-for-byte what the backend
/// serves (see backend/src/tracks/repo.ts). If a Codable change here or a
/// wire-format change there breaks the contract, this suite fails.
@Suite("API wire format")
struct WireFormatTests {
    @Test func decodesTrackListPayload() throws {
        let json = """
        [
          {
            "id": "blues-a",
            "title": "12-Bar Blues in A",
            "artist": null,
            "bpm": 120,
            "key": { "root": 9, "type": { "name": "Blues", "intervals": [0, 3, 5, 6, 7, 10] } }
          },
          {
            "id": "ii-v-i-c",
            "title": "ii\u{2013}V\u{2013}I in C",
            "artist": null,
            "bpm": 120,
            "key": { "root": 0, "type": { "name": "Major (Ionian)", "intervals": [0, 2, 4, 5, 7, 9, 11] } }
          }
        ]
        """
        let tracks = try JSONDecoder().decode([TrackSummary].self, from: Data(json.utf8))
        #expect(tracks.count == 2)
        #expect(tracks[0].id == "blues-a")
        #expect(tracks[0].key == Scale(root: .a, type: .blues))
        #expect(tracks[1].key == Scale(root: .c, type: .major))
    }

    @Test func decodesTimelinePayloadIntoChordTimeline() throws {
        let json = """
        {
          "events": [
            {
              "startMs": 0,
              "durationMs": 2000,
              "chord": { "root": 9, "quality": { "name": "Dominant 7", "symbol": "7", "intervals": [0, 4, 7, 10] } }
            },
            {
              "startMs": 2000,
              "durationMs": 2000,
              "chord": { "root": 2, "quality": { "name": "Dominant 7", "symbol": "7", "intervals": [0, 4, 7, 10] } }
            }
          ],
          "key": { "root": 9, "type": { "name": "Blues", "intervals": [0, 3, 5, 6, 7, 10] } }
        }
        """
        let timeline = try JSONDecoder().decode(ChordTimeline.self, from: Data(json.utf8))
        #expect(timeline.events.count == 2)
        #expect(timeline.chord(atMs: 100) == Chord(root: .a, quality: .dominant7))
        #expect(timeline.chord(atMs: 2100) == Chord(root: .d, quality: .dominant7))
        #expect(timeline.key == Scale(root: .a, type: .blues))
        // Decoded qualities are interchangeable with the built-in presets.
        #expect(timeline.events[0].chord.quality == .dominant7)
    }

    @Test func timelineRoundTripsThroughItsOwnEncoding() throws {
        let original = ProgressionTemplate.twelveBarBlues(in: .e)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChordTimeline.self, from: data)
        #expect(decoded == original)
    }
}
