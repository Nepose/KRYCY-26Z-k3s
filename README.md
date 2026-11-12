# KRYCY26Z · Projekt 12: forensic readiness w Kubernetes (k3s)

**Pytanie badawcze:** które dowody incydentu w klastrze Kubernetes giną bez wcześniejszej
konfiguracji i co należy włączyć, aby je zachować.

**Metoda:** te same 4 scenariusze ataku wykonujemy dwa razy:
- **faza A:** k3s w konfiguracji domyślnej (co zostaje „samo z siebie”),
- **faza B:** k3s przygotowany pod forensics (audit log, telemetria runtime, retencja).

Różnica między fazami daje macierz dowodów (K.3), a z niej wynikają rekomendacje (K.5) i procedura IR (K.6).

## Status wymagań

| ID | Wymaganie | Gdzie | Status |
|---|---|---|---|
| K.1 | Odtwarzalny klaster k3s | [infra/](infra/), `make up` | ✅ od zera w ok. 3 min ([log](docs/logs/)) |
| K.2 | 4 scenariusze ataku | [scenarios/](scenarios/) | ☐ szablony |
| K.3 | Dowody / luki / metoda dla każdego scenariusza | [docs/evidence-matrix.md](docs/evidence-matrix.md) | ☐ szablon |
| K.4 | Falco + audit log API servera | [detection/falco/](detection/falco/), [infra/config/phase-b/](infra/config/phase-b/) | ✅ działa, `make test` OK, [przykładowe zdarzenia](docs/logs/) |
| K.5 | Rekomendowana konfiguracja | [docs/forensic-readiness.md](docs/forensic-readiness.md) | ☐ szkic |
| K.6 | Procedura IR | [docs/ir-procedure.md](docs/ir-procedure.md) | ☐ szkielet |
| K.7 | Reguły Falco ↔ ATT&CK *(nice)* | [detection/falco/rules/](detection/falco/rules/), [docs/attack-mapping.md](docs/attack-mapping.md) | ☐ 1 reguła |
| K.8 | Falco vs Tetragon *(nice)* | [detection/tetragon/](detection/tetragon/), [docs/falco-vs-tetragon.md](docs/falco-vs-tetragon.md) | ☐ |
| X.3 | Rozszerzenie: skrypt triage IR | [triage/](triage/), `make triage` | ✅ wersja bazowa, przetestowana ([log](docs/logs/)) |
| AI | Sekcja AI w raporcie | [docs/ai-log.md](docs/ai-log.md) | ◐ 2 przypadki wpisane, uzupełniać na bieżąco |

## Architektura labu

```
 Mac (stacja analityka: kubectl, helm, triage)
  │  lima1: vzNAT 192.168.64.0/24, tylko host → API (kubectl)
  ├── k3s-server   VM Lima, Ubuntu 24.04: control plane + kubelet, audit log (faza B)
  │      ║ eth0: Lima user-v2 192.168.104.0/24, ruch między węzłami (k3s, flannel) i internet
  └── k3s-agent-1  VM Lima, Ubuntu 24.04: kubelet, tu lądują pody scenariuszy
        Falco (DaemonSet, modern eBPF) na obu węzłach
```

Dlaczego tak ułożona sieć: [docs/decisions.md, D-002](docs/decisions.md).

VM-ki działają w trybie `plain`: **nie montują katalogu domowego Maca** i nie przekierowują portów.
To ważne, bo scenariusz 1 kończy się rootem na węźle. Dlaczego nie VPS: [docs/decisions.md](docs/decisions.md).

## Wymagania

Lab działa na dwóch podłożach; wybór ustawia zmienna `TRANSPORT` (domyślnie `lima`):

**macOS (`TRANSPORT=lima`)**
- macOS 13+ (Apple Silicon lub Intel), około 10 GB wolnego RAM, 60 GB miejsca na dysku
- `brew install lima kubectl helm` (Lima ≥ 2.0)
- opcjonalnie `brew install shellcheck` (dla `make lint`)

