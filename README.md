# modSaveTags

Mod dodaje własną etykietę (tag) do zapisu gry i pokazuje ją na liście
**„Wczytaj grę"**, na przykład:

```
[Geralt] Bestia z Białego Sadu - wtorek, 21:37
```

Przydaje się, gdy kilka osób gra na jednym komputerze i zapisy wyglądają
identycznie.

## Co robi

- W menu pauzy (klawisz `Esc`) na dole pojawia się wpis z tagiem aktualnego
  zapisu: `Zapis: Geralt` albo `Zapis bez nazwy`.
- Kliknięcie tego wpisu przełącza kolejne nazwy z rotacji.
- Przy nadpisywaniu zapisu tag jest automatycznie przenoszony na nowy plik.
- Wpis widać tylko w grze (menu pauzy), nie w menu głównym.

## Instalacja

1. Skopiuj folder `modSaveTags` do folderu `mods` gry:
   `...\The Witcher 3 Wild Hunt GOTY\mods\`
2. Włącz mod w pliku `mods.settings` (`Enabled = 1`) lub przez menedżer modów.

## Jak ustawić tag w grze

1. Wczytaj swój zapis.
2. Otwórz menu pauzy (`Esc`).
3. Klikaj wpis na dole, aby przełączać nazwy:

```
(brak) -> Geralt -> Yennefer -> Triss -> Jaskier -> Ciri -> (brak) -> ...
```

## Jak zmienić domyślne tagi (własne nazwy)

Lista nazw jest trzymana w ustawieniach gry i możesz ją dowolnie edytować.

1. **Zamknij grę.**
2. Otwórz w Notatniku jeden z plików:
   - DX12 (najczęściej ten): `Dokumenty\The Witcher 3\dx12user.settings`
   - DX11: `Dokumenty\The Witcher 3\user.settings`
3. Znajdź sekcję `[SaveTags]` i linię zaczynającą się od `names=`.
   Jeśli linii nie ma, dopisz ją.
4. Wpisz własne nazwy rozdzielone znakiem `|`, na przykład:

```
[SaveTags]
names=Ania|Marek|Gość|
```

5. Zapisz plik i uruchom grę.

### Uwagi

- Przy pierwszym użyciu mod sam utworzy wpis `names` z domyślnymi nazwami w
  języku gry (`Geralt|Yennefer|Triss|Jaskier|Ciri|` po polsku,
  `Geralt|Yennefer|Triss|Dandelion|Ciri|` po angielsku), więc edytujesz gotowy wpis.
- Edytuj ten plik, którego używa Twoja gra — przy DX12 to `dx12user.settings`.
- Rotacja zmienia tylko listę do wybierania. Tagi już przypisane do sejwów
  zostają stare, dopóki nie przełączysz ich w menu.
- Przenoszenie tagu działa dla zapisów z menu „Zapisz grę". Dla szybkiego
  zapisu (`F5`) i autozapisu ustaw tag ponownie.
- Informacja o tagu zapisu nie jest częścią zapisu. Jest zapisywana w pliku `dx12user.settings` lub `user.settings` czyli pliku z ustawieniami gry.

## Języki

Teksty moda (wpis w menu pauzy, komunikaty na HUD i domyślne nazwy w rotacji) nie
są już zaszyte w kodzie — leżą w plikach tłumaczeń i mod pokazuje ten język, który
ma ustawiony gracz. W paczce są **polski** i **angielski**; gdy brakuje pliku dla
języka gracza, mod używa angielskiego i zapisuje o tym linię w logu. Dodanie
języka to przetłumaczenie jednego pliku CSV — patrz
[strings/README.md](strings/README.md).

## Pliki moda

| Plik (`content/scripts/local/`) | Rola |
| --- | --- |
| `modSaveTags.ws` | magazyn tagów i podmiana wierszy listy zapisów |
| `modSaveTagsHooks.ws` | wykrywanie momentu zapisu i wczytania |
| `modSaveTagsMenu.ws` | wpis w menu pauzy + lista nazw z configu |
| `modSaveTagsLoc.ws` | teksty z tłumaczeń (`GetLocStringByKeyExt`) |

Katalog `strings/` to źródła tłumaczeń (pliki CSV), a `content/*.w3strings` to
gotowe teksty dla poszczególnych języków — szczegóły w
[strings/README.md](strings/README.md). `tools/check-strings.py` pilnuje, żeby
klucze w kodzie i w tłumaczeniach się nie rozjechały.

## Uwaga techniczna

Skrypty gry nie mają dostępu do plików, dlatego lista nazw jest trzymana
w ustawieniach gry (sekcja `[SaveTags]`), a nie w osobnym pliku moda.
