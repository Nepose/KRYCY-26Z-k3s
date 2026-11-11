#!/usr/bin/env bash
# Wypisuje adres IPv4 węzła: z podanego interfejsu albo (bez argumentu) z trasy domyślnej.
set -euo pipefail
iface=${1:-}
if [ -n "$iface" ]; then
  ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}'
else
  ip -4 route get 1.1.1.1 | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}'
fi
