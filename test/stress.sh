#!/usr/bin/env bash
# Stress test (SPEC.md section 13, M1): 50 pushes/s for 10 s against the
# running shell. Passes when the shell logs no QML errors, its CPU spike
# stays under 10% of one core in its busiest second, it is back to idle
# within 2 s, and every
# activity is cleaned up afterwards.
#
# CPU is the shell process's own time from /proc (the ipc client processes
# this script spawns are not counted). RATE and SECONDS_RUN override.
set -uo pipefail

RATE=${RATE:-50}
SECONDS_RUN=${SECONDS_RUN:-10}
pid=$(pgrep -f 'quickshell.*-p /usr/share/omarchy/shell' | head -1)
[[ -n $pid ]] || { echo "FAIL: omarchy-shell is not running"; exit 1; }
omarchy-shell dev.deusvult.omavisor version >/dev/null || { echo "FAIL: omavisor IPC target unreachable"; exit 1; }
hz=$(getconf CLK_TCK)

ticks() { awk '{ print $14 + $15 }' "/proc/$pid/stat"; }
# Percent of one core used by the shell over `$1` seconds.
cpu_over() {
  local a b
  a=$(ticks); sleep "$1"; b=$(ticks)
  awk -v d=$((b - a)) -v hz="$hz" -v s="$1" 'BEGIN { printf "%.1f", d / hz / s * 100 }'
}

since=$(date '+%Y-%m-%d %H:%M:%S')
idle_before=$(cpu_over 2)
echo "idle before: ${idle_before}%"

# Per-second CPU of the shell while pushing: the busiest second is the spike.
peak=0
t0=$(date +%s.%N)
for ((s = 0; s < SECONDS_RUN; s++)); do
  second_start=$(date +%s.%N)
  a=$(ticks)
  for ((i = 0; i < RATE; i++)); do
    n=$((s * RATE + i))
    omarchy-shell dev.deusvult.omavisor push "{\"id\":\"stress:$((n % 30))\",\"title\":\"Stress $n\",\"progress\":$(( i * 2 % 100 )).0e-2,\"priority\":\"low\",\"ttl\":60}" >/dev/null &
  done
  wait
  rest=$(awk -v a="$second_start" -v b="$(date +%s.%N)" 'BEGIN { r = 1 - (b - a); print (r > 0 ? r : 0) }')
  sleep "$rest"
  b=$(ticks)
  span=$(awk -v a="$second_start" -v b="$(date +%s.%N)" 'BEGIN { print b - a }')
  peak=$(awk -v d=$((b - a)) -v hz="$hz" -v s="$span" -v p="$peak" 'BEGIN { v = d / hz / s * 100; printf "%.1f", (v > p ? v : p) }')
done
elapsed=$(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN { print b - a }')
spike=$peak
echo "busiest second: ${spike}% ($((RATE * SECONDS_RUN)) pushes in ${elapsed}s)"

# Idle again within 2 s: the shell's use in the second after the 2 s mark.
sleep 2
after=$(cpu_over 1)
echo "at 2-3 s after: ${after}%"

count=$(omarchy-shell dev.deusvult.omavisor list | jq '[.[] | select(.id | startswith("stress:"))] | length')
echo "stress activities listed: $count (max 20 kept)"
for ((n = 0; n < 30; n++)); do omarchy-shell dev.deusvult.omavisor end "stress:$n" >/dev/null; done

errors=$(journalctl --user -b --since "$since" 2>/dev/null | grep -i -E 'omavisor' | grep -i -E 'error|TypeError|ReferenceError|binding loop' | grep -v qmlscanner || true)

fails=0
[[ -z $errors ]] || { echo "FAIL QML errors:"; echo "$errors"; fails=1; }
awk -v v="$spike" 'BEGIN { exit !(v < 10) }' || { echo "FAIL CPU during stress ${spike}% >= 10%"; fails=1; }
awk -v v="$after" -v i="$idle_before" 'BEGIN { exit !(v <= i + 1.0) }' || { echo "FAIL not idle 2 s after (${after}% vs ${idle_before}%)"; fails=1; }
(( count <= 20 )) || { echo "FAIL more than 20 activities kept"; fails=1; }
(( fails == 0 )) && echo "PASS"
exit $fails
