/***********************************************************************/
/**  modSaveTags - console commands ("~" key in game).
/**
/**  Use them when you do not want to click through the pause menu, e.g.
/**  to tag all saves at once.
/**
/**  COMMANDS:
/**    tagsList()                      show saves: number, type, file, tag
/**    tagsSet(3, 'Kamil')             set the tag on save number 3
/**    tagsSetFile('53db9', 'Kamil')   set the tag by a part of the file name
/**    tagsClear(3)                    remove the tag from save number 3
/**    tagsClearAll()                  remove all tags
/**    tagsHelp()                      print these commands on screen
/**
/**  Save numbers ("index") come from tagsList(). The functions that do all
/**  the work live in modSaveTags.ws.
/***********************************************************************/


// Prints the save list: #index [type] file name -> tag.
// Use this first to learn the numbers needed by tagsSet/tagsClear.
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

// Sets the tag on the save with the given number from tagsList().
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

// Sets the tag on every save whose file name contains "part".
// Handy for tagging several saves at once - just a part of the name is enough.
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

// Removes the tag from the save with the given number from tagsList().
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

// Removes tags from all visible saves.
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

// Short on-screen help.
exec function tagsHelp()
{
	SaveTags_Say("modSaveTags: tagsList() | tagsSet(indeks, 'Kamil') | tagsSetFile('53db9','Kamil') | tagsClear(indeks) | tagsClearAll()");
}
