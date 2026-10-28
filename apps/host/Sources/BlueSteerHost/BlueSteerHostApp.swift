import CoreImage.CIFilterBuiltins
import HostCore
import SwiftUI

@main
struct BlueSteerHostApp: App {
    @State private var controller: HostController? = {
        do {
            let c = try HostController(store: try PairingStore())
            // Development aid: `BlueSteerHost --pair` starts pairing at launch and prints the QR payload.
            if CommandLine.arguments.contains("--pair") {
                setvbuf(stdout, nil, _IOLBF, 0)
                print("PAIRING \(c.beginPairing())")
            }
            return c
        } catch { return nil }
    }()

    var body: some Scene {
        MenuBarExtra("BlueSteer", systemImage: "antenna.radiowaves.left.and.right") {
            if let controller {
                MenuContent(controller: controller)
            } else {
                Text("BlueSteer failed to start (see Console)")
            }
            Divider()
            Button("Quit BlueSteer") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
        Window("Pair a remote", id: "pairing") {
            if let controller { PairingView(controller: controller) }
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    @Bindable var controller: HostController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("BlueSteer \(HostInfo.version) · \(bluetoothStatus)")
        if controller.connected.isEmpty {
            Text("No remote connected").foregroundStyle(.secondary)
        } else {
            ForEach(controller.connected) { Text("Connected: \($0.name)") }
        }
        Divider()
        Button("Pair a remote…") {
            controller.beginPairing()
            openWindow(id: "pairing")
            NSApp.activate(ignoringOtherApps: true)
        }
        if !controller.pairedRemotes.isEmpty {
            Menu("Paired remotes") {
                ForEach(controller.pairedRemotes) { remote in
                    Button("Revoke \(remote.name) (\(remote.id.prefix(8))…)") { controller.revoke(remote) }
                }
            }
        }
    }

    private var bluetoothStatus: String {
        switch controller.bluetoothState {
        case .poweredOn: return "Bluetooth on"
        case .poweredOff: return "Bluetooth off"
        case .unauthorized: return "Bluetooth not allowed"
        default: return "Bluetooth…"
        }
    }
}

struct PairingView: View {
    @Bindable var controller: HostController
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 16) {
            if let payload = controller.qrPayload, let image = qrImage(payload) {
                Text("Scan with BlueSteer Remote").font(.headline)
                Image(nsImage: image).interpolation(.none).resizable().frame(width: 260, height: 260)
                Text("or enter code \(controller.pairingCode ?? "")").font(.title3.monospacedDigit())
                Text("The code is valid until a remote pairs or you close this window.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
                Text("Remote paired").font(.headline)
            }
            Button(controller.pairingPSK == nil ? "Done" : "Cancel") {
                controller.endPairing()
                dismissWindow(id: "pairing")
            }
        }
        .padding(24)
        .frame(width: 340)
        .onDisappear { controller.endPairing() }
    }

    private func qrImage(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: output.extent.width, height: output.extent.height))
    }
}
