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
    case placingEdge(nutPoint: SIMD3<Float>, twelfthPoint: SIMD3<Float>)
    case calibrated(FretboardCalibration)

    var isCalibrated: Bool {
        if case .calibrated = self { return true }
        return false
    }

    var isPlacing: Bool {
        switch self {
        case .placingNut, .placingTwelfthFret, .placingEdge: return true
        case .notCalibrated, .calibrated: return false
        }
    }

    var instruction: String? {
        switch self {
        case .notCalibrated: return nil
        case .placingNut:
            return "Pinch and HOLD on the center of the NUT, then release"
        case .placingTwelfthFret:
            return "Pinch and HOLD on the center of the 12th FRET"
        case .placingEdge:
            return "Pinch and HOLD on the board's edge by the THINNEST string"
        case .calibrated: return nil
        }
    }
}

/// Which calibration point an adjust-mode drag is moving.
enum CalibrationHandle: Equatable {
    case nut, twelfth, edge
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
    /// Violet-tint the degrees that differ from the parallel major.
    var emphasizeAlterations = true { didSet { persistSettings() } }
    /// Index into `boxStartFrets` limiting the scale to one position box;
    /// nil shows the full neck. Scale mode only.
    var selectedBoxIndex: Int? = nil

    // MARK: - Voicing study (triads & drop-2 sevenths)
    enum VoicingStyle: String, CaseIterable, Identifiable {
        case triads = "Triads"
        case drop2 = "Drop-2 7ths"
        case harmonized = "Harmonized Ladder"
        case open = "Open Shapes"
        var id: String { rawValue }
    }

