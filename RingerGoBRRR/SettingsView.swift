import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var detector: MuteSwitchDetector
    @EnvironmentObject var calibration: CalibrationManager
    @EnvironmentObject var logger: EventLogger
    @Environment(\.dismiss) var dismiss

    // Local edit state
    @State private var thresholdText: String = ""
    @State private var confirmationCount: Double = 3

    var body: some View {
        NavigationView {
            ZStack {
                Color.brrBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // App info card
                        BRRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("RINGER GO BRRR", systemImage: "waveform.path.ecg")
                                    .font(.system(.headline, design: .rounded).weight(.black))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.brrPurple, .brrPink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                Text("Experimental Ring/Silent switch detector using AudioToolbox timing heuristics.")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.brrText.opacity(0.6))
                                    .fixedSize(horizontal: false, vertical: true)

                                Divider().background(Color.brrBorder)

                                infoRow(key: "Target device", value: "iPhone 15")
                                infoRow(key: "Target OS", value: "iOS 27 Developer Beta 4")
                                infoRow(key: "Detection method", value: "AudioServices timing")
                                infoRow(key: "Uses private APIs", value: "NO")
                                infoRow(key: "Requires jailbreak", value: "NO")
                            }
                        }

                        // Detection settings
                        BRRCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("DETECTION SETTINGS")
                                    .font(.system(.caption, design: .monospaced).weight(.black))
                                    .foregroundColor(.brrPurple)

                                // Threshold
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Threshold (ms)")
                                            .font(.system(.footnote, design: .monospaced))
                                            .foregroundColor(.brrText.opacity(0.8))
                                        Spacer()
                                        Text("set by calibration")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.brrText.opacity(0.35))
                                    }

                                    HStack(spacing: 10) {
                                        TextField("e.g. 20.0", text: $thresholdText)
                                            .keyboardType(.decimalPad)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.brrText)
                                            .padding(10)
                                            .background(Color.brrBorder.opacity(0.5))
                                            .cornerRadius(8)

                                        Button("APPLY") {
                                            if let v = Double(thresholdText), v > 0 {
                                                detector.thresholdMs = v
                                                logger.logInfo("Threshold manually set to \(v) ms.")
                                            }
                                        }
                                        .font(.system(.caption, design: .monospaced).weight(.bold))
                                        .foregroundColor(.brrPurple)
                                    }

                                    Text("Current: \(String(format: "%.1f ms", detector.thresholdMs))")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.brrPink)
                                }

                                Divider().background(Color.brrBorder)

                                // Confirmation count
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Confirmation count")
                                            .font(.system(.footnote, design: .monospaced))
                                            .foregroundColor(.brrText.opacity(0.8))
                                        Spacer()
                                        Text("\(Int(confirmationCount)) readings")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.brrPink)
                                    }

                                    Slider(value: $confirmationCount, in: 1...10, step: 1)
                                        .accentColor(.brrPurple)
                                        .onChange(of: confirmationCount) { _, v in
                                            detector.confirmationCount = Int(v)
                                        }

                                    Text("Higher = fewer false transitions, slower reaction")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.brrText.opacity(0.35))
                                }
                            }
                        }

                        // Calibration summary
                        BRRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("LAST CALIBRATION")
                                    .font(.system(.caption, design: .monospaced).weight(.black))
                                    .foregroundColor(.brrPurple)

                                if case .complete(let result) = calibration.phase {
                                    infoRow(key: "Verdict",   value: verdictString(result.verdict))
                                    infoRow(key: "Ring mean", value: String(format: "%.1f ms", result.ringMeanMs))
                                    infoRow(key: "Silent mean", value: String(format: "%.1f ms", result.silentMeanMs))
                                    infoRow(key: "Cohen's d",  value: String(format: "%.2f", result.separationScore))
                                    infoRow(key: "Threshold",  value: String(format: "%.1f ms", result.threshold))
                                } else {
                                    Text("No calibration data yet.")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.brrText.opacity(0.4))
                                }
                            }
                        }

                        // How it works
                        BRRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("HOW THIS WORKS")
                                    .font(.system(.caption, design: .monospaced).weight(.black))
                                    .foregroundColor(.brrPurple)

                                explanationText(
                                    "AudioServicesPlaySystemSoundWithCompletion fires its completion callback after the sound is actually rendered by the audio hardware.",
                                    color: .brrText.opacity(0.7)
                                )
                                explanationText(
                                    "In Ring mode, the system plays the sound through the speaker pipeline. This takes ~40–120 ms.",
                                    color: .brrText.opacity(0.7)
                                )
                                explanationText(
                                    "In Silent mode, the system suppresses the sound and returns the callback almost immediately (~1–10 ms).",
                                    color: .brrText.opacity(0.7)
                                )
                                explanationText(
                                    "By measuring this timing difference, we can infer the current switch state — without any private API.",
                                    color: .brrPink.opacity(0.9)
                                )
                                explanationText(
                                    "This is a heuristic. Apple could change this behavior in any iOS release. That is why this app exists — to measure if it still works.",
                                    color: .brrRed.opacity(0.8)
                                )
                            }
                        }

                        // Log controls
                        BRRCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("LOG")
                                    .font(.system(.caption, design: .monospaced).weight(.black))
                                    .foregroundColor(.brrPurple)

                                infoRow(key: "Entries", value: "\(logger.entries.count)")

                                Button(action: { logger.clear() }) {
                                    Label("CLEAR LOG", systemImage: "trash")
                                        .font(.system(.footnote, design: .monospaced).weight(.bold))
                                        .foregroundColor(.brrRed)
                                }
                            }
                        }

                        // Limitation disclaimer
                        BRRCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("LIMITATIONS", systemImage: "info.circle.fill")
                                    .font(.system(.caption, design: .monospaced).weight(.bold))
                                    .foregroundColor(.brrPink)

                                Text("• Foreground only — background monitoring not implemented.\n• Only public APIs used.\n• Results may vary across devices and iOS versions.\n• If iOS 27 changes the audio pipeline, this may stop working entirely.")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.brrText.opacity(0.6))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundColor(.brrPurple)
                }
            }
            .onAppear {
                thresholdText = String(format: "%.1f", detector.thresholdMs)
                confirmationCount = Double(detector.confirmationCount)
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.brrText.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.brrText)
        }
    }

    private func explanationText(_ text: String, color: Color) -> some View {
        Text("→ " + text)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func verdictString(_ verdict: CalibrationVerdict) -> String {
        switch verdict {
        case .reliable:    return "RELIABLE ✓"
        case .unreliable:  return "UNRELIABLE ✗"
        case .inconclusive: return "INCONCLUSIVE ?"
        }
    }
}
