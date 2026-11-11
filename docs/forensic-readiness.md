# Rekomendowana konfiguracja forensic readiness (K.5)

Dokument docelowy. Każda rekomendacja powinna mieć: **co włączyć**, **jaki dowód to zachowuje**
(odnośnik do macierzy dowodów), **koszt** (wolumen, wydajność, ryzyko) i **jak to zweryfikować**.

## Co już jest w fazie B labu

| Ustawienie | Gdzie | Zachowuje |
|---|---|---|
| Audit log API servera + polityka | [infra/config/phase-b/](../infra/config/phase-b/) | kto, co, kiedy i skąd zrobił przez API |
| `event-ttl=24h` | [server.yaml](../infra/config/phase-b/server.yaml) | eventy (domyślnie 1 h) |
| Retencja logów kontenerów 10 × 50 MiB | server.yaml / agent.yaml | dłuższa historia logów działających podów |
| Falco (modern eBPF) + reguły projektu | [detection/falco/](../detection/falco/) | procesy, pliki i sieć wewnątrz kontenerów |

## Do zbadania i dopisania (TODO)

- Wysyłka logów poza węzeł (np. Fluent Bit → Loki/S3): logi przeżywają usunięcie poda i węzła.
- Wysyłka zdarzeń Falco poza klaster (falcosidekick).
- Falco `k8saudit`: audit log jako źródło reguł Falco (webhook z API servera).
- Trwały journald na węzłach i synchronizacja czasu (NTP), bo bez niej nie da się skorelować źródeł.
- Checkpointy kontenerów (`ContainerCheckpoint`) jako sposób zabezpieczenia pamięci (X.1).
- Polityka audytu: poziomy vs wolumen (zmierzyć MB/h w labie) i ryzyko zapisania sekretów do logu.
  Pierwszy pomiar: ok. 930 zdarzeń / 1,2 MB w pierwszej minucie fazy B (start + instalacja Falco),
  [docs/logs/README.md](logs/README.md). Trzeba zmierzyć stan ustalony i ustalić, kto generuje najwięcej zdarzeń.
- Ochrona samych dowodów: kto ma dostęp do audit logu, integralność (hashe, WORM).
