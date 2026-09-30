# Tłumaczenia (strings/)

Wszystkie teksty, które gracz widzi, leżą w plikach `content/<kod>.w3strings`
(jeden na język) i są czytane w grze przez `GetLocStringByKeyExt()` — tym samym
mechanizmem, którego gra używa dla własnych tekstów. Dzięki temu teksty nie są
wkompilowane w skrypty i każdy może dodać język bez dotykania kodu.

Pliki `.csv` w tym katalogu to **źródła** (edytowalne, tekstowe). Pliki
`.w3strings` w `content/` to **wynik** (binarne, generowane z CSV).

## Jak to działa

- Etykieta wpisu w menu: `mst_save_is` + `" "` + tag, np. `Zapis: Geralt`.
  Dlatego żaden tekst poniżej nie kończy się spacją.
- Lista nazw do przełączania (menu pauzy) składa się z `mst_name_1`..`mst_name_5`
  i jest zapisywana do ustawień przy pierwszym uruchomieniu — potem możesz ją
  dowolnie edytować w pliku ustawień (patrz README główne).
- Gdy brakuje pliku dla języka gracza albo klucza w nim, mod używa tekstu
  angielskiego zapisanego w kodzie i wpisuje o tym linię do logu
  (`no translation for '<klucz>'`). Mod nigdy nie pokazuje pustego tekstu.

## Klucze

| klucz | gdzie widać | PL | EN |
| --- | --- | --- | --- |
| `mst_save_none` | menu pauzy, zapis bez tagu | Zapis bez nazwy | Unnamed save |
| `mst_save_is` | menu pauzy, zapis z tagiem | Zapis: | Save: |
| `mst_hud_no_save` | HUD, brak wczytanego zapisu | Brak wczytanego zapisu - nie ma czego nazwać. | No save is loaded - there is nothing to name. |
| `mst_hud_none` | HUD, tag zdjęty | Zapis bez nazwy. | Save without a name. |
| `mst_name_1`..`mst_name_5` | domyślne nazwy w rotacji | Geralt, Yennefer, Triss, Jaskier, Ciri | Geralt, Yennefer, Triss, Dandelion, Ciri |

## Dodanie języka

1. Skopiuj `strings/en.w3strings.csv` jako `strings/<kod>.w3strings.csv`
   i zmień w pierwszej linii `;meta[language=en]` na swój kod.
2. Przetłumacz **tylko** kolumnę `text` (po trzecim znaku `|`).
   Nie zmieniaj `id`, kluczy ani nagłówka.
3. Zbuduj plik binarny:

   ```shell
   w3strings-ng encode strings/<kod>.w3strings.csv content/<kod>.w3strings
   ```

4. Sprawdź spójność i to, czy plik powstał:

   ```shell
   python3 tools/check-strings.py
   ```

5. Skopiuj `content/<kod>.w3strings` do `mods/modSaveTags/content/` (albo po
   prostu cały folder moda) i uruchom grę w tym języku.

Kody obsługiwane przez encoder: `ar br cz de en es fr hu it jp kr pl ru tr zh`.
Zasada dla każdego języka: `id` i klucze muszą zostać **identyczne** —
`tools/check-strings.py` zgłosi błąd, jeśli klucz ma różne id w różnych językach,
jeśli brakuje go w którymś języku albo jeśli w kodzie pojawi się nieznany klucz.

Do zbudowania plików użyto `encode` z
[w3strings-rust](https://github.com/Odashikonbu/w3strings-rust) (`cli-tools/`) —
dowolny inny encoder przyjmujący ten format CSV też zadziała. Pliki `.w3strings`
w `content/` są zacommitowane, więc do samego grania nie potrzebujesz encodera.

## Adding a language (English)

1. Copy `strings/en.w3strings.csv` to `strings/<code>.w3strings.csv` and change
   `;meta[language=en]` to your language code.
2. Translate only the `text` column (after the third `|`). Keep `id`s and keys.
3. Build with any encoder that accepts this CSV format
   (`id|key(hex)|key|text`, key hex is optional and computed from the key):

   ```shell
   w3strings-ng encode strings/<code>.w3strings.csv content/<code>.w3strings
   ```

4. Run `python3 tools/check-strings.py`, then put the built
   `content/<code>.w3strings` into `mods/modSaveTags/content/`.

## Uwagi techniczne

- Nowy tekst = nowy klucz i nowy `id`. Identy zaczynają się od `2137135001`
  (własny zakres moda) — dopisuj nowe na końcu, nie używaj ich ponownie.
- Tekst może zawierać znaki narodowe (ą, ł, ż, ü, я...) — to normalna
  lokalizacja gry, nie trzeba ich omijać.
- Nie wpisuj znaku `|` w kolumnie `text` (to separator pliku CSV).
