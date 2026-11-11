# Tetragon (K.8, nice-to-have)

Do zrobienia: instalacja Tetragona obok Falco i porównanie, co każde z narzędzi widzi w tych samych scenariuszach.

- Chart: `cilium/tetragon` (wersja `TETRAGON_CHART_VERSION` w [infra/versions.env](../../infra/versions.env)).
- Tutaj trafią `values.yaml`, `install.sh` i polityki `TracingPolicy` (np. `execve`, `openat` na `serviceaccount/token`, `setns`/`nsenter` dla scenariusza 1).
- Wyniki porównania: [docs/falco-vs-tetragon.md](../../docs/falco-vs-tetragon.md).
