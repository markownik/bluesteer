#!/usr/bin/env python3
"""Turns a tools/soak run directory into report.md with PASS/FAIL lines.

    python3 -I tools/soak/soak-report.py tools/soak/runs/<timestamp>

Criteria (tools/soak/README.md): the host stays alive with bounded memory,
no protocol errors outside drop windows, every drop is followed by a
re-established link and a re-subscribe for every phone, the Android app
stays alive with bounded memory, and the last workload line is on screen.
"""
import datetime
import re
import sys
from pathlib import Path

run = Path(sys.argv[1])
lines = []
results = []


def check(ok, text):
    results.append((ok, text))
    lines.append(f"- {'PASS' if ok else 'FAIL'}: {text}")


def read_tsv(name):
    rows = []
    p = run / name
    if p.exists():
        for line in p.read_text().splitlines():
            rows.append(line.split("\t"))
    return rows


def host_time(line):
    m = re.match(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+)Z", line)
    return datetime.datetime.fromisoformat(m.group(1)).replace(tzinfo=datetime.timezone.utc).timestamp() if m else None


events = [(float(t), kind, detail) for t, kind, *rest in read_tsv("events.tsv") for detail in [rest[0] if rest else ""]]
start = next((t for t, k, _ in events if k == "start"), None)
end = next((t for t, k, _ in events if k == "end"), None)
host_log = (run / "host.log").read_text().splitlines() if (run / "host.log").exists() else []
audit = (run / "audit.log").read_text().splitlines() if (run / "audit.log").exists() else []
logcat = (run / "logcat.txt").read_text(errors="replace").splitlines() if (run / "logcat.txt").exists() else []

lines.append(f"# Soak report: {run.name}")
if start and end:
    lines.append(f"\n{datetime.datetime.fromtimestamp(start):%Y-%m-%d %H:%M} → {datetime.datetime.fromtimestamp(end):%H:%M} "
                 f"({(end - start) / 60:.0f} min)\n")

# 1. Host alive, no crash report.
pid_start = (run / "host-pid-start.txt").read_text().strip() if (run / "host-pid-start.txt").exists() else ""
pid_end = (run / "host-pid-end.txt").read_text().strip() if (run / "host-pid-end.txt").exists() else ""
diag_before = (run / "diag-before.txt").read_text().strip() if (run / "diag-before.txt").exists() else ""
diag_after = (run / "diag-after.txt").read_text().strip() if (run / "diag-after.txt").exists() else ""
check(pid_start and pid_start == pid_end, f"host alive with the same pid ({pid_start} → {pid_end or 'gone'})")
check(not (diag_after and diag_after != diag_before and "BlueSteer" in diag_after), f"no new crash report (latest: {diag_after or 'none'})")

# 2. Host memory.
rss = [(float(t), int(kb)) for t, kb in read_tsv("host-rss.tsv") if kb.isdigit()]
if len(rss) >= 20:
    warm = [r for r in rss if r[0] - rss[0][0] >= 15 * 60] or rss
    growth = (rss[-1][1] - warm[0][1]) / 1024
    tail = rss[-60:]
    n = len(tail)
    xs = [(t - tail[0][0]) / 60 for t, _ in tail]
    ys = [kb for _, kb in tail]
    mx, my = sum(xs) / n, sum(ys) / n
    slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / max(1e-9, sum((x - mx) ** 2 for x in xs))
    check(growth <= 20 and slope <= 50, f"host RSS {rss[0][1] / 1024:.1f} → {rss[-1][1] / 1024:.1f} MB; growth after warm-up {growth:+.1f} MB, slope {slope:.0f} KB/min")
else:
    check(False, f"host RSS: only {len(rss)} samples")

# 3. Protocol health outside drop windows.
windows = []
for t, k, _ in events:
    if k in ("phone-off", "mac-off"):
        windows.append([t - 2, None])
    elif k in ("phone-on", "mac-on") and windows and windows[-1][1] is None:
        windows[-1][1] = t + 30
for w in windows:
    if w[1] is None:
        w[1] = w[0] + 60


def in_window(t):
    return any(a <= t <= b for a, b in windows)


bad = re.compile(r"protocol error|rejected selector|send failed|decrypt|handshake or protocol error", re.I)
host_errors = [l for l in host_log if bad.search(l) and (host_time(l) or 0) >= (start or 0)]
outside = [l for l in host_errors if not in_window(host_time(l) or 0)]
check(not outside, f"host protocol errors outside drop windows: {len(outside)} (inside: {len(host_errors) - len(outside)})")
for l in outside[:5]:
    lines.append(f"    {l[:140]}")

