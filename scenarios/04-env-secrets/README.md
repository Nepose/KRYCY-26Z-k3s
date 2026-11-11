# Scenariusz 4: sekrety w zmiennych środowiskowych

| | |
|---|---|
| Wymagania | K.2, K.3 |
| ATT&CK for Containers | T1552 Unsecured Credentials (T1552.007 Container API) |
| Punkt startowy atakującego | TODO, np. prawo `get pods` w namespace albo dostęp do powłoki w kontenerze |
| Status | ☐ wykonanie ☐ faza A ☐ faza B ☐ wpis w macierzy dowodów |

## Wykonanie

TODO: manifesty i `run.sh`. Warto porównać dwa warianty:
1. sekret wpisany wprost w `env[].value` w specyfikacji poda,
2. sekret przez `env[].valueFrom.secretKeyRef`.

Drogi odczytu: `kubectl get pod -o yaml`, `kubectl exec … env`, `/proc/<pid>/environ` z węzła.

## Obserwacje

### Faza A (domyślny k3s)
TODO

### Faza B (forensic readiness)
TODO. Uwaga: przy wariancie 1 polityka audytu (poziom RequestResponse dla podów) zapisuje
wartość sekretu do audit logu. To ciekawa obserwacja do raportu i rekomendacji (K.5).

## Luki widoczności
TODO: odczyt przez `get pods` jest w audit logu, ale tylko jako „ktoś pobrał spec poda”, bez informacji, że chodziło o sekret.

## Metoda zebrania
TODO, wynik zbiorczy: [docs/evidence-matrix.md](../../docs/evidence-matrix.md)
