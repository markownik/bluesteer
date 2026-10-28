// bluesteer: command line companion of the BlueSteer host app.
//
//   bluesteer run <command...>   run a command in this terminal and bridge it to the host app
//   bluesteer hook <event>       relay a Claude Code hook event to the host app (exits 0 at once)
//   bluesteer hooks install|remove   add or remove the hook entries in ~/.claude/settings.json
//   bluesteer pair | hosts | connect   use this Mac as a remote for another Mac (Remote.swift)

import Darwin
import Foundation
import HostCore
import RemoteCore

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "run":
    guard args.count > 1 else { fputs("usage: bluesteer run <command...>\n", stderr); exit(64) }
    exit(runWrapped(Array(args.dropFirst())))
case "hook":
    guard args.count > 1 else { fputs("usage: bluesteer hook <Event>\n", stderr); exit(64) }
    exit(relayHook(args[1]))
case "hooks":
    HookInstaller.refreshCLILink()
    do {
        switch args.dropFirst().first {
        case "install": try HookInstaller.install(); print("hooks installed in \(HookInstaller.settingsURL.path)")
        case "remove": try HookInstaller.uninstall(); print("hooks removed from \(HookInstaller.settingsURL.path)")
        default: print(HookInstaller.isInstalled() ? "installed" : "not installed"); exit(HookInstaller.isInstalled() ? 0 : 1)
        }
    } catch { fputs("bluesteer hooks: \(error.localizedDescription)\n", stderr); exit(1) }
case "pair":
    exit(cmdPair(Array(args.dropFirst())))
case "hosts":
    exit(cmdHosts())
case "connect":
    exit(cmdConnect(Array(args.dropFirst())))
case "--version":
    print(HostInfo.version)
default:
    print("usage: bluesteer run <command...> | hook <Event> | hooks [install|remove] | pair [link] | hosts | connect [name] [--new]")
    exit(64)
}

/// Forwards one Claude Code hook event to the host app. Never fails the hook:
/// without `BLUESTEER_SESSION` (a session the host does not bridge) or without
/// a running host it just exits 0.
func relayHook(_ event: String) -> Int32 {
    guard let session = ProcessInfo.processInfo.environment["BLUESTEER_SESSION"], !session.isEmpty else { return 0 }
    var notificationType: String?
    if isatty(STDIN_FILENO) == 0,
       let json = try? JSONSerialization.jsonObject(with: FileHandle.standardInput.readDataToEndOfFile()) as? [String: Any] {
        notificationType = json["notification_type"] as? String
    }
    let sock = connectToHost()
    guard sock >= 0 else { return 0 }
    let payload = try! JSONEncoder().encode(HookEvent(event: event, session: session, notificationType: notificationType))
    sendFrame(sock, WrapperFrame.hook, payload)
    close(sock)
    return 0
}

/// Runs `command` in a PTY attached to this terminal and mirrors it to the host app.
func runWrapped(_ command: [String]) -> Int32 {
    let terminal = RawTerminal()
    let stdinIsTTY = terminal.isTTY
    let size = RawTerminal.size
    var ws = winsize(ws_row: UInt16(size.rows), ws_col: UInt16(size.cols), ws_xpixel: 0, ws_ypixel: 0)

    var master: Int32 = 0
    var childTermios = terminal.savedTermios
    let sessionID = UUID().uuidString
    setenv("BLUESTEER_SESSION", sessionID, 1)
    let pid: pid_t = stdinIsTTY ? forkpty(&master, nil, &childTermios, &ws) : forkpty(&master, nil, nil, &ws)
    if pid < 0 { perror("forkpty"); return 1 }
    if pid == 0 {
        let cargs = command.map { strdup($0) } + [nil]
        execvp(command[0], cargs)
        perror("execvp"); _exit(127)
    }

    // Connect to the host app; without it the command still runs, just unbridged.
    let sock = connectToHost()
    if sock >= 0 {
        let hello = WrapperHello(command: command, cwd: FileManager.default.currentDirectoryPath,
                                 rows: Int(ws.ws_row), cols: Int(ws.ws_col), pid: pid, sessionId: sessionID)
        sendFrame(sock, WrapperFrame.hello, try! JSONEncoder().encode(hello))
    } else {
        fputs("bluesteer: host app not running, command is not bridged\n", stderr)
    }

    terminal.enterRaw()
    let winch = RawTerminal.onResize(queue: .main) {
        var now = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &now) == 0 {
            _ = ioctl(master, TIOCSWINSZ, &now)
            if sock >= 0 { sendFrame(sock, WrapperFrame.resize, Data("{\"rows\":\(now.ws_row),\"cols\":\(now.ws_col)}".utf8)) }
        }
    }
    _ = winch

    // PTY → real terminal + host
    DispatchQueue(label: "pty.out").async {
        var buf = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = read(master, &buf, buf.count)
            if n <= 0 { break }
            let data = Data(buf[0..<n])
            writeAll(STDOUT_FILENO, data)
            if sock >= 0 { sendFrame(sock, WrapperFrame.output, data) }
        }
    }
    // real keyboard → PTY
    DispatchQueue(label: "pty.in").async {
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(STDIN_FILENO, &buf, buf.count)
            if n <= 0 { break }
            _ = write(master, buf, n)
        }
    }
    // host (remote keystrokes) → PTY
    if sock >= 0 {
        DispatchQueue(label: "host.in").async {
            var parser = WrapperFrameParser()
            var buf = [UInt8](repeating: 0, count: 65536)
            while true {
                let n = read(sock, &buf, buf.count)
                if n <= 0 { break }
                for frame in parser.receive(Data(buf[0..<n])) where frame.type == WrapperFrame.input {
                    writeAll(master, frame.payload)
                }
            }
        }
    }

    var status: Int32 = 0
    waitpid(pid, &status, 0)
    usleep(50_000)
    terminal.restore()
    if sock >= 0 { close(sock) }
    return (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
}

func connectToHost() -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return -1 }
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    _ = WrapperSocket.path.withCString { strlcpy(&addr.sun_path.0, $0, MemoryLayout.size(ofValue: addr.sun_path)) }
    let ok = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
    if ok != 0 { close(fd); return -1 }
    return fd
}

let sendLock = NSLock()
func sendFrame(_ fd: Int32, _ type: UInt8, _ payload: Data) {
    sendLock.lock(); defer { sendLock.unlock() }
    writeAll(fd, WrapperFrame.encode(type, payload))
}

func writeAll(_ fd: Int32, _ data: Data) { RawTerminal.writeAll(fd, data) }
