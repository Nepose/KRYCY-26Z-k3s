#!/usr/bin/env bash
# Część węzłowa triage (X.3). triage.sh przesyła ten skrypt na stdin węzła i uruchamia jako root:
#   bash -s -- NAMESPACE POD POD_UID [CONTAINER_ID...]
# Wynik: archiwum tar na stdout. Wszystkie komunikaty idą na stderr.
set -uo pipefail
NS=$1; POD=$2; POD_UID=$3; shift 3
T=$(mktemp -d)
exec 3>&1 1>&2          # fd 3 = strumień tar; zwykłe wyjście na stderr

c() { local f=$1; shift; "$@" > "$T/$f" 2>&1 || echo "rc=$? $*" >> "$T/errors.txt"; }

c date-utc.txt date -u +%FT%T.%NZ
c uname.txt uname -a
c crictl-pods.txt k3s crictl pods
c crictl-ps-a.txt k3s crictl ps -a

# Logi poda prosto z dysku węzła (z rotowanymi plikami i poprzednimi instancjami kontenerów)
d="/var/log/pods/${NS}_${POD}_${POD_UID}"
[ -d "$d" ] && tar -C /var/log/pods -cf "$T/var-log-pods.tar" "$(basename "$d")"

for id in "$@"; do
  s=${id:0:13}
  c "container-$s-inspect.json" k3s crictl inspect "$id"
  pid=$(k3s crictl inspect -o go-template --template '{{.info.pid}}' "$id" 2>/dev/null)
  if [ -z "$pid" ] || [ "$pid" = 0 ] || [ ! -d "/proc/$pid" ]; then
    echo "kontener $s nie działa, pomijam procesy, sieć i FS" >> "$T/errors.txt"
    continue
  fi
  # Procesy w przestrzeni nazw PID kontenera
  ns=$(readlink "/proc/$pid/ns/pid")
  {
    printf 'PID\tPPID\tUID\tEXE\tCMDLINE\n'
    for p in /proc/[0-9]*; do
      [ "$(readlink "$p/ns/pid" 2>/dev/null)" = "$ns" ] || continue
      printf '%s\t%s\t%s\t%s\t%s\n' "${p#/proc/}" \
        "$(awk '/^PPid:/{print $2}' "$p/status" 2>/dev/null)" \
        "$(awk '/^Uid:/{print $2}' "$p/status" 2>/dev/null)" \
        "$(readlink "$p/exe" 2>/dev/null)" \
        "$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)"
    done
  } > "$T/container-$s-processes.tsv"
  # Połączenia sieciowe widziane z przestrzeni nazw sieci kontenera
  c "container-$s-sockets.txt" nsenter -t "$pid" -n ss -tunap
  # Zmienne środowiskowe procesu głównego (scenariusz 4; dane wrażliwe!)
  tr '\0' '\n' < "/proc/$pid/environ" > "$T/container-$s-environ.txt" 2>/dev/null
  # Zapisywalna warstwa overlayfs = wszystko, co zmieniono w FS kontenera (np. podrzucone binarki)
  upper=$(grep -o 'upperdir=[^,]*' "/proc/$pid/mountinfo" | head -1 | cut -d= -f2)
  [ -n "$upper" ] && [ -d "$upper" ] && tar -C "$upper" -cf "$T/container-$s-upperdir.tar" .
done

c journal-k3s.txt journalctl -u k3s -u k3s-agent --since "-24h" -o short-iso-precise --no-pager

tar -C "$T" -cf - . >&3
rm -rf "$T"
