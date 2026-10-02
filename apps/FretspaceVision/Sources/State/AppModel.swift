import Foundation
import Observation
import simd
import MusicTheory
import FretboardKit

/// What the overlay is currently visualizing.
enum DisplayMode: String, CaseIterable, Identifiable {
    case scale = "Scale"
    case chord = "Chord"
    case triads = "Voicings"
    case chordInScale = "Chord + Scale"
    case exercise = "Exercise"

    var id: String { rawValue }
}

/// How note markers are labeled.
enum LabelStyle: String, CaseIterable, Identifiable {
    case none = "Dots"
    case noteNames = "Note names"
    case degrees = "Degrees"

    var id: String { rawValue }
}

enum CalibrationState: Equatable {
    case notCalibrated
    case placingNut
    case placingTwelfthFret(nutPoint: SIMD3<Float>)
    case calibrated(FretboardCalibration)

    var isCalibrated: Bool {
        if case .calibrated = self { return true }
        return false
    }

    var instruction: String? {
        switch self {
        case .notCalibrated: return nil
        case .placingNut: return "Pinch at the center of the NUT"
        case .placingTwelfthFret: return "Now pinch at the center of the 12th FRET"
        case .calibrated: return nil
        }
    }
}

@MainActor
@Observable
final class AppModel {
    // MARK: - Musical selection
    var displayMode: DisplayMode = .scale
    var root: PitchClass = .a
    var scaleType: ScaleType = .minorPentatonic
    var chordRoot: PitchClass = .a
    var chordQuality: ChordQuality = .minor
    var tuning: Tuning = .standard { didSet { persistSettings() } }
    var fretCount: Int = 22

    // MARK: - Display options
    var labelStyle: LabelStyle = .degrees { didSet { persistSettings() } }
    var showStringLines = true { didSet { persistSettings() } }
    var showFretLines = true { didSet { persistSettings() } }
    var leftHanded = false { didSet { persistSettings() } }
    /// Index into `boxStartFrets` limiting the scale to one position box;
    /// nil shows the full neck. Scale mode only.
    var selectedBoxIndex: Int? = nil

    // MARK: - Voicing study (triads & drop-2 sevenths)
    enum VoicingStyle: String, CaseIterable, Identifiable {
        case triads = "Triads"
        case drop2 = "Drop-2 7ths"
        case harmonized = "Harmonized"
        var id: String { rawValue }
    }

    var voicingStyle: VoicingStyle = .triads
    /// Index into `TriadVoicings.stringSets`; defaults to the top strings.
    var triadStringSetIndex = 3
    /// Index into `SeventhVoicings.stringSets`; defaults to the top four.
    var seventhStringSetIndex = 2
    /// nil shows all inversions at once, each a connected shape.
    var focusedInversion: TriadVoicing.Inversion? = nil
    var focusedSeventhInversion: SeventhVoicing.Inversion? = nil

    var triadStrings: [Int] {
        TriadVoicings.stringSets[
            TriadVoicings.stringSets.indices.contains(triadStringSetIndex)
                ? triadStringSetIndex : TriadVoicings.stringSets.count - 1
        ]
    }

    var seventhStrings: [Int] {
        SeventhVoicings.stringSets[
            SeventhVoicings.stringSets.indices.contains(seventhStringSetIndex)
                ? seventhStringSetIndex : SeventhVoicings.stringSets.count - 1
        ]
    }

    var triadVoicings: [TriadVoicing] {
        let all = TriadVoicings.inversions(of: chord, strings: triadStrings, on: fretboardModel)
        guard let focusedInversion else { return all }
        return all.filter { $0.inversion == focusedInversion }
    }

    var seventhVoicings: [SeventhVoicing] {
        let all = SeventhVoicings.drop2(of: chord, strings: seventhStrings, on: fretboardModel)
        guard let focusedSeventhInversion else { return all }
        return all.filter { $0.inversion == focusedSeventhInversion }
    }

    /// The scale's diatonic triad ladder on the selected 3-string set.
    var harmonizedTriads: [HarmonizedTriad] {
        HarmonizedScale.triadLadder(of: scale, strings: triadStrings, on: fretboardModel)
    }

    /// The voicing shapes the overlay currently studies; each group carries
    /// its own chord so tone roles color correctly (harmonized rungs are
    /// all different chords).
    var voicingGroups: [(chord: Chord, steps: [ExerciseStep])] {
        switch voicingStyle {
        case .triads: triadVoicings.map { ($0.chord, $0.steps) }
        case .drop2: seventhVoicings.map { ($0.chord, $0.steps) }
        case .harmonized: harmonizedTriads.map { ($0.chord, $0.voicing.steps) }
        }
    }

