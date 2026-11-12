#!/usr/bin/env bash
# Jednorazowa konfiguracja WSL2 pod ścieżkę libvirt/KVM (Ubuntu w WSL2 na Windows 11).
# Idempotentny: można puszczać wielokrotnie. Po zakończeniu wymagany restart dystrybucji.
#
# Co robi:
#   - instaluje libvirt/KVM i narzędzia labu (apt),
#   - włącza systemd w /etc/wsl.conf (libvirtd wymaga systemd jako PID 1),
#   - dodaje użytkownika do grup libvirt i kvm,
#   - sprawdza /dev/kvm (zagnieżdżona wirtualizacja).
# Po nim: w PowerShell  wsl --shutdown  i ponowne wejście do dystrybucji.
set -euo pipefail

say()  { printf '\033[1;34m[wsl2-setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mUWAGA:\033[0m %s\n' "$*"; }

grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || { echo "To nie wygląda na WSL2 — przerwano."; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "Skrypt zakłada dystrybucję na bazie Ubuntu/Debian."; exit 1; }

say "Instaluję libvirt/KVM i narzędzia labu"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  libvirt-daemon-system qemu-kvm virtinst qemu-utils \
  dnsmasq-base bridge-utils ca-certificates wget openssh-client

WSL_CONF=/etc/wsl.conf
if ! { [ -f "$WSL_CONF" ] && grep -qE '^\s*systemd\s*=\s*true' "$WSL_CONF"; }; then
  say "Włączam systemd w $WSL_CONF (wymaga restartu dystrybucji)"
  [ -f "$WSL_CONF" ] && sudo cp "$WSL_CONF" "$WSL_CONF.bak.$(date +%s)"
  if [ -f "$WSL_CONF" ] && grep -qE '^\s*\[boot\]' "$WSL_CONF"; then
    sudo sed -i '/^\s*\[boot\]/a systemd=true' "$WSL_CONF"
  else
    printf '\n[boot]\nsystemd=true\n' | sudo tee -a "$WSL_CONF" >/dev/null
  fi
else
  say "systemd już włączony w $WSL_CONF"
fi

say "Dodaję $USER do grup libvirt i kvm"
sudo usermod -aG libvirt,kvm "$USER"

if [ -e /dev/kvm ]; then
  say "/dev/kvm obecny — zagnieżdżona wirtualizacja działa"
else
  warn "brak /dev/kvm. Włącz nested virtualization: Windows 11, wirtualizacja w BIOS/UEFI,"
  warn "a w %UserProfile%\\.wslconfig dodaj:  [wsl2]  nestedVirtualization=true"
fi

cat <<'EOF'

Gotowe. Teraz, aby zmiany weszły w życie:
  1) w PowerShell (Windows):   wsl --shutdown
  2) wejdź ponownie do dystrybucji WSL2
  3) sprawdź:                  systemctl is-system-running ; ls -l /dev/kvm ; virsh -c qemu:///system version
  4) postaw lab:               TRANSPORT=libvirt make up

Wskazówka: pracuj na repo w systemie plików WSL2 (np. ~/KRYCY-26Z-k3s), nie na /mnt/c
(bity wykonywalne, końce linii LF i wydajność I/O).
EOF