    var voicingStyle: VoicingStyle = .triads { didSet { persistSettings() } }
    /// Index into `TriadVoicings.stringSets`; defaults to the top strings.
    var triadStringSetIndex = 3 { didSet { persistSettings() } }
    /// Index into `SeventhVoicings.stringSets`; defaults to the top four.
    var seventhStringSetIndex = 2 { didSet { persistSettings() } }
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
        case .open:
            OpenChords.shapes(for: chord).map { shape in
                (shape.chord, shape.positions.map { position in
                    ExerciseStep(position: position, note: fretboardModel.note(at: position))
                })
            }
        }
    }

    /// Marker groups the overlay connects with lines (voicing shapes).
    var connectionGroups: [[FretPosition]] {
        displayMode == .triads ? voicingGroups.map { $0.steps.map(\.position) } : []
    }

    /// One caption per voicing shape, for the chart panel strip.
    var voicingCaptions: [String] {
        switch voicingStyle {
        case .triads:
            triadVoicings.map { "\($0.inversion.label) · fret \($0.lowestFret)" }
        case .drop2:
            seventhVoicings.map { "\($0.inversion.label) · fret \($0.lowestFret)" }
        case .harmonized:
            harmonizedTriads.map { "\($0.romanNumeral) \($0.chord.symbol) · fret \($0.voicing.lowestFret)" }
        case .open:
            OpenChords.shapes(for: chord).map(\.name)
        }
    }

    // MARK: - Board placement (the one fretboard, two possible homes)
    enum BoardPlacement: String, CaseIterable, Identifiable {
        case floating = "Floating"
        case onGuitar = "On guitar"
        var id: String { rawValue }
    }

    /// Where the fretboard visualization lives. Floating is the performance
    /// default; On guitar is the calibrated study mode. Never both at once.
    var boardPlacement: BoardPlacement = .floating
    /// Glow the current chord's 3rd & 7th as voice-leading targets.
    var stageGuideTones = true
    /// Recess scale notes a semitone above a chord tone (classic avoid notes).
    var stageAvoidDimming = true

    /// Guide/avoid layers only make sense when a chord context is on screen.
    var stageShowsChordContext: Bool {
        switch displayMode {
        case .chord, .chordInScale: return true
        case .scale, .triads, .exercise: return false
        }
    }

    /// Pitch classes of the voice-leading guide tones (3rd, and 7th if any).
    var guideTonePitchClasses: Set<PitchClass> {
        let intervals = activeChord.quality.intervals
        var tones: Set<PitchClass> = []
        if intervals.count >= 2 { tones.insert(activeChord.root.transposed(by: intervals[1])) }
        if intervals.count >= 4 { tones.insert(activeChord.root.transposed(by: intervals[3])) }
        return tones
    }

    /// Scale notes sitting a semitone above a chord tone — the classic
    /// "avoid note" heuristic (e.g. the 4 over a major chord).
    var avoidPitchClasses: Set<PitchClass> {
        let chordTones = Set(activeChord.pitchClasses)
        return Set(activeScale.pitchClasses.filter { pc in
            !chordTones.contains(pc) && chordTones.contains(pc.transposed(by: -1))
        })
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

    /// Turn whatever the Voicings mode is showing into a step-through drill
    /// (works for triads, drop-2, and the harmonized ladder alike).
    func startVoicingDrillExercise() {
        let steps = voicingGroups.flatMap(\.steps)
        guard !steps.isEmpty else { return }
        let name: String = switch voicingStyle {
        case .triads: "\(chord.symbol) triads — \(voicingStyle.rawValue)"
        case .drop2: "\(chord.symbol) drop-2 voicings"
        case .harmonized: "\(scale.name) harmonized ladder"
        case .open: "\(chord.symbol) open shape"
        }
        exercise = Exercise(name: name, steps: steps)
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

    func startCalibration() {
        calibration = .placingNut
        overlayDidChange()
    }

    func cancelCalibration() {
        calibration = .notCalibrated
        overlayDidChange()
    }

    func recordCalibrationPoint(_ point: SIMD3<Float>, devicePosition: SIMD3<Float>) {
        switch calibration {
        case .placingNut:
            calibration = .placingTwelfthFret(nutPoint: point)
        case .placingTwelfthFret(let nutPoint):
            // Validate the neck length before asking for the edge pinch.
            let half = simd_distance(nutPoint, point)
            if half > 0.15 && half < 0.60 {
                calibration = .placingEdge(nutPoint: nutPoint, twelfthPoint: point)
            } else {
                AppLog.calibration.error("""
                    Implausible neck length rejected: half-scale \
                    \(half, format: .fixed(precision: 3)) m
                    """)
                presentedError = .calibrationImplausible
                calibration = .placingNut
            }
        case .placingEdge(let nutPoint, let twelfthPoint):
            let candidate = FretboardCalibration(
                nutPoint: nutPoint,
                twelfthFretPoint: twelfthPoint,
                // Head position still disambiguates which side was pinched.
                surfaceNormalHint: simd_normalize(devicePosition - nutPoint),
                edgePoint: point
            )
            if candidate.isPlausible, candidate.transform != nil {
                calibration = .calibrated(candidate)
                AppLog.calibration.info("""
                    Calibrated (3-point): scale length \
                    \(candidate.scaleLength, format: .fixed(precision: 4)) m
                    """)
            } else {
                AppLog.calibration.error("Edge point degenerate; restarting calibration")
                presentedError = .calibrationImplausible
                calibration = .placingNut
            }
        case .notCalibrated, .calibrated:
            break
        }
        overlayDidChange()
    }

    // MARK: - Overlay adjust mode

    /// When on, the immersive view shows grab handles at the calibration
    /// points; pinch-dragging one refines the overlay against the real neck.
    var adjustingCalibration = false

    /// Current world positions of the adjustable handles.
    var calibrationHandles: [(handle: CalibrationHandle, position: SIMD3<Float>)] {
        guard case .calibrated(let cal) = calibration else { return [] }
        var handles: [(handle: CalibrationHandle, position: SIMD3<Float>)] = [
            (handle: .nut, position: cal.nutPoint),
            (handle: .twelfth, position: cal.twelfthFretPoint),
        ]
        if let edge = cal.edgePoint {
            handles.append((handle: .edge, position: edge))
        }
        return handles
    }

    /// Move one calibration point (live during an adjust drag). Rebuild is
    /// debounced by the caller; the transform updates cheaply every sample.
    func moveCalibrationPoint(_ handle: CalibrationHandle, to point: SIMD3<Float>) {
        guard case .calibrated(var cal) = calibration else { return }
        switch handle {
        case .nut: cal.nutPoint = point
        case .twelfth: cal.twelfthFretPoint = point
        case .edge: cal.edgePoint = point
        }
        if cal.transform != nil {
            calibration = .calibrated(cal)
        }
    }

    func finishAdjustDrag() {
        AppLog.calibration.info("Adjust drag committed")
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
        // Added after v1 shipped to devices would need migration; optionals
        // keep older payloads decodable.
        var voicingStyle: String?
        var triadStringSetIndex: Int?
        var seventhStringSetIndex: Int?
        var emphasizeAlterations: Bool?
    }

    func persistSettings() {
        let settings = PersistedSettings(
            labelStyle: labelStyle.rawValue,
            showStringLines: showStringLines,
            showFretLines: showFretLines,
            leftHanded: leftHanded,
            tuningName: tuning.name,
            voicingStyle: voicingStyle.rawValue,
            triadStringSetIndex: triadStringSetIndex,
            seventhStringSetIndex: seventhStringSetIndex,
            emphasizeAlterations: emphasizeAlterations
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
            if let style = settings.voicingStyle.flatMap(VoicingStyle.init(rawValue:)) {
                voicingStyle = style
            }
            if let index = settings.triadStringSetIndex,
               TriadVoicings.stringSets.indices.contains(index) {
                triadStringSetIndex = index
            }
            if let index = settings.seventhStringSetIndex,
               SeventhVoicings.stringSets.indices.contains(index) {
                seventhStringSetIndex = index
            }
            if let emphasize = settings.emphasizeAlterations {
                emphasizeAlterations = emphasize
            }
        } catch {
            AppLog.app.error("Failed to restore settings, using defaults: \(error)")
        }
    }
}