    /// Marker groups the overlay connects with lines (voicing shapes).
    var connectionGroups: [[FretPosition]] {
        displayMode == .triads ? voicingGroups.map { $0.steps.map(\.position) } : []
    }

    // MARK: - Error surface
    /// The one place user-visible failures land; ControlPanelView presents it.
    var presentedError: UserFacingError?

    init() {
        restoreSettings()
        listen.onError = { [weak self] error in self?.presentedError = error }
        listen.onNoteHit = { [weak self] in self?.exerciseNoteWasHit() }
    }

    // MARK: - Spatial state
    var calibration: CalibrationState = .notCalibrated
    var immersiveSpaceOpen = false {
        didSet {
            if immersiveSpaceOpen {
                practiceLog.beginSegment(displayMode.practiceMode)
            } else {
                practiceLog.endSegment()
            }
        }
    }

    // MARK: - Practice tracking
    let practiceLog = PracticeLog()

    /// Call when displayMode changes while a session is running so time is
    /// attributed to the mode actually practiced.
    func practiceModeDidChange() {
        guard immersiveSpaceOpen else { return }
        practiceLog.beginSegment(displayMode.practiceMode)
    }

    // MARK: - Listen mode (Phase 3 preview)
    let listen = ListenModeController()

    // MARK: - Backing track (Phase 2 preview)
    let backing = BackingTrackController()

    /// Chord/scale the overlay should actually show — the backing track takes
    /// over while it plays; manual selection otherwise.
    var activeChord: Chord {
        backing.isPlaying ? (backing.currentChord ?? chord) : chord
    }
    var activeScale: Scale {
        backing.isPlaying ? (backing.timeline?.key ?? scale) : scale
    }

    // MARK: - Exercise mode
    private(set) var exercise: Exercise?
    private(set) var exerciseIndex = 0
    /// How many upcoming steps to preview dimly on the board.
    var exerciseLookahead = 3

    var exerciseProgress: String? {
        exercise.map { "\(min(exerciseIndex + 1, $0.steps.count))/\($0.steps.count)" }
    }

    func startScaleRunExercise() {
        let start = boxStartFrets[safe: selectedBoxIndex ?? 1] ?? 5
        exercise = ExerciseGenerator.scaleRun(scale: scale, box: start, on: fretboardModel)
        exerciseIndex = 0
        displayMode = .exercise
        syncExerciseNoteTarget()
        overlayDidChange()
    }

    func startTriadDrillExercise() {
        exercise = ExerciseGenerator.triadInversions(
            chord: chord, strings: [3, 4, 5], on: fretboardModel)
        exerciseIndex = 0
        displayMode = .exercise
        syncExerciseNoteTarget()
        overlayDidChange()
    }

    func startThreeNPSExercise() {
        let start = boxStartFrets[safe: selectedBoxIndex ?? 1] ?? 5
        guard let generated = ExerciseGenerator.threeNotesPerString(
            scale: scale, startingAt: start, on: fretboardModel) else {
            AppLog.app.notice("3NPS pattern doesn't fit at fret \(start)")
            return
        }
        exercise = generated
        exerciseIndex = 0
        displayMode = .exercise
        syncExerciseNoteTarget()
        overlayDidChange()
    }

    func advanceExercise() {
        guard let exercise else { return }
        exerciseIndex = (exerciseIndex + 1) % exercise.steps.count
        syncExerciseNoteTarget()
        overlayDidChange()
    }

    func stopExercise() {
        exercise = nil
        exerciseIndex = 0
        listen.noteTarget = nil
        if displayMode == .exercise { displayMode = .scale }
        overlayDidChange()
    }

    /// Play-to-advance: while listening during an exercise, the current
    /// step's pitch class is the note target; a stable hit advances.
    private func syncExerciseNoteTarget() {
        guard listen.isListening, let exercise,
              exercise.steps.indices.contains(exerciseIndex) else {
            listen.noteTarget = nil
            return
        }
        listen.noteTarget = exercise.steps[exerciseIndex].note.pitchClass
    }

    private func exerciseNoteWasHit() {
        guard displayMode == .exercise, exercise != nil else { return }
        advanceExercise()
    }

    /// Re-sync the target when listen mode starts/stops mid-exercise.
    func listenStateDidChange() {
        syncExerciseNoteTarget()
    }

    // MARK: - Derived musical state
    var scale: Scale { Scale(root: root, type: scaleType) }
    var chord: Chord { Chord(root: chordRoot, quality: chordQuality) }
    var fretboardModel: FretboardModel { FretboardModel(tuning: tuning, fretCount: fretCount) }

    /// Starting frets of the five scale boxes up the neck (scale mode).
    var boxStartFrets: [Int] { fretboardModel.boxStartFrets(for: scale) }

