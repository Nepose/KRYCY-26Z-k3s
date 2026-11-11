# evidence/

Tu `triage/triage.sh` zapisuje zebrane dowody: katalog `<czas>_<namespace>_<pod>/`,
archiwum `.tar.gz` i jego sumę SHA-256.

Zawartość jest w `.gitignore`: dowody zawierają tokeny, sekrety i zmienne środowiskowe.
Do raportu przenosimy tylko wycinki (zrzuty, fragmenty logów z zamaskowanymi sekretami).
