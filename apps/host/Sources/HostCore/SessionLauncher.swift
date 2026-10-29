import Darwin
import Foundation

/// Starts a host-spawned session as a detached `bluesteer serve-session`
/// helper. The helper owns the PTY in its own session group, so it outlives
/// the host app and re-attaches over the wrapper socket after a relaunch
/// (docs/architecture.md, "Session sources").
public enum SessionLauncher {
    /// The `bluesteer` executable next to this one (the app bundle or the build directory).
    public static var cli: URL? {
        guard let exe = Bundle.main.executableURL else { return nil }
        let url = exe.deletingLastPathComponent().appendingPathComponent("bluesteer")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    public enum Error: Swift.Error, LocalizedError {
        case cliMissing
        case spawnFailed(Int32)
        public var errorDescription: String? {
            switch self {
            case .cliMissing: "the bluesteer helper is not next to the host executable"
            case .spawnFailed(let rc): "could not start the session helper (\(String(cString: strerror(rc))))"
            }
        }
    }

    @discardableResult
    public static func spawn(id: SessionID, command: [String], cwd: String, rows: Int, cols: Int) throws -> pid_t {
        guard let cli else { throw Error.cliMissing }
        let argv = [cli.path, "serve-session", "--id", id.rawValue, "--cwd", cwd, "--rows", "\(rows)", "--cols", "\(cols)", "--"] + command
        var attr: posix_spawnattr_t? = nil
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        // Its own session (no controlling terminal, no SIGHUP from us) and none of our descriptors.
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))
        var actions: posix_spawn_file_actions_t? = nil
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)
        let cargs = argv.map { strdup($0) } + [nil]
        defer { for p in cargs { free(p) } }
        var pid: pid_t = 0
        let rc = posix_spawn(&pid, cli.path, &actions, &attr, cargs, environ)
        guard rc == 0 else { throw Error.spawnFailed(rc) }
        reap(pid)
        return pid
    }

    /// Collects the helper's exit status when it ends, so no zombie is left behind.
    private static var reapers: [pid_t: DispatchSourceProcess] = [:]
    private static func reap(_ pid: pid_t) {
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler {
            var status: Int32 = 0
            waitpid(pid, &status, WNOHANG)
            reapers[pid] = nil
        }
        source.resume()
        reapers[pid] = source
    }
}
