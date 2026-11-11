# Dziennik użycia AI (obowiązkowa sekcja raportu)

Wymagania z karty projektu:
- do jakich elementów i jakimi narzędziami użyto AI,
- **co najmniej 2 udokumentowane przypadki**, w których AI zaproponowało rozwiązanie błędne,
  nieoptymalne lub niebezpieczne, z opisem, jak to wykryto i poprawiono,
- co zespół zweryfikował samodzielnie i w jaki sposób.


## Użycie AI

| Data | Narzędzie | Element projektu | Zakres (co wygenerowano / o co pytano) |
|---|---|---|---|
| 2026-11-11 | Claude Opus 5.5 | Szkielet repozytorium | Zapytano o stworzenie szkieletu dokumentacji do późniejszego uzupełnienia z wykorzystaniem VPSa Bartka. Model m.in. zbadał blokadę dostępu do wybranych przestrzeni w ramach non-privileged LXC i zaproponował skonfigurowanie Lima na Bartkowym MacBooku. Wygenerowano szkielet repozytorium - skrypty `infra/`, `triage/`, `tests/`, szablony `docs/` i `scenarios/`. |
| 2026-11-11 | Claude Opus 5.5 | Logi po uruchomieniu | Claude został poproszony o zebranie logów z ręcznego uruchomienia klastra z wykorzystaniem skryptów. Agent Claude'a otrzymał limitowany dostęp do mojej VMki. | 

## Przypadki błędnych / nieoptymalnych / niebezpiecznych propozycji

### Przypadek 1: założenie, że sieć vzNAT „po prostu działa” (2026-11-11)
- **Narzędzie:** Claude Opus 5.5
- **Propozycja AI:** VM-ki Lima z jedną siecią `vzNAT` używaną do wszystkiego: internetu,
  ruchu między węzłami k3s i dostępu z Maca.
- **Problem:** na Macu zespołu NAT vmnet przepuszcza tylko ruch host↔VM. Najpierw `curl` pobierający
  instalator k3s wisiał bez limitu czasu. Po pierwszej poprawce (trasa do internetu przez `eth0`)
  okazało się, że agent też nie łączy się z serwerem, bo ruch VM↔VM jest blokowany.
  Poprawka była więc niepełna: AI załatało objaw zamiast od razu sprawdzić całą ścieżkę sieciową.
- **Jak wykryto:** `make up` stało kilka minut. W VM-ce `ps` pokazał wiszący `curl`, a `curl --interface`
  dał różne wyniki dla `eth0` i `lima0`. Potem `journalctl -u k3s-agent` (`failed to get CA certs`)
  i testy `ping`/`curl` VM→VM i host→VM.
- **Poprawka:** sieć Limy `user-v2` jako `eth0` (internet i ruch między węzłami), vzNAT (`lima1`) tylko dla hosta;
  limity czasu i ponawianie w `curl`. Szczegóły: [decisions.md, D-002](decisions.md).
  Przy okazji AI błędnie założyło, że `user-v2` pojawi się jako dodatkowy interfejs `lima0`. W rzeczywistości
  Lima podmienia nim `eth0`, co wyszło przy następnym uruchomieniu (`ip -4 -o addr` w VM-ce).

### Przypadek N: tytuł
- **Data, narzędzie:**
- **Propozycja AI:** (wycinek)
- **Problem:** (dlaczego błędne / nieoptymalne / niebezpieczne)
- **Jak wykryto:** (test, dokumentacja, review, obserwacja w labie)
- **Poprawka:** (link do commita)

## Weryfikacja własna

| Opis elementu | Jak zweryfikowano |
|---|---|
| **Schematyczność LLM-ów**. Zlecając projekt nawet najlepszemu modelowi AI, nalezy pamiętać o tym, iz w istocie ciągle pozostaje on czarnym pudełkiem do zgadywania i podawania na output najbardziej prawdopodobnego następnego tokenu (słowa / sylaby). Teksty i bazy kodu tworzone przez LLMy zawierają charakterystyczne cechy, po których mozna zauwazyc jego autorstwo. | Dla Claude'a typowe jest m.in. nadawanie nietypowych dla człowieka "kodów" kazdej części decyzji projektowej, zapisywanej jako element architektury systemu. Jest to widoczne m.in. w folderze `docs/decisions.md`. Śladem pracy Klaudiusza są równiez części zdań oddzielane punktorem (·), a takze zdania zawierajace porownanie do elementu negatywnego (np. "X, a nie Y"). To samo mozna zauwazyc w definicji projektow na stronie przedmiotu (jako ze tworzenie plików HTML, z tego, co widzimy, było wspomagane AI). |