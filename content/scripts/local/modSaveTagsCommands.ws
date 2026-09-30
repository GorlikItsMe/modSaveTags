/***********************************************************************/
/**  modSaveTags - komendy do konsoli (klawisz "~" w grze).
/**
/**  Mozna ich uzywac, gdy nie chce sie klikac w menu pauzy, np. zeby
/**  ustawic etykiete dla wszystkich zapisow naraz.
/**
/**  KOMENDY:
/**    tagsList()                      pokaz zapisy: numer, typ, plik, etykieta
/**    tagsSet(3, 'Kamil')             ustaw etykiete zapisowi o numerze 3
/**    tagsSetFile('53db9', 'Kamil')   ustaw etykiete po fragmencie nazwy pliku
/**    tagsClear(3)                    usun etykiete z zapisu o numerze 3
/**    tagsClearAll()                  usun wszystkie etykiety
/**    tagsHelp()                      wypisz te komendy na ekranie
/**
/**  Numery zapisow ("indeks") pochodza z tagsList(). Funkcje, ktore
/**  wykonuja cala prace, sa w pliku modSaveTags.ws.
/***********************************************************************/


// Wypisuje liste zapisow: #indeks [typ] nazwa pliku -> etykieta.
// Uzyj tego najpierw, zeby poznac numery potrzebne dla tagsSet/tagsClear.
exec function tagsList()
{
	var saves : array< SSavegameInfo >;
	var i     : int;

	SaveTags_TryMigrate();

	saves = SaveTags_Saves();

	SaveTags_Say("--- zapisy: #indeks [typ] plik -> tag ---");

	for (i = 0; i < saves.Size(); i += 1)
	{
		SaveTags_Say("#" + IntToString(i)
			+ " [" + IntToString((int)saves[i].slotType) + "]"
			+ " " + saves[i].filename
			+ "  tag='" + SaveTags_Get(saves[i]) + "'");
	}
}

// Ustawia etykiete zapisowi o podanym numerze z tagsList().
exec function tagsSet(index : int, owner : string)
{
	var saves : array< SSavegameInfo >;

	saves = SaveTags_Saves();

	if (index < 0 || index >= saves.Size())
	{
		SaveTags_Say("Zly indeks. Uzyj tagsList(), aby zobaczyc numery.");
		return;
	}

	SaveTags_Set(saves[index], owner);
	SaveTags_Say("Zapis #" + IntToString(index) + " = '" + owner + "'. Otworz 'Wczytaj gre', aby zobaczyc.");
}

// Ustawia etykiete wszystkim zapisom, ktorych nazwa pliku zawiera "part".
// Wygodne do otagowania kilku zapisow naraz - wystarczy fragment nazwy.
exec function tagsSetFile(part : string, owner : string)
{
	var saves : array< SSavegameInfo >;
	var i     : int;
	var found : int;

	saves = SaveTags_Saves();
	found = 0;

	for (i = 0; i < saves.Size(); i += 1)
	{
		if (StrContains(StrLower(saves[i].filename), StrLower(part)))
		{
			SaveTags_Set(saves[i], owner);
			found += 1;
		}
	}

	if (found == 0)
	{
		SaveTags_Say("Nie znaleziono zapisu z '" + part + "'. Uzyj tagsList().");
	}
	else
	{
		SaveTags_Say("Otagowano " + IntToString(found) + " zapis(y) jako '" + owner + "'.");
	}
}

// Usuwa etykiete z zapisu o podanym numerze z tagsList().
exec function tagsClear(index : int)
{
	var saves : array< SSavegameInfo >;

	saves = SaveTags_Saves();

	if (index < 0 || index >= saves.Size())
	{
		SaveTags_Say("Zly indeks. Uzyj tagsList(), aby zobaczyc numery.");
		return;
	}

	SaveTags_Set(saves[index], "");
	SaveTags_Say("Tag usuniety z zapisu #" + IntToString(index) + ".");
}

// Usuwa etykiety ze wszystkich widocznych zapisow.
exec function tagsClearAll()
{
	var saves : array< SSavegameInfo >;
	var i     : int;

	saves = SaveTags_Saves();

	for (i = 0; i < saves.Size(); i += 1)
	{
		SaveTags_Set(saves[i], "");
	}

	SaveTags_Say("Usunieto wszystkie tagi (" + IntToString(saves.Size()) + " zapisow).");
}

// Krotka pomoc na ekranie.
exec function tagsHelp()
{
	SaveTags_Say("modSaveTags: tagsList() | tagsSet(indeks, 'Kamil') | tagsSetFile('53db9','Kamil') | tagsClear(indeks) | tagsClearAll()");
}
