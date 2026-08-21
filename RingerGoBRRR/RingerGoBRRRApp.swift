import SwiftUI

@main
struct RingerGoBRRRApp: App {
    @StateObject private var logger = EventLogger()
    @StateObject private var detector = MuteSwitchDetector()
    @StateObject private var calibration = CalibrationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(logger)
                .environmentObject(detector)
                .environmentObject(calibration)
                .preferredColorScheme(.dark)
        }
    }
}
