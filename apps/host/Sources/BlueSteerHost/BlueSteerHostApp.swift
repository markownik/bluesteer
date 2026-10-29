import CoreImage.CIFilterBuiltins
import HostCore
import SwiftUI

@main
struct BlueSteerHostApp: App {
    @State private var controller: HostController? = {
        do {
            // A wrapper that went away must not take the host down with it (EPIPE is handled).
            signal(SIGPIPE, SIG_IGN)
            HookInstaller.refreshCLILink()
            let c = try HostController(store: try PairingStore())
            // Development aid: `BlueSteerHost --pair` starts pairing at launch, prints the QR
            // payload and confirms code pairings by itself (printing the code).
            if CommandLine.arguments.contains("--pair") {
                setvbuf(stdout, nil, _IOLBF, 0)
                c.autoConfirmPairing = true
                print("PAIRING \(c.beginPairing())")
            }
            // Development aid: `BlueSteerHost --login-item on|off|status` drives SMAppService and exits.
            if let i = CommandLine.arguments.firstIndex(of: "--login-item"), i + 1 < CommandLine.arguments.count {
                setvbuf(stdout, nil, _IOLBF, 0)
                let want = CommandLine.arguments[i + 1]
                if want == "on" || want == "off" {
                    do { try LoginItem.setEnabled(want == "on") } catch { print("LOGIN ITEM error \(error)") }
                }
                print("LOGIN ITEM available=\(LoginItem.isAvailable) enabled=\(LoginItem.isEnabled) requiresApproval=\(LoginItem.requiresApproval)")
                exit(0)
            }
            return c
        } catch { return nil }
    }()

    var body: some Scene {
        MenuBarExtra {
            if let controller {
                MenuContent(controller: controller)
            } else {
                Text("BlueSteer failed to start (see Console)")
            }
            Divider()
            Button("Quit BlueSteer") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        Window("Pair a remote", id: "pairing") {
            if let controller { PairingView(controller: controller) }
        }
        .windowResizability(.contentSize)
    }
}

extension BlueSteerHostApp {
    /// The brand glyph (assets/icon/menubar.svg) as a template image, so it follows the menu bar's appearance.
    static let menuBarIcon: NSImage = {
        let image = NSImage()
        for name in ["MenuBarIcon", "MenuBarIcon@2x"] {
            if let url = Bundle.module.url(forResource: name, withExtension: "png"), let data = try? Data(contentsOf: url),
               let rep = NSBitmapImageRep(data: data) {
                rep.size = NSSize(width: 18, height: 18)
                image.addRepresentation(rep)
            }
        }
        if image.representations.isEmpty, let fallback = NSImage(systemSymbolName: "terminal", accessibilityDescription: "BlueSteer") { return fallback }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
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
        Divider()
        if hooksInstalled {
            Button("Remove Claude Code hooks") { changeHooks(install: false) }
        } else {
            Button("Install Claude Code hooks…") { changeHooks(install: true) }
        }
        Toggle("Start at login", isOn: Binding(
            get: { LoginItem.isEnabled },
            set: { on in
                do { try LoginItem.setEnabled(on) } catch { NSApp.presentError(error) }
                if LoginItem.requiresApproval { LoginItem.openSystemSettings() }
                menuRefresh += 1
            }))
            .disabled(!LoginItem.isAvailable)
        Button("Show audit log") { NSWorkspace.shared.open(AuditLog.shared.url) }
    }

    @State private var menuRefresh = 0
    private var hooksInstalled: Bool { _ = menuRefresh; return HookInstaller.isInstalled() }

    /// Confirms, then edits ~/.claude/settings.json (backed up first).
    private func changeHooks(install: Bool) {
        let alert = NSAlert()
        alert.messageText = install ? "Install Claude Code hooks?" : "Remove Claude Code hooks?"
        alert.informativeText = install
            ? "BlueSteer adds command hooks for \(HookInstaller.events.joined(separator: ", ")) to \(HookInstaller.settingsURL.path) so the phone can show when Claude is working, waiting for input or waiting for permission. Each hook runs:\n\n\(HookInstaller.command(for: "<Event>"))\n\nIt exits at once for sessions BlueSteer does not bridge. A backup is kept next to the file."
            : "The BlueSteer entries are removed from \(HookInstaller.settingsURL.path); other hooks stay."
        alert.addButton(withTitle: install ? "Install" : "Remove")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            if install { try HookInstaller.install() } else { try HookInstaller.uninstall() }
            AuditLog.shared.record(install ? "hooks installed file=\(HookInstaller.settingsURL.path)" : "hooks removed file=\(HookInstaller.settingsURL.path)")
        } catch {
            NSApp.presentError(error)
        }
        menuRefresh += 1
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
            if let pending = controller.pendingPairing {
                Text("\(pending.deviceName) wants to pair").font(.headline)
                Text(Self.spaced(pending.code)).font(.system(size: 40, weight: .semibold, design: .monospaced))
                Text(pending.remoteConfirmed
                     ? "Does the remote show the same code?"
                     : "Does the remote show the same code? Confirm there too.")
                    .font(.callout).multilineTextAlignment(.center)
                HStack {
                    Button("Reject", role: .destructive) { controller.rejectPairing() }
                    Button("Pair") { controller.confirmPairing() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(pending.hostConfirmed)
                }
                if pending.hostConfirmed { Text("Waiting for the remote…").font(.caption).foregroundStyle(.secondary) }
            } else if controller.pairingOpen, let payload = controller.qrPayload, let image = qrImage(payload) {
                Text("Pair a remote").font(.headline)
                Image(nsImage: image).interpolation(.none).resizable().frame(width: 220, height: 220)
                Text("Scan this with BlueSteer Remote, or tap + on the phone, choose this Mac and compare the 6-digit code.")
                    .font(.callout).multilineTextAlignment(.center)
                Text("Valid for 2 minutes or until a remote pairs.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let name = controller.lastPairedName {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
                Text("Paired with \(name)").font(.headline)
            } else {
                Image(systemName: "clock").font(.system(size: 48)).foregroundStyle(.secondary)
                Text("Pairing ended").font(.headline)
                Button("Start again") { controller.beginPairing() }
            }
            Button(controller.pairingOpen ? "Cancel" : "Done") {
                controller.endPairing()
                dismissWindow(id: "pairing")
            }
        }
        .padding(24)
        .frame(width: 340)
        .onDisappear { controller.endPairing() }
    }

    static func spaced(_ code: String) -> String { String(code.prefix(3)) + " " + String(code.suffix(3)) }

    private func qrImage(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: output.extent.width, height: output.extent.height))
    }
}
