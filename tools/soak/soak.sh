#!/bin/bash
# BlueSteer soak orchestrator (docs: tools/soak/README.md).
#
#   tools/soak/soak.sh --host-log <host stderr log> [--minutes 120] [--drops phone|phone+mac]
#                      [--adb <serial>] [--ios-udid <udid>] [--no-type-workload]
#
# Runs on the Mac next to a host started with its stderr in a file, an Android
# phone on adb attached to a session, and optionally an iPhone driven by
# tools/ios-ui-driver (already started). Every minute it samples the host's
# memory and the Android app's; on a schedule it restarts the phone's radio
# (every 10 min from minute 5) and, with --drops phone+mac, the Mac's radio
# (every 30 min from minute 20); it screenshots the phones every 10 min and
# after every restore. Everything lands in tools/soak/runs/<timestamp>/ and
# soak-report.py turns it into report.md with PASS/FAIL lines.
set -u
here=$(cd "$(dirname "$0")" && pwd)
MINUTES=120; DROPS=phone+mac; SERIAL=ADB-SERIAL; IOS_UDID=""; HOST_LOG=""; TYPE_WORKLOAD=1
while [ $# -gt 0 ]; do
  case "$1" in
    --host-log) HOST_LOG=$2; shift 2 ;;
    --minutes) MINUTES=$2; shift 2 ;;
    --drops) DROPS=$2; shift 2 ;;
    --adb) SERIAL=$2; shift 2 ;;
    --ios-udid) IOS_UDID=$2; shift 2 ;;
    --no-type-workload) TYPE_WORKLOAD=0; shift ;;
    *) echo "unknown option $1"; exit 64 ;;
  esac
done
[ -n "$HOST_LOG" ] || { echo "--host-log is required"; exit 64; }
A() { adb -s "$SERIAL" "$@"; }
IOS() { UDID=$IOS_UDID "$here/../ios-ui-driver/driver.sh" "$@"; }
HOST_PID=$(pgrep -x BlueSteerHost | head -1)
[ -n "$HOST_PID" ] || { echo "no BlueSteerHost running"; exit 1; }
RUN="$here/runs/$(date +%Y%m%d-%H%M)"
mkdir -p "$RUN/android" "$RUN/ios"
AUDIT="$HOME/Library/Application Support/BlueSteer/audit.log"
APP=dev.bluesteer.bluesteer_remote
now() { date +%s; }
event() { printf '%s\t%s\t%s\n' "$(now)" "$1" "${2:-}" >> "$RUN/events.tsv"; echo "$(date +%T) $1 ${2:-}"; }
shot() {
  A exec-out screencap -p > "$RUN/android/$1.png" 2>/dev/null
  [ -n "$IOS_UDID" ] && IOS shot "$RUN/ios/$1.png" >/dev/null 2>&1
  event shot "$1"
}
sample() {
  printf '%s\t%s\n' "$(now)" "$(ps -o rss= -p "$HOST_PID" | tr -d ' ')" >> "$RUN/host-rss.tsv"
  local pid pss
  pid=$(A shell pidof "$APP" 2>/dev/null | tr -d '\r ')
  pss=$(A shell dumpsys meminfo "$APP" 2>/dev/null | awk '/TOTAL PSS:/ {print $3; exit}')
  printf '%s\t%s\t%s\n' "$(now)" "${pss:-0}" "${pid:-0}" >> "$RUN/android-mem.tsv"
}

echo "run: $RUN (host pid $HOST_PID, $MINUTES min, drops=$DROPS)"
cp "$HOST_LOG" "$RUN/host.log.start" 2>/dev/null
ls -t "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | head -1 > "$RUN/diag-before.txt"
A logcat -c
A logcat -v time -s flutter > "$RUN/logcat.txt" 2>&1 &
LOGCAT_PID=$!
event start "host=$HOST_PID drops=$DROPS minutes=$MINUTES"
if [ "$TYPE_WORKLOAD" = 1 ]; then
  A shell input text "$here/workload.sh%s$((MINUTES * 60))"
  A shell input keyevent 66
  event workload-typed
fi
shot t0

START=$(now)
TOTAL=$((MINUTES * 60 + 120))
PHONE_OFF=-1; MAC_OFF=-1
while :; do
  el=$(( $(now) - START ))
  [ "$el" -ge "$TOTAL" ] && break
  [ $((el % 60)) -eq 0 ] && sample
  # Phone radio: off at minute 5, 15, 25, …; back on 20 s later.
  if [ $((el % 600)) -eq 300 ] && [ "$el" -lt $((MINUTES * 60)) ]; then
    A shell svc bluetooth disable; event phone-off; PHONE_OFF=$el
  fi
  if [ "$PHONE_OFF" -ge 0 ] && [ "$el" -eq $((PHONE_OFF + 20)) ]; then A shell svc bluetooth enable; event phone-on; fi
  if [ "$PHONE_OFF" -ge 0 ] && [ "$el" -eq $((PHONE_OFF + 50)) ]; then shot "after-phone-$((PHONE_OFF / 60))m"; PHONE_OFF=-1; fi
  # Mac radio: off at minute 20, 50, 80, 110; back on 15 s later.
  if [ "$DROPS" = "phone+mac" ] && [ $((el % 1800)) -eq 1200 ] && [ "$el" -lt $((MINUTES * 60)) ]; then
    blueutil -p 0; event mac-off; MAC_OFF=$el
  fi
  if [ "$MAC_OFF" -ge 0 ] && [ "$el" -eq $((MAC_OFF + 15)) ]; then blueutil -p 1; event mac-on; fi
  if [ "$MAC_OFF" -ge 0 ] && [ "$el" -eq $((MAC_OFF + 45)) ]; then shot "after-mac-$((MAC_OFF / 60))m"; MAC_OFF=-1; fi
  [ $((el % 600)) -eq 0 ] && [ "$el" -gt 0 ] && shot "t$((el / 60))m"
  sleep 1
done
shot final
sample
event end
kill $LOGCAT_PID 2>/dev/null
cp "$HOST_LOG" "$RUN/host.log"
cp "$AUDIT" "$RUN/audit.log"
ls -t "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | head -1 > "$RUN/diag-after.txt"
pgrep -x BlueSteerHost > "$RUN/host-pid-end.txt"
echo "$HOST_PID" > "$RUN/host-pid-start.txt"
pgrep -fl "serve-session" > "$RUN/helpers-end.txt"
python3 -I "$here/soak-report.py" "$RUN" | tee "$RUN/report.md"
