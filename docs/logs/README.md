# docs/logs/: nagrane przebiegi labu (dowody do raportu)

Pliki `RRRRMMDD-GGMMSS_<cel>.log` powstają przez `make rec T=<cel>` ([tools/record.sh](../../tools/record.sh)).
Każdy ma nagłówek (polecenie, czas UTC, host, commit), pełne wyjście bez kodów kolorów,
a na końcu kod wyjścia i czas trwania. Do raportu wklejamy wycinki z odnośnikiem do pliku.

Pliki `sample-*.json` to pojedyncze, sformatowane zdarzenia wyciągnięte z audit logu i z Falco
(przykładowe zdarzenia dla K.4).

Zasady:
- nie edytujemy logów ręcznie: jeśli przebieg był błędny, nagrywamy nowy, a stary usuwamy albo opisujemy,
- przed commitem sprawdzamy, czy log nie zawiera sekretów (tokeny, wartości z `env`); `make up` nie wypisuje tokenu węzłów.

## Spis

| Plik | Co pokazuje | Wymaganie |
|---|---|---|
| `20261111-211536_up.log` | klaster od zera: 2 VM-ki, k3s v1.37.2, oba węzły Ready w 195 s | K.1 |
| `20261111-211912_phase-b.log` | przełączenie na fazę B (drop-in + restart k3s) w 11 s | K.4, K.5 |
| `20261111-211923_falco.log` | instalacja Falco 0.45.2, DaemonSet na obu węzłach | K.4 |
| `20261111-212013_test.log` | test end-to-end: węzły, znacznik w audit logu, wykrycie przez regułę Falco | K.1, K.4, K.7 |
| `20261111-212057_triage.log` | triage poda demo (kolejność ulotności, suma paczki) | X.3 |
| `20261111-212126_triage-zawartosc.log` | zawartość paczki triage: sumy OK, podrzucony plik z upperdir, procesy, audit log | X.3 |
| `sample-audit-selfsubjectrulesreview.json` | audit log, poziom Request: rozpoznanie uprawnień (`kubectl auth can-i --list`) | K.4 |
| `sample-audit-pod-create.json` | audit log, poziom RequestResponse: utworzenie poda z pełną specyfikacją | K.4 |
| `sample-falco-sa-token-read.json` | Falco: reguła projektu `KRYCY Odczyt tokenu ServiceAccount…` (T1528) | K.4, K.7 |

Obserwacja z pierwszego przebiegu: w pierwszej minucie fazy B audit log urósł do ok. 930 zdarzeń / 1,2 MB
(start klastra i instalacja Falco). Wolumen w stanie ustalonym trzeba zmierzyć: to wkład do K.5.
