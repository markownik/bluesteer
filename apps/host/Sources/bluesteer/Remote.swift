// The console remote: this Mac as a BlueSteer remote attached to a host over BLE.
//
//   bluesteer pair [bluesteer://pair?...]   pair with a nearby Mac (code comparison) or from a link
//   bluesteer hosts                          list paired Macs
//   bluesteer connect [name] [--new]         attach this terminal to a session on a paired Mac

import BlueSteerProtocol
import CoreBluetooth
import Darwin
import Foundation
import HostCore
import RemoteCore

let remoteQueue = DispatchQueue(label: "dev.bluesteer.remote")

func fail(_ message: String) -> Never { fputs("bluesteer: \(message)\n", stderr); exit(1) }

/// Runs `body` on the remote queue and blocks until it calls `done`.
func block<T>(_ timeout: TimeInterval = 30, _ body: @escaping (@escaping (T) -> Void) -> Void) -> T? {
    let sem = DispatchSemaphore(value: 0)
    var result: T?
    remoteQueue.async { body { r in if result == nil { result = r; sem.signal() } } }
    return sem.wait(timeout: .now() + timeout) == .success ? result : nil
}

func newLink() -> CentralLink {
    let link = CentralLink(queue: remoteQueue)
    let error: Error?? = block(10) { done in link.waitForPower { done($0) } }
    if let e = error ?? nil { fail(e.localizedDescription) }
    if error == nil { fail("Bluetooth did not become available") }
    return link
}

struct PairingLink {
    let id: String, psk: Data, name: String
    init?(_ text: String) {
        guard let url = URLComponents(string: text), url.scheme == "bluesteer", url.host == "pair",
              let id = url.queryItems?.first(where: { $0.name == "id" })?.value,
              let pskText = url.queryItems?.first(where: { $0.name == "psk" })?.value else { return nil }
        var b64 = pskText.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let psk = Data(base64Encoded: b64), psk.count == 32 else { return nil }
        self.id = id; self.psk = psk
        self.name = url.queryItems?.first(where: { $0.name == "name" })?.value ?? "Mac"
    }
}

/// Scans until a host with `id` answers, connecting to each candidate in turn; nil after `timeout`.
func findHost(_ link: CentralLink, id: String, timeout: TimeInterval = 20) -> ConnectedHostInfo? {
    let info: ConnectedHostInfo? = block(timeout) { done in
        var tried = Set<UUID>()
        var busy = false
        var waiting: [CBPeripheral] = []
        func tryNext() {
            guard !busy, let p = waiting.first else { return }
            waiting.removeFirst()
            busy = true
            RemoteSession.log("connecting to \(p.identifier)")
            link.connect(p) { result in
                busy = false
                if case .success(let info) = result, info.id == id { link.stopScan(); done(info); return }
                RemoteSession.log("\(p.identifier): \((try? result.get()).map { "is \($0.name), not the Mac we want" } ?? "connect failed")")
                link.close()
                tryNext()
            }
        }
        link.onDiscovered = { host in
            guard tried.insert(host.peripheral.identifier).inserted else { return }
            RemoteSession.log("discovered \(host.peripheral.identifier) (\(host.name))")
            waiting.append(host.peripheral)
            tryNext()
        }
        link.startScan()
    }
    if info == nil { remoteQueue.sync { link.stopScan() } }
    return info
}

let notInRange = "no Mac with that id is in range (is BlueSteer running there?)"

