import SwiftUI
import MusicTheory

/// The main floating window: musical selection, display options, and the
/// calibration + immersive-space lifecycle controls.
struct ControlPanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @State private var showTrackLibrary = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("Display", selection: $model.displayMode) {
                        ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if model.displayMode == .triads {
                    Section {
                        Picker("Style", selection: $model.voicingStyle) {
                            ForEach(AppModel.VoicingStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch model.voicingStyle {
                        case .triads:
                            Picker("Strings", selection: $model.triadStringSetIndex) {
                                ForEach(Array(TriadVoicings.stringSets.enumerated()), id: \.offset) { index, set in
                                    Text(stringSetLabel(set)).tag(index)
                                }
                            }
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
                        }
                    } header: {
                        Label("Voicings", systemImage: "triangle")
                    } footer: {
                        if model.voicingStyle == .drop2, model.chordQuality.intervals.count < 4 {
                            Text("Pick a seventh quality (maj7, 7, m7, m7♭5, °7) to see drop-2 shapes.")
                        }
                    }
                }

                if model.displayMode != .chord && model.displayMode != .triads {
                    Section {
                        rootPicker("Root", selection: $model.root)
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

                if model.displayMode != .scale {
                    Section {
                        rootPicker("Chord root", selection: $model.chordRoot)
                        Picker("Quality", selection: $model.chordQuality) {
                            ForEach(ChordQuality.all, id: \.self) { Text($0.name).tag($0) }
                        }
                    } header: {
                        Label("Chord", systemImage: "pianokeys")
                    }
                }

                Section(header: Label("Display", systemImage: "slider.horizontal.3")) {
                    Picker("Labels", selection: $model.labelStyle) {
                        ForEach(LabelStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("String lines", isOn: $model.showStringLines)
                    Toggle("Fret lines", isOn: $model.showFretLines)
                    Toggle("Left-handed", isOn: $model.leftHanded)
                    Picker("Tuning", selection: $model.tuning) {
                        ForEach(Tuning.all, id: \.self) { Text($0.name).tag($0) }
                    }
                }

                Section(header: Label("Guitar", systemImage: "guitars")) {
                    immersiveControls
                }

                Section(header: Label("Backing Track", systemImage: "metronome")) {
                    if let timeline = model.backing.timeline {
                        LabeledContent("Track", value: model.backing.title)
                        LabeledContent("Now",
                                       value: model.backing.currentChord?.symbol ?? "—")
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
                        @Bindable var backing = model.backing
                        Toggle("Metronome click", isOn: $backing.clickEnabled)
                    } else {
                        Button("Browse Backing Tracks") { showTrackLibrary = true }
                    }
                }

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

                Section(header: Label("Listen", systemImage: "ear")) {
                    if model.listen.isListening {
                        LabeledContent("Hearing",
                                       value: model.listen.detectedChord?.symbol ?? "—")
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
            .navigationTitle("Fretspace")
            .sheet(isPresented: $showTrackLibrary) {
                TrackLibraryView()
            }
        }
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
        .onChange(of: model.triadStringSetIndex) { model.overlayDidChange() }
        .onChange(of: model.focusedInversion) { model.overlayDidChange() }
        .onChange(of: model.voicingStyle) { model.overlayDidChange() }
        .onChange(of: model.seventhStringSetIndex) { model.overlayDidChange() }
        .onChange(of: model.focusedSeventhInversion) { model.overlayDidChange() }
        .alert(
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

    @ViewBuilder
    private var immersiveControls: some View {
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
            case .placingNut, .placingTwelfthFret:
                Button("Cancel Calibration", role: .cancel) {
                    model.calibration = .notCalibrated
                }
            case .calibrated(let cal):
                LabeledContent("Scale length",
                               value: String(format: "%.1f\u{2033}", cal.scaleLength / 0.0254))
                Button("Recalibrate") { model.startCalibration() }
            }

            Button("End Session", role: .destructive) {
                Task { await dismissImmersiveSpace() }
            }
        }
    }

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

    private func rootPicker(_ title: String, selection: Binding<PitchClass>) -> some View {
        RootNotePicker(title: title, selection: selection)
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
                        let isSelected = pitchClass == selection
                        Button {
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
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
