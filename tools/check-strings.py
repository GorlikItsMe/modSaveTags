#!/usr/bin/env python3
"""Sprawdza spojnosc tekstow moda (build-time, bez gry).

Sprawdzane reguly:
  1. kazdy klucz uzywany w kodzie (SaveTags_Loc("...")) istnieje w kazdym jezyku,
  2. kazdy klucz ma ten sam id we wszystkich jezykach (id identyfikuje string),
  3. zaden id nie powtarza sie w obrebie jednego pliku,
  4. dla kazdego strings/<jezyk>.w3strings.csv istnieje zbudowany content/<jezyk>.w3strings,
  5. ostrzezenie: klucz przetlumaczony, ale nieuzywany w kodzie.

Stosowanie:
    python3 tools/check-strings.py              # sprawdza repo
    python3 tools/check-strings.py --self-test  # dowodzi, ze walidator lapie bledy
"""
import glob
import os
import re
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
META_RE = re.compile(r"^;meta\[language=([A-Za-z0-9_]+)\]")
KEY_RE = re.compile(r'SaveTags_Loc\(\s*"([^"]+)"')


def read_csv(path):
    """Zwraca (jezyk, [(id, klucz, tekst), ...]) albo (None, []) przy braku meta."""
    rows = []
    lang = None
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    if lines:
        meta = META_RE.match(lines[0].strip())
        if meta:
            lang = meta.group(1)

    for line in lines[1:]:
        line = line.rstrip("\r")
        if not line.strip() or line.startswith(";"):
            continue
        parts = line.split("|", 3)
        if len(parts) < 4:
            continue
        rows.append((parts[0].strip(), parts[2].strip(), parts[3]))

    return lang, rows


def check(root):
    """Zwraca (errors, warnings, langs) dla drzewa moda w 'root'."""
    errors = []
    warnings = []
    langs = {}
    ids_by_key = {}

    for path in sorted(glob.glob(os.path.join(root, "strings", "*.w3strings.csv"))):
        name = os.path.basename(path)
        lang, rows = read_csv(path)

        if not lang:
            errors.append("{}: brak linii ;meta[language=xx] w pierwszej linii".format(name))
            continue

        seen_ids = {}
        langs[lang] = {}
        for sid, key, text in rows:
            if not sid.isdigit():
                errors.append("{}: id '{}' nie jest liczba (klucz '{}')".format(name, sid, key))
            if key in langs[lang]:
                errors.append("{}: klucz '{}' powtorzony".format(name, key))
            if sid in seen_ids:
                errors.append("{}: id {} powtorzone (klucze '{}' i '{}')".format(
                    name, sid, seen_ids[sid], key))
            seen_ids[sid] = key
            langs[lang][key] = text

            if key in ids_by_key and ids_by_key[key][1] != sid:
                errors.append("klucz '{}' ma id {} w '{}', a {} w '{}'".format(
                    key, ids_by_key[key][1], ids_by_key[key][0], sid, name))
            ids_by_key.setdefault(key, (name, sid))

        built = os.path.join(root, "content", "{}.w3strings".format(lang))
        if not os.path.exists(built) or os.path.getsize(built) == 0:
            errors.append("brak zbudowanego pliku content/{}.w3strings (zbuduj z {})".format(
                lang, name))

    used = set()
    for path in sorted(glob.glob(os.path.join(root, "content", "scripts", "local", "*.ws"))):
        with open(path, encoding="utf-8") as fh:
            used.update(KEY_RE.findall(fh.read()))

    for key in sorted(used):
        for lang in sorted(langs):
            if key not in langs[lang]:
                errors.append("klucz '{}' uzywany w kodzie, brak w jezyku '{}'".format(key, lang))

    all_keys = set()
    for keys in langs.values():
        all_keys.update(keys)
    for key in sorted(all_keys - used):
        warnings.append("klucz '{}' przetlumaczony, ale nieuzywany w kodzie".format(key))

    return errors, warnings, langs


def report(root):
    errors, warnings, langs = check(root)
    print("jezyki: {}".format(", ".join("{} ({} kluczy)".format(l, len(k))
                                        for l, k in sorted(langs.items()))))
    for warning in warnings:
        print("UWAGA: {}".format(warning))
    for error in errors:
        print("BLAD:  {}".format(error))
    print("wynik: {}".format("BLADY" if errors else "OK"))
    return 1 if errors else 0


# ---- autotest: walidator musi zlapac kazdy z znanych bledow ----

GOOD_PL = """;meta[language=pl]
2137135001||mst_save_none|Zapis bez nazwy
2137135002||mst_save_is|Zapis:
"""
GOOD_EN = """;meta[language=en]
2137135001||mst_save_none|Unnamed save
2137135002||mst_save_is|Save:
"""
GOOD_WS = """function x()
{
	return SaveTags_Loc("mst_save_none", "Unnamed save")
		+ SaveTags_Loc("mst_save_is", "Save:");
}
"""


def write_tree(root, pl=GOOD_PL, en=GOOD_EN, ws=GOOD_WS, built=("pl", "en")):
    os.makedirs(os.path.join(root, "strings"), exist_ok=True)
    os.makedirs(os.path.join(root, "content", "scripts", "local"), exist_ok=True)
    with open(os.path.join(root, "strings", "pl.w3strings.csv"), "w", encoding="utf-8") as fh:
        fh.write(pl)
    with open(os.path.join(root, "strings", "en.w3strings.csv"), "w", encoding="utf-8") as fh:
        fh.write(en)
    with open(os.path.join(root, "content", "scripts", "local", "modX.ws"), "w", encoding="utf-8") as fh:
        fh.write(ws)
    for lang in built:
        with open(os.path.join(root, "content", "{}.w3strings".format(lang)), "wb") as fh:
            fh.write(b"\x00\x01")


def self_test():
    cases = [
        ("poprawne drzewo", {}, 0),
        ("brak klucza w jednym jezyku",
         {"pl": GOOD_PL.replace("2137135002||mst_save_is|Zapis:\n", "")}, 1),
        ("powtorzony id w pliku",
         {"pl": GOOD_PL + "2137135001||mst_save_is2|Zapis:\n"}, 1),
        ("klucz z innym id w drugim jezyku",
         {"en": GOOD_EN.replace("2137135002", "2137135999")}, 1),
        ("brak zbudowanego pliku",
         {"built": ("en",)}, 1),
        ("nieuzywany klucz = ostrzezenie, nie blad",
         {"pl": GOOD_PL + "2137135003||mst_dead|Martwy\n",
          "en": GOOD_EN + "2137135003||mst_dead|Dead\n"}, 0),
    ]

    failures = 0
    for name, changes, expected in cases:
        root = tempfile.mkdtemp()
        try:
            write_tree(root, **changes)
            errors, warnings, _ = check(root)
            got = 1 if errors else 0
            ok = got == expected
            failures += 0 if ok else 1
            print("  [{}] {}: bledow={} (oczekiwano {}){}".format(
                "OK" if ok else "ZLE", name, len(errors), expected,
                " -> " + "; ".join(errors[:2]) if errors else ""))
        finally:
            shutil.rmtree(root)

    print("autotest: {}".format("OK" if not failures else "{} przypadkow nie dziala".format(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    sys.exit(report(ROOT))
