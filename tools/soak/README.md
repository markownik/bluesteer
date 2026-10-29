# Soak test

A long session with periodic link drops, run against the real host and the
real phones (Phase 4). Two hours fits a working session; `--minutes` changes it.

## What it does

- `workload.sh` runs inside the bridged terminal (the phone's shell runs on
  the Mac): one coloured, numbered line per second; a 3000-line truecolor
  burst every 5 minutes (past the host's 16 KiB backpressure budget, so
  remotes get snapshots instead of a backlog); three quiet minutes every 20.
  It ends with `SOAK-END`, waits 90 s for the final screenshots and exits.
- `soak.sh` samples the host's RSS and the Android app's PSS every minute,
  restarts the phone's radio every 10 minutes (from minute 5, 20 s off) and,
  with `--drops phone+mac`, the Mac's radio every 30 minutes (from minute 20,
  15 s off; this also drops the Mac's other Bluetooth devices). It screenshots
  the phones every 10 minutes and after every restore, keeps the app's log
  (`adb logcat -s flutter`), and copies the host's stderr log and the audit
  log into `runs/<timestamp>/`.
- `soak-report.py` reads that directory and prints `report.md`.

## Setup

1. Build and start the host with its stderr in a file:
   `tools/bundle-app.sh && nohup build/BlueSteer.app/Contents/MacOS/BlueSteerHost > /tmp/host.log 2>&1 &`
2. Samsung: release build installed, screen kept on (`adb shell svc power stayon usb`),
   connected to the Mac with a terminal open (the page unsubscribes while hidden, so a
   locked phone voids the run).
3. iPhone (optional): release build installed, Auto-Lock off, `tools/ios-ui-driver`
   started (`UDID=… driver.sh start`), the same session open. Its server stops after 2 h.
4. `tools/soak/soak.sh --host-log /tmp/host.log --drops phone+mac [--ios-udid …]`
   types the workload into the Samsung's terminal and runs unattended. Use
   `--no-type-workload` to start the workload yourself (for example as a wrapped
   session: `bluesteer run tools/soak/workload.sh`).

## Pass criteria

- The host is alive with the same pid and no new crash report.
- Host RSS growth after a 15-minute warm-up ≤ 20 MB and slope ≤ 50 KB/min over the last hour.
- No protocol, handshake or decryption errors in the host log outside the drop windows
  (2 s before a radio goes off until 30 s after it is back).
- Every drop is followed, for every phone, by `established as <name>` and a
  `received subscribe` within 30 s of the radio coming back; the target median is 5 s.
- The Android app keeps its pid, its PSS grows ≤ 50 MB after warm-up, and its log has
  no `send failed` or `error:` lines.
- The workload's shell exited at the end (audit log) and `SOAK-END` is visible on the
  final screenshots (a manual look at `android/final.png` and `ios/final.png`).

The in-process counterpart is `apps/host/Tests/HostCoreTests/SoakTests.swift`:
50 connect → handshake → subscribe → type → disconnect cycles against one hub
(`SOAK_CYCLES=500 swift test --filter SoakTests` for more).
