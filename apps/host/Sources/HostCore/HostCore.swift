// HostCore: the non-UI heart of the BlueSteer host.
//
// Components (see docs/architecture.md):
//   SessionHub            owns sessions, subscriptions, sequence numbers, backpressure
//   PtySession            forkpty + headless SwiftTerm + deflate stream (Phase 2)
//   WrapperSocketServer   Unix socket for `bluesteer run` and `bluesteer hook` (Phase 2/3)
//   BLEPeripheralService  CoreBluetooth peripheral: advertise, chunk, flow control (Phase 1)
//   SecureChannel         Noise handshake + transport over one BLE connection (Phase 1)
//   PairingStore          paired remotes' static keys in the Keychain (Phase 1)
//   Discovery             `claude agents --json` poller (Phase 3)
//   HookInstaller         writes/removes hook entries in Claude and Copilot settings (Phase 3)

import Foundation

public enum HostInfo {
    public static let version = "0.0.1"
    /// Directory for the wrapper/hook socket and local state.
    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BlueSteer", isDirectory: true)
    }
}