**Linux (`TRANSPORT=libvirt`)** — patrz [Na Linuksie (libvirt/KVM)](#na-linuksie-libvirtkvm)
- libvirt + KVM, około 10 GB wolnego RAM, 60 GB miejsca na dysku
- `sudo apt install libvirt-daemon-system qemu-kvm virtinst qemu-utils kubectl helm`
- użytkownik w grupie `libvirt`

Wersje k3s i chartów są przypięte w [infra/versions.env](infra/versions.env).
Przetestowane 2026-11-11: macOS 26.6 (Apple Silicon), Lima 2.2.1, k3s v1.37.2+k3s1 (containerd 2.3.7),
Ubuntu 24.04 (jądro 6.8), Falco 0.45.2 (chart 9.2.2), kubectl 1.37.2, Helm 4.3.1.

## Szybki start

```bash
make up          # VM-ki + k3s, faza A (ok. 3 min, pierwszy raz dłużej: pobieranie obrazu Ubuntu)
export KUBECONFIG=$PWD/.kube/config
make status
# make kubeconfig  # gdy klaster już działa, a .kube/config nie ma (np. po sklonowaniu repo)

make phase-b     # faza B: audit log, eventy 24 h, retencja logów
make falco       # telemetria runtime
make test        # test end-to-end: węzły, audit log, wykrycie przez Falco

make triage NS=default POD=<pod>   # zabezpieczenie dowodów -> evidence/
make phase-a     # powrót do domyślnej konfiguracji
make down        # usunięcie VM-ek (dowody na węzłach przepadną)
```

`make help` pokazuje wszystkie polecenia.

### Logi do dokumentacji

Każdy cel można nagrać jako dowód realizacji do raportu:

```bash
make rec T=test                              # -> docs/logs/<data>-<czas>_test.log
make rec T=triage NS=default POD=<pod>
```

Log ma nagłówek (polecenie, czas UTC, host, commit), pełne wyjście bez kolorów, kod wyjścia i czas trwania.
Nagrane przebiegi: [docs/logs/](docs/logs/).

## Fazy eksperymentu

| | Faza A (domyślny k3s) | Faza B (forensic readiness) |
|---|---|---|
| Audit log API servera | wyłączony | JSON, [polityka](infra/config/phase-b/audit-policy.yaml), rotacja 30 dni |
| Czas życia eventów | 1 h | 24 h |
| Logi kontenerów na węźle | 5 × 10 MiB | 10 × 50 MiB |
| Telemetria runtime | brak | Falco (`make falco`) |

Przełączanie (`make phase-a`/`phase-b`) dodaje albo usuwa drop-in
`/etc/rancher/k3s/config.yaml.d/50-forensic-readiness.yaml` i restartuje k3s. Działające pody zostają.
Falco instaluje się osobno, więc w fazie A trzeba go odinstalować (`make falco-remove`).

## Na Linuksie (libvirt/KVM)

Odpowiednik Limy na Linuksie: `TRANSPORT=libvirt` stawia dwie VM-ki KVM (Ubuntu 24.04)
przez `virt-install` + cloud-init, w sieci NAT libvirta. Węzły są dostępne po SSH jako
użytkownik `krycy` dedykowanym kluczem (generowany do `.lab/`, poza gitem).

```bash
sudo apt install libvirt-daemon-system qemu-kvm virtinst qemu-utils kubectl helm
sudo usermod -aG libvirt "$USER"    # potem wyloguj/zaloguj
TRANSPORT=libvirt make up
export KUBECONFIG=$PWD/.kube/config
TRANSPORT=libvirt make status
```

Dalej wszystko jest takie samo (`make phase-b`, `make falco`, `make test`, `make triage`) —
pamiętaj tylko o `TRANSPORT=libvirt` (albo `export TRANSPORT=libvirt` na czas sesji).

Różnice wobec Limy, wszystkie **po stronie hosta** (skrypty węzła są wspólne):

| | macOS / Lima | Linux / libvirt |
|---|---|---|
| Hypervisor | Apple Virtualization.framework (`vmType: vz`) | KVM/QEMU |
| Stawianie VM | `limactl start` + [node.yaml](infra/lima/node.yaml) | `virt-install` + [cloud-init](infra/libvirt/user-data.yaml.tpl) |
| Sieć | eth0 (user-v2) + lima1 (vzNAT, tylko host→API) | jedna sieć NAT libvirta (host sięga VM bezpośrednio) |
| Dostęp do węzła | `limactl shell` | SSH kluczem labu (`krycy@<ip z dzierżawy DHCP>`) |
| `NODE_IFACE`/`API_IFACE` | `eth0`/`lima1` | puste (adres z trasy domyślnej) |

Parametry (nazwa sieci, puli, obraz) są na górze [infra/libvirt/provision.sh](infra/libvirt/provision.sh)
i w [infra/versions.env](infra/versions.env). Decyzja projektowa: [docs/decisions.md, D-003](docs/decisions.md).

> **Status:** ścieżka libvirt napisana i sprawdzona składniowo; przebieg `make up`/`make test`
> na realnym hoście Linux jeszcze do wykonania (patrz D-003).

### Na Windows przez WSL2

WSL2 jest **hostem** tej samej ścieżki libvirt — nie osobnym transportem. Węzły k3s to pełne
VM-ki KVM z własnym jądrem Ubuntu 24.04 (BTF), więc **Falco działa**, mimo że współdzielone jądro
WSL2 zwykle nie ma BTF. Wymaga to zagnieżdżonej wirtualizacji (Windows 11) i systemd w WSL2.

```bash
# w dystrybucji Ubuntu w WSL2, repo sklonowane w ~/ (NIE na /mnt/c):
infra/libvirt/wsl2-setup.sh        # pakiety + systemd + grupy + /dev/kvm
# w PowerShell (Windows):          wsl --shutdown        # restart dystrybucji
# po ponownym wejściu:
TRANSPORT=libvirt make up
export KUBECONFIG=$PWD/.kube/config
TRANSPORT=libvirt make test
```

Wymagania specyficzne dla WSL2 (sprawdzane automatycznie przez `make up`):

| Warunek | Jak spełnić |
|---|---|
| `/dev/kvm` (nested virt) | Windows 11 + wirtualizacja w BIOS/UEFI; w `%UserProfile%\.wslconfig`: `[wsl2]` + `nestedVirtualization=true` |
| systemd jako PID 1 | `infra/libvirt/wsl2-setup.sh` wpisuje `systemd=true` do `/etc/wsl.conf`, potem `wsl --shutdown` |
| grupy `libvirt`, `kvm` | dodaje `wsl2-setup.sh` |
| repo w FS WSL2 (`~/…`, nie `/mnt/c`) | klon wewnątrz Linuksa: bity wykonywalne, LF i wydajność I/O |

Rozwiązywanie problemów: `systemctl is-system-running`, `ls -l /dev/kvm`, `virsh -c qemu:///system version`.
Decyzja projektowa: [docs/decisions.md, D-003](docs/decisions.md).

> **Status:** jak przy libvirt — kod i preflight gotowe, pełny przebieg w WSL2 do wykonania.

## Inny host zamiast Limy

Skrypty węzła ([infra/node/](infra/node/)) nie zależą od Limy. Na hostach z Ubuntu po SSH
(użytkownik z `sudo` bez hasła; **pełna VM, np. KVM; nie LXC ani OpenVZ**, bo tam nie działa eBPF):

```bash
TRANSPORT=ssh SERVER=lab-server AGENTS="lab-agent" NODE_IFACE=eth0 make up
```

`API_IFACE` (domyślnie równy `NODE_IFACE`) wskazuje interfejs serwera, pod którego adresem `kubectl` łączy się z API.

Nazwy węzłów w k3s są równe nazwom VM-ek lub aliasom SSH, bo z nich korzysta `triage.sh`.

## Struktura repozytorium

```
infra/          K.1: stawianie klastra (lib.sh, up/down/phase.sh), skrypty węzła, konfiguracja fazy B
                lima/ (VM-ki na macOS), libvirt/ (VM-ki KVM na Linuksie)
detection/      K.4/K.7/K.8: Falco (values, reguły projektu), Tetragon
scenarios/      K.2: po jednym katalogu na scenariusz (opis, manifesty, run.sh)
triage/         X.3: triage.sh (stacja analityka) + node-collect.sh (węzeł)
tests/          smoke.sh: test end-to-end labu
tools/          record.sh: nagrywanie przebiegów do docs/logs/
docs/           raport: macierz dowodów, rekomendacje, procedura IR, mapowanie ATT&CK, decyzje, dziennik AI
docs/logs/      nagrane przebiegi (make rec) i przykładowe zdarzenia: dowody do raportu
evidence/       wyniki triage (poza gitem)
```

## Zasady pracy

- Każdy scenariusz: `run.sh` + opis w README katalogu + wpis w macierzy dowodów, w obu fazach.
- Dowody (`evidence/`) nie trafiają do gita; do raportu idą wycinki z zamaskowanymi sekretami.
- Każde użycie AI i każdą błędną propozycję AI zapisujemy od razu w [docs/ai-log.md](docs/ai-log.md).
- Przed commitem: `make lint`; po zmianach w `infra/` także `make up && make test`.
