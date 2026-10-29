#!/usr/bin/env python3
"""Screenshot sync server for integration_test/screenshots_test.dart.

    shot-server.py <port> <ios|android> <device id> <output dir>

The test, running on the simulator or phone, GETs /shot/<name> each time a screen
is ready and waits for the reply; this takes a native capture of that device
(status bar included) into <output dir>/<name>.png. tools/store-shots.sh starts it."""
import http.server, pathlib, subprocess, sys, urllib.parse

port, kind, device, out = int(sys.argv[1]), sys.argv[2], sys.argv[3], pathlib.Path(sys.argv[4])


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        name = urllib.parse.unquote(self.path.removeprefix("/shot/")).strip("/")
        if not self.path.startswith("/shot/") or not name or ".." in name:
            self.send_error(404); return
        path = out / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        if kind == "ios":
            r = subprocess.run(["xcrun", "simctl", "io", device, "screenshot", str(path)], capture_output=True, text=True)
        else:
            r = subprocess.run(["adb", "-s", device, "exec-out", "screencap", "-p"], capture_output=True)
            if r.returncode == 0:
                path.write_bytes(r.stdout)
        if r.returncode != 0:
            self.send_error(500, "capture failed"); sys.stderr.write(str(r.stderr) + "\n"); return
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok\n")
        print(f"screenshot {path}", flush=True)

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
