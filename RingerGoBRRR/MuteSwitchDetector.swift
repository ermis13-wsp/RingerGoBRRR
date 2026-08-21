import Foundation
import AudioToolbox
import AVFoundation

// MARK: - Inferred switch state

enum RingerState: String, Equatable {
    case ring     = "RING"
    case silent   = "SILENT"
    case uncertain = "UNCERTAIN"
}

// MARK: - A single timing measurement

struct TimingSample {
    let timestamp: Date
    let durationMs: Double   // milliseconds from play request → completion callback
    let raw: TimeInterval    // same value in seconds, kept for convenience
}

// MARK: - MuteSwitchDetector
//
// Public-API-only approach:
//   AudioServicesPlaySystemSoundWithCompletion fires its callback almost
//   immediately (< ~5 ms) when the ringer switch is in Silent mode because
//   the system suppresses the sound and returns instantly.
//   In Ring mode the callback arrives after the actual (very short) audio
//   render pipeline drains — typically 40–120 ms depending on the sound.
//
// This is a heuristic, NOT an official API.  The technique may break on any
// iOS release.  The entire purpose of this app is to measure whether it still
// works on iOS 27 Developer Beta 4.

final class MuteSwitchDetector: ObservableObject {

    // MARK: Published state

    @Published private(set) var currentState: RingerState = .uncertain
    @Published private(set) var lastSampleMs: Double?
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastError: String?

    // MARK: Configuration

    /// Threshold in ms — set after calibration.
    /// Samples BELOW this are classified as Silent; ABOVE as Ring.
    var thresholdMs: Double = 20.0

    /// How many consecutive consistent readings are required before we commit
    /// to a new state (reduces flip-flopping on noisy readings).
    var confirmationCount: Int = 3

    // MARK: Private

    private var soundID: SystemSoundID = 0
    private var isPlayingSound: Bool = false
    private var monitoringTimer: Timer?

    /// Interval between probes while monitoring (seconds).
    private let probeInterval: TimeInterval = 0.35

    /// Ring-buffer of the last N inferences used for confirmation.
    private var recentInferences: [RingerState] = []

    /// Callback fired each time a new sample arrives (used by CalibrationManager).
    var onSample: ((TimingSample) -> Void)?

    /// Callback fired when the inferred state changes (used by monitoring).
    var onStateChange: ((RingerState, RingerState) -> Void)?  // (old, new)

    // MARK: Init / deinit

    init() {
        setupAudioSession()
        prepareSoundID()
    }

    deinit {
        stopMonitoring()
        if soundID != 0 {
            AudioServicesDisposeSystemSoundID(soundID)
        }
    }

    // MARK: - Audio session setup

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .ambient allows the sound to be silenced by the ringer switch,
            // which is exactly what we need for this technique to work.
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            lastError = "Audio session setup failed: \(error.localizedDescription)"
        }
    }

    // MARK: - System sound preparation
    //
    // We need a real, non-zero-length sound file.  We use the built-in
    // system sound 1057 ("Tock") which is a very short click — minimal
    // audible disruption in Ring mode, and its render time is consistent.

    private func prepareSoundID() {
        // Use a built-in short system sound.
        // kSystemSoundID_Vibrate = 4095, regular UI sounds start at 1000.
        // Sound 1104 is a short "key press" click — good for timing.
        // We fall back to creating a minimal silence WAV if the system sound
        // approach doesn't produce a measurable delay difference.
        let result = AudioServicesCreateSystemSoundID(
            URL(fileURLWithPath: "/System/Library/Audio/UISounds/key_press_click.caf") as CFURL,
            &soundID
        )
        if result != kAudioServicesNoError {
            // Fallback: use built-in ID directly.
            soundID = 1104
            lastError = "Note: using fallback sound ID 1104 (OSStatus \(result))"
        }
    }

    // MARK: - Single probe

    /// Takes one timing measurement and calls `onSample` with the result.
    /// Safe to call from any thread; completion is dispatched to main.
    func probe(completion: ((TimingSample) -> Void)? = nil) {
        guard !isPlayingSound else { return }
        isPlayingSound = true

        let start = Date()
        let startCFAbs = CFAbsoluteTimeGetCurrent()

        AudioServicesPlaySystemSoundWithCompletion(soundID) { [weak self] in
            guard let self = self else { return }

            let elapsed = CFAbsoluteTimeGetCurrent() - startCFAbs
            let ms = elapsed * 1000.0

            let sample = TimingSample(
                timestamp: start,
                durationMs: ms,
                raw: elapsed
            )

            DispatchQueue.main.async {
                self.isPlayingSound = false
                self.lastSampleMs = ms
                self.onSample?(sample)
                completion?(sample)
            }
        }
    }

    // MARK: - Classify a single sample against the current threshold

    func classify(_ ms: Double) -> RingerState {
        guard thresholdMs > 0 else { return .uncertain }
        return ms < thresholdMs ? .silent : .ring
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        recentInferences = []
        scheduleNextProbe()
    }

    func stopMonitoring() {
        isRunning = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func scheduleNextProbe() {
        guard isRunning else { return }
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: probeInterval,
            repeats: false
        ) { [weak self] _ in
            self?.runMonitoringProbe()
        }
    }

    private func runMonitoringProbe() {
        probe { [weak self] sample in
            guard let self = self else { return }
            let inferred = self.classify(sample.durationMs)

            // Confirmation logic: only commit after N consistent readings.
            self.recentInferences.append(inferred)
            if self.recentInferences.count > self.confirmationCount {
                self.recentInferences.removeFirst()
            }

            if self.recentInferences.count == self.confirmationCount {
                let allSame = self.recentInferences.allSatisfy { $0 == inferred }
                if allSame && inferred != self.currentState {
                    let old = self.currentState
                    self.currentState = inferred
                    self.onStateChange?(old, inferred)
                }
            }

            // Schedule next probe.
            self.scheduleNextProbe()
        }
    }

    // MARK: - Forced state reset (used after recalibration)

    func resetState() {
        currentState = .uncertain
        recentInferences = []
        lastSampleMs = nil
    }
}