    /// The highlights the overlay should currently render.
    var highlights: [FretboardHighlight] {
        switch displayMode {
        case .scale:
            if let boxIndex = selectedBoxIndex,
               boxStartFrets.indices.contains(boxIndex) {
                return fretboardModel.positionBox(for: scale, startingAt: boxStartFrets[boxIndex])
            }
            return fretboardModel.highlights(for: scale)
        case .chord:
            return fretboardModel.highlights(for: activeChord)
        case .triads:
            return voicingGroups.flatMap { group in
                group.steps.compactMap { step in
                    guard let tone = group.chord.tone(of: step.note.pitchClass) else { return nil }
                    return FretboardHighlight(position: step.position, note: step.note,
                                              role: .chordTone(tone))
                }
            }
        case .chordInScale:
            return fretboardModel.highlights(for: activeChord, within: activeScale)
        case .exercise:
            guard let exercise, !exercise.steps.isEmpty else { return [] }
            let upcoming = (0...exerciseLookahead).compactMap { offset -> FretboardHighlight? in
                let index = exerciseIndex + offset
                guard index < exercise.steps.count else { return nil }
                let step = exercise.steps[index]
                return FretboardHighlight(position: step.position, note: step.note,
                                          role: .exerciseStep(isCurrent: offset == 0))
            }
            // Later steps can revisit a position the current step occupies;
            // keep the current step's highlight in that case.
            var seen = Set<FretPosition>()
            return upcoming.filter { seen.insert($0.position).inserted }
        }
    }

    /// Geometry sized from calibration when available, defaults otherwise.
    var geometry: FretboardGeometry {
        if case .calibrated(let cal) = calibration {
            return cal.geometry(stringCount: tuning.stringCount,
                                fretCount: fretCount,
                                leftHanded: leftHanded)
        }
        return FretboardGeometry(stringCount: tuning.stringCount,
                                 fretCount: fretCount,
                                 leftHanded: leftHanded)
    }

    /// Monotonic value the RealityView update closure watches to know the
    /// overlay needs rebuilding. Bump-on-change keeps the diff cheap.
    private(set) var overlayRevision = 0

    func overlayDidChange() { overlayRevision += 1 }

    func startCalibration() { calibration = .placingNut }

    func recordCalibrationPoint(_ point: SIMD3<Float>, devicePosition: SIMD3<Float>) {
        switch calibration {
        case .placingNut:
            calibration = .placingTwelfthFret(nutPoint: point)
        case .placingTwelfthFret(let nutPoint):
            let candidate = FretboardCalibration(
                nutPoint: nutPoint,
                twelfthFretPoint: point,
                // The fretboard roughly faces the player's head while they
                // look down at the neck to calibrate.
                surfaceNormalHint: simd_normalize(devicePosition - nutPoint)
            )
            if candidate.isPlausible, candidate.transform != nil {
                calibration = .calibrated(candidate)
                AppLog.calibration.info("""
                    Calibrated: scale length \(candidate.scaleLength, format: .fixed(precision: 4)) m
                    """)
            } else {
                AppLog.calibration.error("""
                    Implausible calibration rejected: half-scale distance \
                    \(simd_distance(nutPoint, point), format: .fixed(precision: 3)) m
                    """)
                presentedError = .calibrationImplausible
                calibration = .placingNut // start over with guidance shown
            }
        case .notCalibrated, .calibrated:
            break
        }
        overlayDidChange()
    }
}

extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
    }
}

// MARK: - Settings persistence

extension AppModel {
    private static let settingsKey = "fretspace.displaySettings.v1"

    private struct PersistedSettings: Codable {
        var labelStyle: String
        var showStringLines: Bool
        var showFretLines: Bool
        var leftHanded: Bool
        var tuningName: String
    }

    func persistSettings() {
        let settings = PersistedSettings(
            labelStyle: labelStyle.rawValue,
            showStringLines: showStringLines,
            showFretLines: showFretLines,
            leftHanded: leftHanded,
            tuningName: tuning.name
        )
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(settings),
                                      forKey: Self.settingsKey)
        } catch {
            // Non-fatal: settings just won't survive relaunch.
            AppLog.app.error("Failed to persist settings: \(error)")
        }
    }

    private func restoreSettings() {
        guard let data = UserDefaults.standard.data(forKey: Self.settingsKey) else { return }
        do {
            let settings = try JSONDecoder().decode(PersistedSettings.self, from: data)
            labelStyle = LabelStyle(rawValue: settings.labelStyle) ?? .degrees
            showStringLines = settings.showStringLines
            showFretLines = settings.showFretLines
            leftHanded = settings.leftHanded
            tuning = Tuning.all.first { $0.name == settings.tuningName } ?? .standard
        } catch {
            AppLog.app.error("Failed to restore settings, using defaults: \(error)")
        }
    }
}
