import SwiftUI

// MARK: - Brand colors

extension Color {
    static let brrPurple   = Color(hex: "#9B5CFF")
    static let brrPink     = Color(hex: "#FF3CAC")
    static let brrBg       = Color(hex: "#0B0B0F")
    static let brrText     = Color(hex: "#F5F5F5")
    static let brrRed      = Color(hex: "#FF4567")
    static let brrCard     = Color(hex: "#141419")
    static let brrBorder   = Color(hex: "#2A2A35")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - App screen enum

enum AppScreen {
    case splash
    case calibrateRing
    case calibrateSilent
    case calibrateResult
    case monitoring
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var logger: EventLogger
    @EnvironmentObject var detector: MuteSwitchDetector
    @EnvironmentObject var calibration: CalibrationManager

    @State private var screen: AppScreen = .splash
    @State private var showLog = false
    @State private var showSettings = false
    @State private var pulseAnimation = false
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.brrBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Main content
                Group {
                    switch screen {
                    case .splash:          splashView
                    case .calibrateRing:   calibrateRingView
                    case .calibrateSilent: calibrateSilentView
                    case .calibrateResult: calibrateResultView
                    case .monitoring:      monitoringView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: screen)
            }
        }
        .sheet(isPresented: $showLog) {
            LogView()
                .environmentObject(logger)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(detector)
                .environmentObject(calibration)
                .environmentObject(logger)
        }
        .onAppear {
            wireCallbacks()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.brrPurple)
                    .font(.system(size: 20))
            }
            Spacer()
            Button(action: { showLog = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                    Text("LOG")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                }
                .foregroundColor(.brrPink)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.brrCard.opacity(0.8))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.brrBorder),
            alignment: .bottom
        )
    }

    // MARK: - Splash / landing

    private var splashView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // Title
                VStack(spacing: 8) {
                    Text("RINGER GO BRRR")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.brrPurple, .brrPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)

                    Text("does the switch actually do shit?")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.brrText.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                // Disclaimer card
                BRRCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("HEURISTIC ONLY", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundColor(.brrPink)

                        Text("iOS does NOT officially expose the Ring/Silent switch to third-party apps. This app attempts to infer the switch state from audio completion timing. This technique may not work on iOS 27 Developer Beta 4 — finding out is the whole point.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.brrText.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Status
                BRRCard {
                    VStack(spacing: 8) {
                        Text("WE NEED DATA")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.brrText)

                        Text("First, let's calibrate with your specific device.")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.brrText.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }

                // Start calibration button
                BRRButton(
                    title: "START CALIBRATION",
                    color: .brrPurple,
                    icon: "waveform.path.ecg"
                ) {
                    screen = .calibrateRing
                    logger.logInfo("Calibration started.")
                }

                // If already calibrated, allow skip to monitoring
                if case .complete(let result) = calibration.phase {
                    BRRButton(
                        title: result.verdict == .reliable
                            ? "RESUME MONITORING"
                            : "VIEW LAST RESULT",
                        color: result.verdict == .reliable ? .brrPink : .brrRed,
                        icon: result.verdict == .reliable ? "antenna.radiowaves.left.and.right" : "chart.bar.xaxis"
                    ) {
                        screen = result.verdict == .reliable ? .monitoring : .calibrateResult
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Calibrate Ring

    private var calibrateRingView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 30)

                stepBadge(number: 1, of: 2)

                VStack(spacing: 10) {
                    Text("MAKE PHONE GO BRRR")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.brrPurple, .brrPink],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .multilineTextAlignment(.center)

                    Text("Flip the physical switch to\nRING mode right now.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.brrText.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                // Switch illustration
                switchIllustration(isRing: true)

                // Progress
                if calibration.phase == .capturingRing {
                    progressCard(
                        current: calibration.ringProgress,
                        total: calibration.samplesNeeded,
                        label: "CAPTURING RING SAMPLES..."
                    )
                }

                // Capture button
                BRRButton(
                    title: calibration.phase == .capturingRing
                        ? "MAKING SCIENCE HAPPEN..."
                        : "CAPTURE RING",
                    color: .brrPurple,
                    icon: "waveform",
                    isLoading: calibration.phase == .capturingRing
                ) {
                    guard calibration.phase != .capturingRing else { return }
                    logger.logCalibration("Ring capture started.")
                    calibration.beginRingCapture(detector: detector)
                }

                // Once ring is done, show next step prompt
                if calibration.phase == .idle && calibration.ringProgress >= calibration.samplesNeeded {
                    BRRCard {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.brrPurple)
                            Text("Ring captured! (\(calibration.ringProgress) samples)")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(.brrText.opacity(0.7))
                        }
                    }

                    BRRButton(
                        title: "NEXT →",
                        color: .brrPink,
                        icon: "arrow.right.circle.fill"
                    ) {
                        screen = .calibrateSilent
                    }
                }

                backButton { screen = .splash }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: calibration.ringProgress) { _, progress in
            if progress >= calibration.samplesNeeded {
                logger.logCalibration("Ring capture complete: \(progress) samples.")
            }
        }
    }

    // MARK: - Calibrate Silent

    private var calibrateSilentView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 30)

                stepBadge(number: 2, of: 2)

                VStack(spacing: 10) {
                    Text("NOW FLIP THE\nDAMN SWITCH")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.brrPink, .brrPurple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .multilineTextAlignment(.center)

                    Text("Put the physical switch into\nSILENT mode. Then tap the button.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.brrText.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                switchIllustration(isRing: false)

                if calibration.phase == .capturingSilent {
                    progressCard(
                        current: calibration.silentProgress,
                        total: calibration.samplesNeeded,
                        label: "CAPTURING SILENT SAMPLES..."
                    )
                }

                if calibration.phase == .analyzing {
                    BRRCard {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .brrPink))
                            Text("ANALYZING THE DATA...")
                                .font(.system(.footnote, design: .monospaced).weight(.bold))
                                .foregroundColor(.brrPink)
                        }
                    }
                }

                BRRButton(
                    title: calibration.phase == .capturingSilent || calibration.phase == .analyzing
                        ? "MAKING SCIENCE HAPPEN..."
                        : "CAPTURE SILENT",
                    color: .brrPink,
                    icon: "speaker.slash.fill",
                    isLoading: calibration.phase == .capturingSilent || calibration.phase == .analyzing
                ) {
                    guard calibration.phase == .idle else { return }
                    logger.logCalibration("Silent capture started.")
                    calibration.beginSilentCapture(detector: detector)
                }

                backButton { screen = .calibrateRing }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: calibration.silentProgress) { _, progress in
            if progress >= calibration.samplesNeeded {
                logger.logCalibration("Silent capture complete: \(progress) samples.")
            }
        }
        .onChange(of: calibration.phase) { _, phase in
            if case .complete = phase {
                screen = .calibrateResult
            } else if case .failed(let msg) = phase {
                logger.logError(msg)
                screen = .calibrateResult
            }
        }
    }

    // MARK: - Calibration result

    private var calibrateResultView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 30)

                switch calibration.phase {
                case .complete(let result):
                    resultContent(result)
                case .failed(let msg):
                    failedContent(msg)
                default:
                    Text("Something went sideways.")
                        .foregroundColor(.brrRed)
                        .font(.system(.body, design: .monospaced))
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func resultContent(_ result: CalibrationResult) -> some View {
        // Headline
        VStack(spacing: 10) {
            switch result.verdict {
            case .reliable:
                Text("HOLY SHIT\nIT WORKS")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.brrPurple, .brrPink],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .multilineTextAlignment(.center)

                verdictBadge(text: "CALIBRATION: RELIABLE", color: .brrPurple)

            case .unreliable:
                Text("NAH BRO.\niOS SAID NO.")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.brrRed)
                    .multilineTextAlignment(.center)

                verdictBadge(text: "CALIBRATION: UNRELIABLE", color: .brrRed)

            case .inconclusive:
                Text("WE HAVE NO\nFUCKING IDEA")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.brrPink)
                    .multilineTextAlignment(.center)

                verdictBadge(text: "CALIBRATION: INCONCLUSIVE", color: .brrPink)
            }
        }

        // Reason
        BRRCard {
            Text(result.verdictReason)
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(.brrText.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }

        // Stats table
        BRRCard {
            VStack(spacing: 0) {
                statsHeader
                Divider().background(Color.brrBorder)
                statsRow(label: "RING mean",   value: String(format: "%.1f ms", result.ringStats.mean))
                statsRow(label: "RING stddev", value: String(format: "%.1f ms", result.ringStats.stdDev))
                statsRow(label: "RING min/max",
                         value: String(format: "%.1f / %.1f ms",
                                       result.ringStats.min, result.ringStats.max))
                Divider().background(Color.brrBorder)
                statsRow(label: "SILENT mean",   value: String(format: "%.1f ms", result.silentStats.mean))
                statsRow(label: "SILENT stddev", value: String(format: "%.1f ms", result.silentStats.stdDev))
                statsRow(label: "SILENT min/max",
                         value: String(format: "%.1f / %.1f ms",
                                       result.silentStats.min, result.silentStats.max))
                Divider().background(Color.brrBorder)
                statsRow(label: "Cohen's d",  value: String(format: "%.2f", result.separationScore))
                statsRow(label: "Threshold",  value: String(format: "%.1f ms", result.threshold))
            }
        }

        // Raw ring samples
        rawSamplesCard(title: "RING SAMPLES", samples: calibration.ringSamples, color: .brrPurple)
        rawSamplesCard(title: "SILENT SAMPLES", samples: calibration.silentSamples, color: .brrPink)

        // Action buttons
        if result.verdict == .reliable {
            // Apply calibration and go to monitoring
            BRRButton(
                title: "START MONITORING",
                color: .brrPurple,
                icon: "antenna.radiowaves.left.and.right"
            ) {
                detector.thresholdMs = result.threshold
                detector.resetState()
                logger.logCalibration("Threshold set to \(String(format: "%.1f", result.threshold)) ms. Monitoring starting.")
                screen = .monitoring
            }
        }

        BRRButton(
            title: "RECALIBRATE",
            color: .brrCard,
            textColor: .brrText,
            icon: "arrow.clockwise"
        ) {
            calibration.reset()
            detector.resetState()
            screen = .calibrateRing
        }

        backButton { screen = .splash }
    }

    @ViewBuilder
    private func failedContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("AUDIO SAID NO")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.brrRed)
                .multilineTextAlignment(.center)

            BRRCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COULDN'T GET A CLEAN SAMPLE")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundColor(.brrRed)
                    Text(message)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.brrText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            BRRButton(title: "TRY AGAIN", color: .brrPurple, icon: "arrow.clockwise") {
                calibration.reset()
                screen = .calibrateRing
            }

            backButton { screen = .splash }
        }
    }

    // MARK: - Monitoring

    private var monitoringView: some View {
        VStack(spacing: 0) {
            // State display
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                Text(detector.isRunning ? "LISTENING FOR THE FUNNY SWITCH..." : "PRESS START")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(.brrText.opacity(0.5))

                // Current state indicator
                stateIndicator

                // Last sample ms
                if let ms = detector.lastSampleMs {
                    Text(String(format: "last probe: %.1f ms", ms))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.brrText.opacity(0.4))
                }

                // Control buttons
                HStack(spacing: 16) {
                    if detector.isRunning {
                        BRRButton(title: "STOP", color: .brrRed, icon: "stop.fill") {
                            detector.stopMonitoring()
                            logger.logInfo("Monitoring stopped by user.")
                        }
                    } else {
                        BRRButton(
                            title: "START MONITORING",
                            color: .brrPurple,
                            icon: "antenna.radiowaves.left.and.right"
                        ) {
                            detector.startMonitoring()
                            logger.logInfo("Monitoring started.")
                        }
                    }
                }

                Spacer(minLength: 10)
            }
            .padding(.horizontal, 20)

            Divider().background(Color.brrBorder)

            // Inline recent event log
            VStack(spacing: 0) {
                HStack {
                    Text("RECENT EVENTS")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundColor(.brrPurple)
                    Spacer()
                    Button("VIEW ALL") {
                        showLog = true
                    }
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(.brrPink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(logger.entries.suffix(50)) { entry in
                                logLine(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .onChange(of: logger.entries.count) { _, _ in
                        if let last = logger.entries.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .background(Color.brrCard)

            // Bottom buttons
            HStack(spacing: 12) {
                BRRButton(
                    title: "RECALIBRATE",
                    color: .brrCard,
                    textColor: .brrText,
                    icon: "arrow.clockwise"
                ) {
                    detector.stopMonitoring()
                    calibration.reset()
                    detector.resetState()
                    screen = .calibrateRing
                }
            }
            .padding(16)
        }
        .onAppear {
            wireCallbacks()
        }
        .onDisappear {
            detector.stopMonitoring()
        }
    }

    // MARK: - State indicator widget

    private var stateIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.brrCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(stateColor(detector.currentState), lineWidth: 2)
                )
                .shadow(color: stateColor(detector.currentState).opacity(0.4), radius: 20)

            VStack(spacing: 6) {
                Text("CURRENT STATE")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(.brrText.opacity(0.4))

                Text(stateLabel(detector.currentState))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(stateColor(detector.currentState))
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(
                        detector.isRunning
                            ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                            : .default,
                        value: pulseAnimation
                    )
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 0)
        .onAppear { pulseAnimation = true }
    }

    private func stateLabel(_ state: RingerState) -> String {
        switch state {
        case .ring:      return "RING"
        case .silent:    return "SILENT"
        case .uncertain: return "UNCERTAIN"
        }
    }

    private func stateColor(_ state: RingerState) -> Color {
        switch state {
        case .ring:      return .brrPurple
        case .silent:    return .brrPink
        case .uncertain: return .brrText.opacity(0.4)
        }
    }

    // MARK: - Wire callbacks from detector

    private func wireCallbacks() {
        detector.onSample = { sample in
            logger.logSample(sample.durationMs, state: detector.classify(sample.durationMs))
        }
        detector.onStateChange = { old, new in
            logger.logStateChange(from: old, to: new)
        }
    }

    // MARK: - Reusable sub-views

    private func stepBadge(number: Int, of total: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { n in
                Circle()
                    .fill(n == number ? Color.brrPurple : Color.brrBorder)
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func switchIllustration(isRing: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brrCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isRing ? Color.brrPurple : Color.brrPink, lineWidth: 1.5)
                )
                .frame(height: 110)

            HStack(spacing: 24) {
                // Switch shape
                ZStack {
                    Capsule()
                        .fill(isRing ? Color.brrPurple.opacity(0.3) : Color.brrPink.opacity(0.3))
                        .frame(width: 28, height: 56)
                        .overlay(Capsule().strokeBorder(isRing ? Color.brrPurple : Color.brrPink, lineWidth: 1.5))

                    Circle()
                        .fill(isRing ? Color.brrPurple : Color.brrPink)
                        .frame(width: 20, height: 20)
                        .offset(y: isRing ? 14 : -14)
                        .animation(.spring(response: 0.4), value: isRing)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isRing ? "▶  RING" : "✕  SILENT")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(isRing ? .brrPurple : .brrPink)

                    Text(isRing ? "sound is ON" : "sound is OFF")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.brrText.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 0)
    }

    private func progressCard(current: Int, total: Int, label: String) -> some View {
        BRRCard {
            VStack(spacing: 10) {
                Text(label)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(.brrPink)

                ProgressView(value: Double(current), total: Double(total))
                    .progressViewStyle(LinearProgressViewStyle(tint: .brrPurple))
                    .scaleEffect(x: 1, y: 2, anchor: .center)

                Text("\(current) / \(total)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.brrText.opacity(0.5))
            }
        }
    }

    private var statsHeader: some View {
        HStack {
            Text("MEASUREMENT")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundColor(.brrPurple)
            Spacer()
            Text("VALUE")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundColor(.brrPurple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.brrText.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.brrText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func rawSamplesCard(title: String, samples: [TimingSample], color: Color) -> some View {
        BRRCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(color)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(samples.enumerated()), id: \.offset) { _, s in
                            Text(String(format: "%.0f", s.durationMs))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(color.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(color.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }

    private func verdictBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.black))
            .foregroundColor(.brrBg)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(8)
    }

    private func logLine(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTimestamp)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.brrText.opacity(0.3))
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            Text(entry.message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(logLineColor(entry.kind))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func logLineColor(_ kind: LogEntryKind) -> Color {
        switch kind {
        case .sample:      return .brrText.opacity(0.55)
        case .stateChange: return .brrPink
        case .calibration: return .brrPurple
        case .error:       return .brrRed
        case .info:        return .brrText.opacity(0.4)
        }
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("BACK")
            }
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .foregroundColor(.brrText.opacity(0.4))
        }
    }
}

// MARK: - BRRCard

struct BRRCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brrCard)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.brrBorder, lineWidth: 1)
            )
    }
}

