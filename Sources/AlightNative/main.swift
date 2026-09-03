import SwiftUI
import Foundation

if ProcessInfo.processInfo.environment["RUN_MATH_TESTS"] != nil {
    runMathTests()
    exit(0)
}

struct ContentView: View {
    var body: some View {
        MetalView()
            .frame(width: 400, height: 300)
    }
}

struct AlightNativeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

AlightNativeApp.main()
