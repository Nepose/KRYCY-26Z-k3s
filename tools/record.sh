#!/usr/bin/env bash
# Nagrywa przebieg polecenia do docs/logs/ jako dowód realizacji do raportu:
# nagłówek (polecenie, czas UTC, host, commit), pełne wyjście bez kolorów, kod wyjścia i czas trwania.
# Użycie: tools/record.sh NAZWA POLECENIE...     np. tools/record.sh test make test
#         make rec T=test                         (to samo przez Makefile)
set -uo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
[ $# -ge 2 ] || { echo "Użycie: $0 NAZWA POLECENIE..." >&2; exit 2; }
name=$1; shift

dir="$REPO_ROOT/docs/logs"
mkdir -p "$dir"
file="$dir/$(date +%Y%m%d-%H%M%S)_${name}.log"
commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')
[ -z "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ] || commit="$commit + niezacommitowane zmiany"

{
  echo "# polecenie: $*"
  echo "# start:     $(date -u +%FT%TZ) (UTC)"
  echo "# host:      $(uname -sm), $(sw_vers -productVersion 2>/dev/null || uname -r)"
  echo "# commit:    $commit"
  echo
} > "$file"

start=$(date +%s)
# Na terminal idzie wyjście z kolorami, do pliku bez kodów ANSI
"$@" 2>&1 | tee /dev/stderr | perl -pe 's/\e\[[0-9;]*[A-Za-z]//g' >> "$file"
rc=${PIPESTATUS[0]}

{
  echo
  echo "# koniec:    $(date -u +%FT%TZ) (UTC), czas $(( $(date +%s) - start )) s, kod wyjścia $rc"
} >> "$file"
echo "Zapisano log: ${file#"$REPO_ROOT"/}" >&2
exit "$rc"