func cmdPair(_ args: [String]) -> Int32 {
    let store = try! RemoteStore()
    let link = newLink()
    if let text = args.first {
        guard let pairing = PairingLink(text) else { fail("that is not a BlueSteer pairing link") }
        print("Looking for \(pairing.name)…")
        guard let info = findHost(link, id: pairing.id) else { fail(notInRange) }
        let session = try! RemoteSession(transport: link, identity: store.keyPair, deviceName: store.deviceName, mode: .psk(pairing.psk), queue: remoteQueue)
        let ready: Result<Void, Error>? = block(20) { done in
            session.onReady = { done(.success(())) }
            session.onError = { done(.failure($0)) }
            try? session.start()
        }
        switch ready {
        case .success: break
        case .failure(let e): fail("pairing failed: \(e.localizedDescription)")
        case nil: fail("pairing timed out")
        }
        try! store.add(RemoteStore.Host(id: info.id, name: info.name, hostKey: session.hostKey!))
        print("Paired with \(info.name).")
        session.close()
        return 0
    }

    print("Looking for Macs running BlueSteer…")
    var found: [DiscoveredHost] = []
    _ = block(4) { (done: @escaping (Bool) -> Void) in
        link.onDiscovered = { host in
            if !found.contains(where: { $0.peripheral.identifier == host.peripheral.identifier }) { found.append(host) }
        }
        link.startScan()
    }
    remoteQueue.sync { link.stopScan() }
    guard !found.isEmpty else { fail("no Mac running BlueSteer is in range") }
    // A Mac advertises no local name next to the service UUID and a Mac central caches
    // none either (the scan result carries only the peripheral id), so each candidate's
    // Computer Name is read from its INFO characteristic, as the phones do.
    for (i, host) in found.enumerated() {
        let connected: Result<ConnectedHostInfo, Error>? = block(15) { done in link.connect(host.peripheral) { done($0) } }
        if case .success(let info)? = connected {
            print("  [\(i + 1)] \(info.name)")
            _ = block(3) { (done: @escaping (Bool) -> Void) in link.onClosed = { done(true) }; link.close() }
            link.onClosed = nil
        } else {
            print("  [\(i + 1)] \(host.name)  (did not answer)")
        }
    }
    var choice = 1
    if found.count > 1 {
        print("Pair with [1-\(found.count)]: ", terminator: "")
        guard let line = readLine(), let n = Int(line), (1...found.count).contains(n) else { fail("no such entry") }
        choice = n
    }
    let target = found[choice - 1]
    let connected: Result<ConnectedHostInfo, Error>? = block(15) { done in link.connect(target.peripheral) { done($0) } }
    guard case .success(let info)? = connected else { fail("could not connect to \(target.name)") }
    guard info.pairingOpen else { fail("open “Pair a remote…” in the BlueSteer menu on \(info.name) first") }
    let session = try! RemoteSession(transport: link, identity: store.keyPair, deviceName: store.deviceName, mode: .code, queue: remoteQueue)
    let code: String? = block(20) { done in
        session.onPairingCode = { done($0) }
        session.onError = { e in fputs("bluesteer: \(e.localizedDescription)\n", stderr); exit(1) }
        try? session.start()
    }
    guard let code else { fail("the handshake timed out") }
    print("\n    \(code.prefix(3)) \(code.suffix(3))\n")
    print("Does \(info.name) show the same code? Confirm there too. [y/N] ", terminator: "")
    guard readLine()?.lowercased().hasPrefix("y") == true else { session.close(); print("Cancelled."); return 1 }
    let ready: Result<Void, Error>? = block(120) { done in
        session.onReady = { done(.success(())) }
        session.onError = { done(.failure($0)) }
        try? session.confirmPairing()
    }
    switch ready {
    case .success: break
    case .failure(let e): fail(e.localizedDescription)
    case nil: fail("the Mac did not confirm within 2 minutes")
    }
    try! store.add(RemoteStore.Host(id: info.id, name: info.name, hostKey: session.hostKey!))
    print("Paired with \(info.name).")
    session.close()
    return 0
}

func cmdHosts() -> Int32 {
    let store = try! RemoteStore()
    if store.hosts.isEmpty { print("No paired Macs. Run `bluesteer pair` next to one.") }
    for h in store.hosts { print("\(h.name)  (\(h.id.prefix(8))…)") }
    return 0
}

