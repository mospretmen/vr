import SwiftUI
import MusicTheory

/// The main floating window: musical selection, display options, and the
/// calibration + immersive-space lifecycle controls.
struct ControlPanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

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

                if model.displayMode != .chord {
                    Section("Scale") {
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
                    }
                }

                if model.displayMode != .scale {
                    Section("Chord") {
                        rootPicker("Chord root", selection: $model.chordRoot)
                        Picker("Quality", selection: $model.chordQuality) {
                            ForEach(ChordQuality.all, id: \.self) { Text($0.name).tag($0) }
                        }
                    }
                }

                Section("Display") {
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

                Section("Guitar") {
                    immersiveControls
                }

                Section("Backing Track (preview)") {
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
                    } else {
                        Menu("Load Progression") {
                            ForEach(StarterProgression.all) { starter in
                                Button(starter.title) {
                                    model.backing.load(starter.timeline, title: starter.title)
                                }
                            }
                        }
                    }
                }

                Section("Exercise") {
                    if let progress = model.exerciseProgress {
                        LabeledContent("Step", value: progress)
                        Button("Next Step") { model.advanceExercise() }
                        Button("Stop Exercise", role: .destructive) { model.stopExercise() }
                    } else {
                        Button("Scale Run in Current Box") { model.startScaleRunExercise() }
                        Button("Triad Drill on Top Strings") { model.startTriadDrillExercise() }
                    }
                }

                Section("Listen (beta)") {
                    if model.listen.isListening {
                        LabeledContent("Hearing",
                                       value: model.listen.detectedChord?.symbol ?? "—")
                        Button("Stop Listening") { model.listen.stop() }
                    } else {
                        Button("Start Listening") {
                            Task { await model.listen.start() }
                        }
                    }
                }

                Section {
                    Button("Open Notation Panel") { openWindow(id: SceneID.notation) }
                }
            }
            .navigationTitle("Fretspace")
        }
        .onChange(of: model.root) { model.overlayDidChange() }
        .onChange(of: model.scaleType) { model.overlayDidChange() }
        .onChange(of: model.chordRoot) { model.overlayDidChange() }
        .onChange(of: model.chordQuality) { model.overlayDidChange() }
        .onChange(of: model.tuning) { model.overlayDidChange() }
        .onChange(of: model.displayMode) { model.overlayDidChange() }
        .onChange(of: model.selectedBoxIndex) { model.overlayDidChange() }
        .onChange(of: model.leftHanded) { model.overlayDidChange() }
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

    private func rootPicker(_ title: String, selection: Binding<PitchClass>) -> some View {
        Picker(title, selection: selection) {
            ForEach(PitchClass.allCases, id: \.self) { Text($0.name()).tag($0) }
        }
        .pickerStyle(.menu)
    }
}