// MARK: - BRRButton

struct BRRButton: View {
    let title: String
    let color: Color
    var textColor: Color = .white
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.85)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 10, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Log view (full screen sheet)

struct LogView: View {
    @EnvironmentObject var logger: EventLogger
    @Environment(\.dismiss) var dismiss
    @State private var shareText: String? = nil
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.brrBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 3) {
                                ForEach(logger.entries) { entry in
                                    fullLogLine(entry)
                                        .id(entry.id)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: logger.entries.count) { _, _ in
                            if let last = logger.entries.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }

                    Divider().background(Color.brrBorder)

                    HStack(spacing: 12) {
                        Button(action: { logger.clear() }) {
                            Label("CLEAR", systemImage: "trash")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundColor(.brrRed)
                        }
                        Spacer()
                        Button(action: {
                            shareText = logger.exportText()
                            showShareSheet = true
                        }) {
                            Label("EXPORT", systemImage: "square.and.arrow.up")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundColor(.brrPink)
                        }
                    }
                    .padding(16)
                    .background(Color.brrCard)
                }
            }
            .navigationTitle("EVENT LOG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundColor(.brrPurple)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let text = shareText {
                ShareSheet(items: [text])
            }
        }
    }

    private func fullLogLine(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.formattedTimestamp)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.brrText.opacity(0.3))
                .frame(width: 90, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(fullLogColor(entry.kind))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fullLogColor(_ kind: LogEntryKind) -> Color {
        switch kind {
        case .sample:      return .brrText.opacity(0.6)
        case .stateChange: return .brrPink
        case .calibration: return .brrPurple
        case .error:       return .brrRed
        case .info:        return .brrText.opacity(0.45)
        }
    }
}

// MARK: - Share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