func cmdConnect(_ args: [String]) -> Int32 {
    let store = try! RemoteStore()
    let wantNew = args.contains("--new")
    let name = args.first { !$0.hasPrefix("--") }
    let host: RemoteStore.Host
    if let name {
        guard let h = store.hosts.first(where: { $0.name.lowercased().hasPrefix(name.lowercased()) }) else { fail("no paired Mac called \(name); see `bluesteer hosts`") }
        host = h
    } else {
        guard store.hosts.count == 1, let h = store.hosts.first else {
            fail(store.hosts.isEmpty ? "no paired Macs; run `bluesteer pair` first" : "several Macs are paired; say which: bluesteer connect <name>")
        }
        host = h
    }

    let terminal = RawTerminal()
    var sessionID: String?
    let backoff = [1, 2, 4, 8, 10]
    var attempt = 0
    while true {
        let link = newLink()
        if attempt == 0 { print("Looking for \(host.name)…") } else { RemoteSession.log("attempt \(attempt): scanning") }
        guard let info = findHost(link, id: host.id, timeout: attempt == 0 ? 20 : 15) else {
            // The Mac's radio or the host may take a while to come back: keep scanning.
            if attempt == 0 { fail(notInRange) }
            RemoteSession.log("attempt \(attempt): not found")
            if attempt >= backoff.count { fail("could not reach \(host.name)") }
            sleep(UInt32(backoff[min(attempt, backoff.count - 1)])); attempt += 1; continue
        }
        let session = try! RemoteSession(transport: link, identity: store.keyPair, deviceName: store.deviceName, mode: .paired(hostKey: host.hostKey), queue: remoteQueue)
        let ready: Result<Void, Error>? = block(20) { done in
            session.onReady = { done(.success(())) }
            session.onError = { done(.failure($0)) }
            try? session.start()
        }
        guard case .success? = ready else {
            RemoteSession.log("attempt \(attempt): handshake \(ready == nil ? "timed out" : "failed")")
            if case .failure(let e)? = ready { fputs("bluesteer: \(e.localizedDescription)\n", stderr) }
            if attempt >= backoff.count { fail("could not reach \(host.name)") }
            sleep(UInt32(backoff[min(attempt, backoff.count - 1)])); attempt += 1; continue
        }
        if sessionID == nil {
            sessionID = chooseSession(session, info: info, wantNew: wantNew)
        }
        guard let sid = sessionID else { fail("no session") }
        terminal.enterRaw()
        let attach = TerminalAttach(session: session, sessionID: sid) // held here: its handlers only weakly reference it
        let outcome: TerminalAttach.Outcome? = block(.infinity) { done in attach.run(completion: done) }
        terminal.restore()
        switch outcome {
        case .detached?:
            try? session.send(BSEnvelope.with { $0.unsubscribe = BSUnsubscribe.with { $0.cmdID = session.nextCommandID(); $0.sessionID = sid } })
            print("\r\n[bluesteer] detached; the session keeps running on \(host.name)")
            remoteQueue.sync { session.close() }
            return 0
        case .sessionExited(let code)?:
            print("\r\n[bluesteer] session exited (\(code))")
            remoteQueue.sync { session.close() }
            return code
        case .error(let e)?:
            fail("\r\n\(e.localizedDescription)")
        case .linkLost?, nil:
            print("\r\n[bluesteer] link lost, reconnecting… (Ctrl-C to give up)")
            attempt = 1
            sleep(1)
        }
    }
}

/// Lists the host's sessions and returns the one to attach to (starting a shell when asked or when there is none).
func chooseSession(_ session: RemoteSession, info: ConnectedHostInfo, wantNew: Bool) -> String {
    let size = RawTerminal.size
    func startShell() -> String {
        let ack: BSAck? = block(15) { done in
            let cmd = session.nextCommandID()
            session.onEnvelope = { e in if case .ack(let a) = e.body, a.cmdID == cmd { done(a) } }
            try? session.send(BSEnvelope.with {
                $0.newSession = BSNewSession.with { $0.cmdID = cmd; $0.preset = "shell"; $0.rows = UInt32(size.rows); $0.cols = UInt32(size.cols) }
            })
        }
        guard let ack, ack.ok else { fail("could not start a shell: \(ack?.error ?? "timeout")") }
        return ack.sessionID
    }
    if wantNew { return startShell() }
    let list: BSSessionList? = block(15) { done in
        session.onEnvelope = { e in if case .sessionList(let l) = e.body { done(l) } }
        try? session.send(BSEnvelope.with { $0.listSessions = BSListSessions.with { $0.cmdID = session.nextCommandID() } })
    }
    let sessions = (list?.sessions ?? []).filter { $0.status != .exited }
    if sessions.isEmpty { print("No terminal on \(info.name); starting a shell."); return startShell() }
    if sessions.count == 1 { return sessions[0].sessionID }
    print("Terminals on \(info.name):")
    for (i, s) in sessions.enumerated() {
        print("  [\(i + 1)] \(s.cwd)  \(s.title.isEmpty ? s.command : s.title)\(s.source == .wrapped ? "  (your terminal)" : "")")
    }
    print("  [n] new shell\nAttach to: ", terminator: "")
    guard let line = readLine() else { exit(1) }
    if line.lowercased() == "n" { return startShell() }
    guard let n = Int(line), (1...sessions.count).contains(n) else { fail("no such entry") }
    return sessions[n - 1].sessionID
}