# 4. Every drop recovers, per phone.
names = sorted({m.group(1) for l in host_log for m in [re.search(r"established as (.+)$", l)] if m})
drop_rows = []
all_recovered = True
for t, k, _ in events:
    if k not in ("phone-on", "mac-on"):
        continue
    affected = names if k == "mac-on" else [n for n in names if "iPhone" not in n]
    for name in affected:
        est = next((host_time(l) for l in host_log if f"established as {name}" in l and (host_time(l) or 0) > t), None)
        link = None
        if est is not None:
            est_line = next(l for l in host_log if f"established as {name}" in l and host_time(l) == est)
            link = re.search(r"link (\S+) established", est_line).group(1)
        sub = next((host_time(l) for l in host_log if link and f"link {link} received subscribe" in l and (host_time(l) or 0) > t), None)
        ok = est is not None and est - t <= 30 and sub is not None and sub - t <= 30
        all_recovered &= ok
        drop_rows.append((datetime.datetime.fromtimestamp(t).strftime("%H:%M:%S"), k, name,
                          f"{est - t:.1f}" if est else "—", f"{sub - t:.1f}" if sub else "—", "ok" if ok else "FAIL"))
check(all_recovered and drop_rows, f"every drop re-established and re-subscribed within 30 s ({len(drop_rows)} drop/phone pairs)")
ests = [float(r[3]) for r in drop_rows if r[3] != "—"]
if ests:
    ests.sort()
    lines.append(f"    re-establish after radio on: median {ests[len(ests) // 2]:.1f} s, p95 {ests[int((len(ests) - 1) * 0.95)]:.1f} s, max {ests[-1]:.1f} s (target median ≤ 5 s)")

# 5. Android app.
mem = [(float(t), int(pss), pid) for t, pss, pid in read_tsv("android-mem.tsv") if pss.isdigit()]
pids = {pid for _, _, pid in mem if pid not in ("0", "")}
if mem:
    warm = [m for m in mem if m[0] - mem[0][0] >= 15 * 60] or mem
    growth = (mem[-1][1] - warm[0][1]) / 1024
    check(len(pids) == 1 and growth <= 50, f"Android app pid stable ({', '.join(sorted(pids))}), PSS {mem[0][1] / 1024:.0f} → {mem[-1][1] / 1024:.0f} MB ({growth:+.0f} MB after warm-up)")
else:
    check(False, "Android memory: no samples")
phone_bad = [l for l in logcat if "send failed" in l or "error:" in l]
check(not phone_bad, f"no 'send failed' / 'error:' lines in the app log ({len(phone_bad)})")
phone_recon = []
dropped_at = None
for l in logcat:
    m = re.match(r"(\d\d-\d\d \d\d:\d\d:\d\d\.\d+)", l)
    if not m:
        continue
    ts = datetime.datetime.strptime(f"{datetime.date.today().year}-{m.group(1)}", "%Y-%m-%d %H:%M:%S.%f").timestamp()
    if "[link] dropped" in l or "[link] radio off" in l:
        dropped_at = dropped_at or ts
    elif "[link] connected" in l and dropped_at:
        phone_recon.append(ts - dropped_at)
        dropped_at = None
if phone_recon:
    lines.append(f"    phone-side drop → connected: median {sorted(phone_recon)[len(phone_recon) // 2]:.1f} s over {len(phone_recon)} reconnects (includes the radio-off time)")

# 6. Sessions and helpers.
check(any("session exited" in l for l in audit[-50:]), "the workload's shell exited at the end (audit: session exited)")
helpers = (run / "helpers-end.txt").read_text().strip() if (run / "helpers-end.txt").exists() else ""
lines.append(f"    helpers still running at the end: {len(helpers.splitlines())} (the soak session should be gone; others may be yours)")
lines.append("    final screens: look at android/final.png and ios/final.png for SOAK-END")

lines.append("\n## Drops\n")
lines.append("| radio on | kind | phone | established after (s) | subscribed after (s) | |")
lines.append("|---|---|---|---|---|---|")
for r in drop_rows:
    lines.append("| " + " | ".join(r) + " |")

lines.append("\n## Result\n")
passed = sum(1 for ok, _ in results if ok)
lines.append(f"{passed}/{len(results)} checks passed: **{'PASS' if passed == len(results) else 'FAIL'}**")
print("\n".join(lines))
