// bluesteer: command line companion of the BlueSteer host app.
//
//   bluesteer run <command...>   run a command in a PTY and bridge it to the host app (Phase 2)
//   bluesteer hook <event>       relay a Claude/Copilot hook event to the host app (Phase 3)
//   bluesteer sessions           list bridged sessions (Phase 3)
//   bluesteer status             show host app and Bluetooth status (Phase 3)

import Foundation
import HostCore

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "run", "hook", "sessions", "status":
    FileHandle.standardError.write("bluesteer \(args[0]): not implemented yet\n".data(using: .utf8)!)
    exit(2)
case "--version":
    print(HostInfo.version)
default:
    print("usage: bluesteer run <command...> | hook <event> | sessions | status")
    exit(64)
}
