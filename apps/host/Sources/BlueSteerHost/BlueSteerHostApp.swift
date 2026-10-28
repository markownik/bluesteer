import HostCore
import SwiftUI

@main
struct BlueSteerHostApp: App {
    @State private var hub = SessionHub()

    var body: some Scene {
        MenuBarExtra("BlueSteer", systemImage: "antenna.radiowaves.left.and.right") {
            Text("BlueSteer \(HostInfo.version)")
            Text("Sessions: \(hub.sessionIDs.count)")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
