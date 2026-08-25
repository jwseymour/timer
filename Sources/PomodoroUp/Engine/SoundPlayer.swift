import AppKit

/// One-shot system-style chimes. Deliberately simple — `NSSound` is
/// sufficient for a single non-overlapping alert sound with no
/// mixing/ducking/format requirements.
final class SoundPlayer {
    private let targetReachedSound = NSSound(named: "Glass")
    private let breakEndedSound = NSSound(named: "Ping")

    func playTargetReached() {
        targetReachedSound?.stop()
        targetReachedSound?.play()
    }

    func playBreakEnded() {
        breakEndedSound?.stop()
        breakEndedSound?.play()
    }
}
