# Scenariusz 1: ucieczka z kontenera przez privileged pod

| | |
|---|---|
| Wymagania | K.2, K.3 |
| ATT&CK for Containers | T1610 Deploy Container, T1611 Escape to Host |
| Punkt startowy atakującego | konto z prawem `create pods` w namespace `dev` (np. po RCE w aplikacji CI albo z wykradzionego, zbyt szerokiego konta) |
| Status | ☑ wykonanie (skrypt) ☐ faza A ☐ faza B ☐ wpis w macierzy dowodów |

## Wykonanie

```bash
export KUBECONFIG=$PWD/.kube/config
scenarios/01-privileged-escape/run.sh            # deploy + escape
# albo krok po kroku:
scenarios/01-privileged-escape/run.sh deploy
scenarios/01-privileged-escape/run.sh escape
```

- [`pod.yaml`](pod.yaml) — pod z `securityContext.privileged: true` i `hostPID: true` w namespace `dev`.
- [`run.sh`](run.sh) — z wnętrza poda: `nsenter --target 1 --mount --uts --ipc --net --pid -- …`,
  następnie na hoście odczyt `/etc/shadow`, `/etc/machine-id`, tokenu k3s (jeśli to węzeł-serwer)
  i zapis markera persystencji `/krycy-pwned-scenariusz1`.

Namespace i nazwę poda można zmienić zmiennymi `NS` i `POD`.

## Procedura pomiaru (obie fazy)

1. `make phase-a` (lub `phase-b`) i — dla fazy B — `make falco`.
2. `scenarios/01-privileged-escape/run.sh` — wykonaj atak.
3. `make triage NS=dev POD=privesc` — zabezpiecz dowody **przed** usunięciem poda.
4. Zajrzyj do `evidence/…/` oraz do źródeł telemetrii (audit log, logi Falco).
5. `run.sh clean` — dopiero po triage. Marker na węźle usuń ręcznie.

## Obserwacje

### Faza A (domyślny k3s)
TODO (do uzupełnienia po przebiegu na Macu). Oczekiwane: audit log wyłączony (brak zapisu
utworzenia poda), brak telemetrii runtime; po `kubectl delete pod` zostają tylko ślady na węźle
(marker persystencji, journal k3s/kubelet, ewentualnie logi kontenera do czasu usunięcia poda).

### Faza B (forensic readiness)
TODO (do uzupełnienia po przebiegu na Macu). Oczekiwane:
- **audit log API servera**: `create` poda z `securityContext.privileged=true` i `hostPID=true`,
  z `user.username`, `sourceIPs`, czasem — dowód „kto i kiedy postawił uprzywilejowanego poda”.
- **Falco**: reguła `KRYCY Ucieczka z kontenera przez nsenter` (T1611, CRITICAL) na moment `nsenter`;
  dodatkowo reguły **domyślne** Falco (`Launch Privileged Container`, `Read sensitive file …` dla
  `/etc/shadow`) — do odnotowania, które z nich zadziałały.

## Luki widoczności
Działania **po** ucieczce wykonują się już jako procesy hosta w przestrzeniach nazw węzła, więc
Falco widzi je jako aktywność hosta (bez kontekstu poda: `k8s.pod.name` puste). Pamięć procesu
atakującego nie jest nigdzie utrwalana (patrz X.1, checkpoint). Marker persystencji na węźle
przeżywa usunięcie poda — i to jest pointa: usunięcie poda ≠ usunięcie skutków włamania.

## Metoda zebrania
`make triage NS=dev POD=privesc` zbiera (kolejność ulotności): logi i spec poda, `crictl inspect`,
procesy i połączenia kontenera, zapisywalną warstwę FS, journal k3s, eventy, kontekst RBAC/SA
oraz — w fazie B — wycinek audit logu i zdarzeń Falco z węzła. Wynik zbiorczy:
[docs/evidence-matrix.md](../../docs/evidence-matrix.md).
