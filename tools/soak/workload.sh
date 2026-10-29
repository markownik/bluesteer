#!/bin/bash
# BlueSteer soak workload. Run it inside a bridged terminal (the phone's shell):
#   tools/soak/workload.sh [seconds]            (default 7200)
# Steady: one coloured, timestamped, numbered line per second.
# Bursts: every 5 minutes (at minute 4 of the block) 3000 truecolor lines in
#   under a second, far past the host's 16 KiB backpressure budget, so remotes
#   get snapshots instead of a backlog. The palette is bounded (3000 colours).
# Quiet: the first 3 minutes of every 20-minute block print nothing.
# Ends with SOAK-END, waits 90 s for final screenshots, then exits the shell.
DURATION=${1:-7200}
start=$(date +%s)
i=0
burst() {
  local n=$1 k r g b
  for ((k = 0; k < n; k++)); do
    r=$(( (k * 37) % 256 )); g=$(( (k * 91) % 256 )); b=$(( (k * 53) % 256 ))
    printf '\e[38;2;%d;%d;%dm\e[48;5;%dm%s\e[0m burst %06d line %04d \e[1mbold\e[22m \e[4munder\e[24m lorem ipsum dolor sit amet\n' \
      "$r" "$g" "$b" $((16 + k % 216)) "$(date +%T)" "$i" "$k"
  done
}
while :; do
  el=$(( $(date +%s) - start ))
  [ "$el" -ge "$DURATION" ] && break
  if [ $(( (el / 60) % 20 )) -lt 3 ]; then sleep 1; i=$((i + 1)); continue; fi
  [ $(( el % 300 )) -eq 240 ] && burst 3000
  printf '\e[38;5;%dm%s #%06d\e[0m\n' $((16 + i % 216)) "$(date +%T)" "$i"
  i=$((i + 1))
  sleep 1
done
printf 'SOAK-END #%06d\n' "$i"
sleep 90
exit
