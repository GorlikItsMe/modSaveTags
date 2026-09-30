/***********************************************************************/
/**  modSaveTags - komendy konsoli (klawisz "~").
/**
/**    tagsList()                      lista zapisow: indeks, typ, plik, tag
/**    tagsSet(3, 'Kamil')             ustaw tag zapisowi o indeksie 3
/**    tagsSetFile('53db9', 'Kamil')   ustaw tag po fragmencie nazwy pliku
/**    tagsClear(3)                    usun tag z zapisu o indeksie 3
/**    tagsClearAll()                  usun wszystkie tagi
/**    tagsHelp()                      wypisz te komendy na ekranie
/**
/**  Funkcje bazowe sa w modSaveTags.ws.
/***********************************************************************/


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
		SaveTags_Say("Otagnieto " + IntToString(found) + " zapis(y) jako '" + owner + "'.");
	}
}

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

exec function tagsHelp()
{
	SaveTags_Say("modSaveTags: tagsList() | tagsSet(indeks, 'Kamil') | tagsSetFile('53db9','Kamil') | tagsClear(indeks) | tagsClearAll()");
}
