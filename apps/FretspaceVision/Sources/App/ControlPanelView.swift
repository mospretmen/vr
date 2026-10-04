import SwiftUI
import MusicTheory

/// The main floating window: musical selection, display options, and the
/// calibration + immersive-space lifecycle controls.
///
/// Every section lives in its own small view/property — the one-big-Form
/// version exceeded the Swift type-checker's expression budget.
struct ControlPanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @State private var showTrackLibrary = false

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                voicingsSection
                scaleSection
                chordSection
                displaySection
                guitarSection
                backingSection
                exerciseSection
                listenSection
                panelFooterSection
            }
            .navigationTitle("Fretspace")
            .sheet(isPresented: $showTrackLibrary) {
                TrackLibraryView()
            }
        }
        .modifier(OverlayInvalidation(model: model))
        .modifier(ErrorAlert(model: model))
    }

    // MARK: - Sections

    private var modeSection: some View {
        @Bindable var model = model
        return Section("Mode") {
            Picker("Display", selection: $model.displayMode) {
                ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var voicingsSection: some View {
        @Bindable var model = model
        if model.displayMode == .triads {
            Section {
                Picker("Style", selection: $model.voicingStyle) {
                    ForEach(AppModel.VoicingStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                voicingStylePickers
                Button("Drill These Voicings") { model.startVoicingDrillExercise() }
                    .disabled(model.voicingGroups.isEmpty)
            } header: {
                Label("Voicings", systemImage: "triangle")
            } footer: {
                voicingsFooter
            }
        }
    }

    @ViewBuilder
    private var voicingStylePickers: some View {
        @Bindable var model = model
        switch model.voicingStyle {
        case .triads:
            triadStringsPicker
            Picker("Inversion", selection: $model.focusedInversion) {
                Text("All three").tag(TriadVoicing.Inversion?.none)
                ForEach(TriadVoicing.Inversion.allCases) { inversion in
                    Text(inversion.label).tag(TriadVoicing.Inversion?.some(inversion))
                }
            }
        case .drop2:
            Picker("Strings", selection: $model.seventhStringSetIndex) {
                ForEach(Array(SeventhVoicings.stringSets.enumerated()), id: \.offset) { index, set in
                    Text(stringSetLabel(set)).tag(index)
                }
            }
            Picker("Inversion", selection: $model.focusedSeventhInversion) {
                Text("All four").tag(SeventhVoicing.Inversion?.none)
                ForEach(SeventhVoicing.Inversion.allCases) { inversion in
                    Text(inversion.label).tag(SeventhVoicing.Inversion?.some(inversion))
                }
            }
        case .harmonized:
            RootNotePicker(title: "Key", selection: $model.root)
            Picker("Scale", selection: $model.scaleType) {
                ForEach(ScaleType.all, id: \.self) { Text($0.name).tag($0) }
            }
            triadStringsPicker
        case .open:
            EmptyView() // chord pickers below are all it needs
        }
    }

    private var triadStringsPicker: some View {
        @Bindable var model = model
        return Picker("Strings", selection: $model.triadStringSetIndex) {
            ForEach(Array(TriadVoicings.stringSets.enumerated()), id: \.offset) { index, set in
                Text(stringSetLabel(set)).tag(index)
            }
        }
    }

    @ViewBuilder
    private var voicingsFooter: some View {
        if model.voicingStyle == .drop2, model.chordQuality.intervals.count < 4 {
            Text("Pick a seventh quality (maj7, 7, m7, m7♭5, °7) to see drop-2 shapes.")
        } else if model.voicingStyle == .harmonized {
            if model.harmonizedTriads.isEmpty {
                Text("Harmonization needs a seven-note scale.")
            } else {
                Text(model.harmonizedTriads
                    .map { "\($0.romanNumeral) \($0.chord.symbol)" }
                    .joined(separator: "  ·  "))
            }
        } else if model.voicingStyle == .open, model.voicingGroups.isEmpty {
            Text("No open shape for \(model.chord.symbol) — "
                 + "try Triads or Drop-2 for a movable grip.")
        }
    }

    @ViewBuilder
    private var scaleSection: some View {
        @Bindable var model = model
        if model.displayMode != .chord && model.displayMode != .triads {
            Section {
                RootNotePicker(title: "Root", selection: $model.root)
                Picker("Scale", selection: $model.scaleType) {
                    ForEach(ScaleType.all, id: \.self) { Text($0.name).tag($0) }
                }
                if model.displayMode == .scale {
                    Picker("Position", selection: $model.selectedBoxIndex) {
                        Text("Full neck").tag(Int?.none)
                        ForEach(Array(model.boxStartFrets.enumerated()), id: \.offset) { index, fret in
                            Text("Box \(index + 1) (fret \(fret))").tag(Int?.some(index))
                        }
                    }
                }
            } header: {
                Label("Scale", systemImage: "music.note.list")
            } footer: {
                if let summary = Modes.summary(of: model.scale) {
                    Text(summary)
                }
            }
        }
    }

    @ViewBuilder
    private var chordSection: some View {
        @Bindable var model = model
        if model.displayMode != .scale,
           !(model.displayMode == .triads && model.voicingStyle == .harmonized) {
            Section {
                RootNotePicker(title: "Chord root", selection: $model.chordRoot)
                Picker("Quality", selection: $model.chordQuality) {
                    ForEach(ChordQuality.all, id: \.self) { Text($0.name).tag($0) }
                }
            } header: {
                Label("Chord", systemImage: "pianokeys")
            }
        }
    }

    private var displaySection: some View {
        @Bindable var model = model
        return Section(header: Label("Display", systemImage: "slider.horizontal.3")) {
            Picker("Labels", selection: $model.labelStyle) {
                ForEach(LabelStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("String lines", isOn: $model.showStringLines)
            Toggle("Fret lines", isOn: $model.showFretLines)
            Toggle("Left-handed", isOn: $model.leftHanded)
            Toggle("Color altered degrees", isOn: $model.emphasizeAlterations)
            Picker("Tuning", selection: $model.tuning) {
                ForEach(Tuning.all, id: \.self) { Text($0.name).tag($0) }
            }
        }
    }

    private var guitarSection: some View {
        Section(header: Label("Guitar", systemImage: "guitars")) {
            immersiveControls
        }
    }

    private var backingSection: some View {
        Section(header: Label("Backing Track", systemImage: "metronome")) {
            if let timeline = model.backing.timeline {
                LabeledContent("Track", value: model.backing.title)
                LabeledContent("Now", value: model.backing.currentChord?.symbol ?? "—")
                if let next = model.backing.upcoming {
                    LabeledContent("Next", value: next.chord.symbol)
                }
                HStack {
                    Button(model.backing.isPlaying ? "Pause" : "Play") {
                        if model.backing.isPlaying {
                            model.backing.pause()
                        } else {
                            model.displayMode = .chordInScale
                            model.backing.play()
                        }
                    }
                    Button("Stop", role: .destructive) { model.backing.stop() }
                    Button("Eject") { model.backing.eject() }
                }
                ProgressView(value: Double(model.backing.positionMs),
                             total: Double(timeline.durationMs))
                MetronomeToggle(backing: model.backing)
            } else {
                Button("Browse Backing Tracks") { showTrackLibrary = true }
            }
        }
    }

    private var exerciseSection: some View {
        Section(header: Label("Exercise", systemImage: "list.number")) {
            if let progress = model.exerciseProgress {
                LabeledContent("Step", value: progress)
                Button("Next Step") { model.advanceExercise() }
                Button("Stop Exercise", role: .destructive) { model.stopExercise() }
            } else {
                Button("Scale Run in Current Box") { model.startScaleRunExercise() }
                Button("3-Notes-Per-String Pattern") { model.startThreeNPSExercise() }
                Button("Triad Drill on Top Strings") { model.startTriadDrillExercise() }
            }
            if model.exercise != nil, !model.listen.isListening {
                Text("Tip: start Listen mode and steps advance when you play the target note.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var listenSection: some View {
        Section(header: Label("Listen", systemImage: "ear")) {
            if model.listen.isListening {
                LabeledContent("Hearing", value: model.listen.detectedChord?.symbol ?? "—")
                Button("Stop Listening") {
                    model.listen.stop()
                    model.listenStateDidChange()
                }
            } else {
                Button("Start Listening") {
                    Task {
                        await model.listen.start()
                        model.listenStateDidChange()
                    }
                }
            }
        }
    }

    private var panelFooterSection: some View {
        Section {
            Button("Open Notation Panel") { openWindow(id: SceneID.notation) }
        } footer: {
            let summary = model.practiceLog.summary
            if summary.sessionCount > 0 {
                Text("Streak: \(summary.currentStreakDays) day(s) · "
                     + "Total practice: \(Self.formatted(summary.totalTime))")
            }
        }
    }

    @ViewBuilder
    private var immersiveControls: some View {
        @Bindable var model = model
        if !model.immersiveSpaceOpen {
            Button("Start Session") {
                Task { await openImmersiveSpace(id: SceneID.immersive) }
            }
        } else {
            if let instruction = model.calibration.instruction {
                Label(instruction, systemImage: "hand.pinch")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            switch model.calibration {
            case .notCalibrated:
                Button("Calibrate to My Guitar") { model.startCalibration() }
            case .placingNut, .placingTwelfthFret, .placingEdge:
                Button("Cancel Calibration", role: .cancel) {
                    model.cancelCalibration()
                }
            case .calibrated(let cal):
                LabeledContent("Scale length",
                               value: String(format: "%.1f\u{2033}", cal.scaleLength / 0.0254))
                Toggle("Adjust overlay", isOn: $model.adjustingCalibration)
                if model.adjustingCalibration {
                    Text("Pinch-hold a cyan handle and drag it until the overlay "
                         + "sits on your real frets. Release to lock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Recalibrate") { model.startCalibration() }
            }

            Button("End Session", role: .destructive) {
                Task { await dismissImmersiveSpace() }
            }
        }
    }

    // MARK: - Helpers

    private static func formatted(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// "G · B · E" style label for a string set, from the active tuning.
    private func stringSetLabel(_ set: [Int]) -> String {
        set.map { model.tuning.openStrings[$0].pitchClass.name() }
            .joined(separator: " · ")
    }
}

/// All the "model changed → rebuild overlay" plumbing in one modifier,
/// keeping the body expression small.
private struct OverlayInvalidation: ViewModifier {
    let model: AppModel

    func body(content: Content) -> some View {
        content
            .onChange(of: model.root) { model.overlayDidChange() }
            .onChange(of: model.scaleType) { model.overlayDidChange() }
            .onChange(of: model.chordRoot) { model.overlayDidChange() }
            .onChange(of: model.chordQuality) { model.overlayDidChange() }
            .onChange(of: model.tuning) { model.overlayDidChange() }
            .onChange(of: model.displayMode) {
                model.overlayDidChange()
                model.practiceModeDidChange()
            }
            .onChange(of: model.selectedBoxIndex) { model.overlayDidChange() }
            .onChange(of: model.leftHanded) { model.overlayDidChange() }
            .onChange(of: model.emphasizeAlterations) { model.overlayDidChange() }
            .onChange(of: model.triadStringSetIndex) { model.overlayDidChange() }
            .onChange(of: model.focusedInversion) { model.overlayDidChange() }
            .onChange(of: model.voicingStyle) { model.overlayDidChange() }
            .onChange(of: model.seventhStringSetIndex) { model.overlayDidChange() }
            .onChange(of: model.focusedSeventhInversion) { model.overlayDidChange() }
    }
}

/// The single error-alert surface, fed by AppModel.presentedError.
private struct ErrorAlert: ViewModifier {
    @Bindable var model: AppModel

    func body(content: Content) -> some View {
        content.alert(
            model.presentedError?.title ?? "Something went wrong",
            isPresented: Binding(
                get: { model.presentedError != nil },
                set: { if !$0 { model.presentedError = nil } }
            ),
            presenting: model.presentedError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }
}

/// Small wrapper so the metronome toggle gets a proper @Bindable home
/// (property-wrapper locals don't belong inside result builders).
private struct MetronomeToggle: View {
    @Bindable var backing: BackingTrackController

    var body: some View {
        Toggle("Metronome click", isOn: $backing.clickEnabled)
    }
}

/// Chromatic note row: twelve tappable pills, selected root in the accent
/// color. Faster than a menu and reads like an instrument control.
struct RootNotePicker: View {
    let title: String
    @Binding var selection: PitchClass

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PitchClass.allCases, id: \.self) { pitchClass in
                        pill(for: pitchClass)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func pill(for pitchClass: PitchClass) -> some View {
        let isSelected = pitchClass == selection
        return Button {
            withAnimation(.snappy(duration: 0.15)) { selection = pitchClass }
        } label: {
            Text(pitchClass.name())
                .font(.callout.weight(isSelected ? .bold : .regular))
                .monospacedDigit()
                .frame(width: 42, height: 42)
                .background(
                    isSelected
                        ? AnyShapeStyle(.orange.opacity(0.85))
                        : AnyShapeStyle(.thinMaterial),
                    in: .circle
                )
                .foregroundStyle(isSelected ? .black : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(pitchClass.name())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
