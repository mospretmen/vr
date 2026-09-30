import Foundation

/// Everything that can go wrong in a way the user must hear about, with
/// recovery guidance. Raw errors never reach the UI; they get logged and
/// mapped into one of these.
enum UserFacingError: Identifiable, Equatable {
    case calibrationImplausible
    case microphonePermissionDenied
    case audioEngineUnavailable
    case handTrackingUnavailable
    case trackLibraryUnreachable
    case trackNotFound

    var id: String { title }

    var title: String {
        switch self {
        case .calibrationImplausible: "Calibration didn't look right"
        case .microphonePermissionDenied: "Microphone access needed"
        case .audioEngineUnavailable: "Audio engine unavailable"
        case .handTrackingUnavailable: "Hand tracking unavailable"
        case .trackLibraryUnreachable: "Can't reach the track library"
        case .trackNotFound: "Track not found"
        }
    }

    var message: String {
        switch self {
        case .calibrationImplausible:
            "The two points were too close together or too far apart to be a "
            + "guitar neck. Pinch once at the nut, then once at the 12th fret."
        case .microphonePermissionDenied:
            "Listen mode needs the microphone to hear your playing. "
            + "Enable it in Settings → Privacy → Microphone."
        case .audioEngineUnavailable:
            "The audio system couldn't start. Try closing other audio apps "
            + "and starting listen mode again."
        case .handTrackingUnavailable:
            "Calibration needs hand tracking, which isn't available right now. "
            + "Check Settings → Privacy → Hand Structure & Movements."
        case .trackLibraryUnreachable:
            "The track service didn't respond. Bundled progressions still "
            + "work offline; try the library again in a moment."
        case .trackNotFound:
            "That track is no longer in the library. Refresh the list."
        }
    }
}
