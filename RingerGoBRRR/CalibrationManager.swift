import Foundation

// MARK: - Calibration phase

enum CalibrationPhase: Equatable {
    case idle
    case capturingRing
    case capturingSilent
    case analyzing
    case complete(CalibrationResult)
    case failed(String)
}

// MARK: - Result

enum CalibrationVerdict: Equatable {
    case reliable          // Strong separation — technique appears to work.
    case unreliable        // Distributions overlap too much.
    case inconclusive      // Not enough data or ambiguous.
}

struct SampleStats: Equatable {
    let samples: [Double]   // ms values
    let mean: Double
    let median: Double
    let stdDev: Double
    let min: Double
    let max: Double

    init(samples: [Double]) {
        self.samples = samples
        let sorted = samples.sorted()
        let n = Double(samples.count)

        mean   = samples.isEmpty ? 0 : samples.reduce(0, +) / n
        median = samples.isEmpty ? 0 : (samples.count % 2 == 0
            ? (sorted[samples.count / 2 - 1] + sorted[samples.count / 2]) / 2
            : sorted[samples.count / 2])
        min    = sorted.first ?? 0
        max    = sorted.last ?? 0

        let variance = samples.isEmpty ? 0 : samples.map { pow($0 - mean, 2) }.reduce(0, +) / n
        stdDev = sqrt(variance)
    }
}

struct CalibrationResult: Equatable {
    let ringStats: SampleStats
    let silentStats: SampleStats
    let threshold: Double        // Midpoint between the two means.
    let separationScore: Double  // Cohen's d — effect size between the two groups.
    let verdict: CalibrationVerdict
    let verdictReason: String

    // MARK: Convenience

    var ringMeanMs: Double  { ringStats.mean }
    var silentMeanMs: Double { silentStats.mean }
}

// MARK: - CalibrationManager

final class CalibrationManager: ObservableObject {

    // MARK: Published

    @Published private(set) var phase: CalibrationPhase = .idle
    @Published private(set) var ringSamples:   [TimingSample] = []
    @Published private(set) var silentSamples: [TimingSample] = []
    @Published private(set) var ringProgress: Int = 0
    @Published private(set) var silentProgress: Int = 0

    // MARK: Configuration

    let samplesNeeded: Int = 20    // Samples collected per mode.

    // MARK: Private

    private var isCollecting = false
    private var collectionCount = 0
    private var currentMode: RingerState = .ring

    // MARK: - Start ring capture

    func beginRingCapture(detector: MuteSwitchDetector) {
        guard phase == .idle || shouldAllowRestart else { return }
        ringSamples = []
        ringProgress = 0
        phase = .capturingRing
        currentMode = .ring
        collectSamples(detector: detector, needed: samplesNeeded) { [weak self] in
            DispatchQueue.main.async {
                self?.phase = .idle    // Ready for silent capture.
            }
        }
    }

    // MARK: - Start silent capture

    func beginSilentCapture(detector: MuteSwitchDetector) {
        guard phase == .idle, !ringSamples.isEmpty else { return }
        silentSamples = []
        silentProgress = 0
        phase = .capturingSilent
        currentMode = .silent
        collectSamples(detector: detector, needed: samplesNeeded) { [weak self] in
            DispatchQueue.main.async {
                self?.analyzeAndFinalize()
            }
        }
    }

    // MARK: - Reset

    func reset() {
        phase = .idle
        ringSamples = []
        silentSamples = []
        ringProgress = 0
        silentProgress = 0
        isCollecting = false
        collectionCount = 0
    }

    private var shouldAllowRestart: Bool {
        switch phase {
        case .complete, .failed: return true
        default: return false
        }
    }

    // MARK: - Sample collection loop

    private func collectSamples(
        detector: MuteSwitchDetector,
        needed: Int,
        completion: @escaping () -> Void
    ) {
        isCollecting = true
        collectionCount = 0

        func runNext() {
            guard isCollecting, collectionCount < needed else {
                isCollecting = false
                completion()
                return
            }

            detector.probe { [weak self] sample in
                guard let self = self, self.isCollecting else { return }
                self.collectionCount += 1

                switch self.currentMode {
                case .ring:
                    self.ringSamples.append(sample)
                    self.ringProgress = self.ringSamples.count
                case .silent:
                    self.silentSamples.append(sample)
                    self.silentProgress = self.silentSamples.count
                case .uncertain:
                    break
                }

                // Small delay between probes to avoid hammering the audio engine.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    runNext()
                }
            }
        }

        runNext()
    }

    // MARK: - Analysis

    private func analyzeAndFinalize() {
        phase = .analyzing

        let ringMs   = ringSamples.map(\.durationMs)
        let silentMs = silentSamples.map(\.durationMs)

        guard ringMs.count >= 5, silentMs.count >= 5 else {
            phase = .failed("Not enough samples to analyze (need at least 5 per mode).")
            return
        }

        let rStats = SampleStats(samples: ringMs)
        let sStats = SampleStats(samples: silentMs)

        // Cohen's d: measures how well-separated the two distributions are.
        // d > 2.0 → very strong separation (reliable).
        // d 1.0–2.0 → moderate (marginal).
        // d < 1.0 → weak (unreliable).
        let pooledStdDev = sqrt((rStats.stdDev * rStats.stdDev + sStats.stdDev * sStats.stdDev) / 2.0)
        let cohensD: Double
        if pooledStdDev < 0.001 {
            cohensD = 0
        } else {
            cohensD = abs(rStats.mean - sStats.mean) / pooledStdDev
        }

        // The threshold is the midpoint between the two means.
        // If ring and silent are in the expected direction (ring > silent),
        // use the midpoint; otherwise mark as inconclusive.
        let threshold = (rStats.mean + sStats.mean) / 2.0
        let meansOrdered = rStats.mean > sStats.mean   // Ring should be slower.

        let verdict: CalibrationVerdict
        let reason: String

        if rStats.samples.count < 10 || sStats.samples.count < 10 {
            verdict = .inconclusive
            reason  = "Fewer than 10 samples per mode — collect more data."
        } else if !meansOrdered {
            verdict = .inconclusive
            reason  = "Ring mean (\(String(format: "%.1f", rStats.mean)) ms) is NOT slower than Silent mean (\(String(format: "%.1f", sStats.mean)) ms). The timing technique may not work on this device/OS."
        } else if cohensD >= 2.0 {
            verdict = .reliable
            reason  = "Cohen's d = \(String(format: "%.2f", cohensD)) — strong separation between Ring and Silent timing."
        } else if cohensD >= 1.0 {
            verdict = .unreliable
            reason  = "Cohen's d = \(String(format: "%.2f", cohensD)) — weak separation. The technique is marginal on this device/OS."
        } else {
            verdict = .unreliable
            reason  = "Cohen's d = \(String(format: "%.2f", cohensD)) — distributions overlap too much. The technique does not reliably work here."
        }

        let result = CalibrationResult(
            ringStats: rStats,
            silentStats: sStats,
            threshold: threshold,
            separationScore: cohensD,
            verdict: verdict,
            verdictReason: reason
        )

        phase = .complete(result)
    }
}
