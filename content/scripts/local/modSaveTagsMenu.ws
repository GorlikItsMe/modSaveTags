/***********************************************************************/
/**  modSaveTags - wpis w menu pauzy.
/**
/**  Wpis pokazuje tag biezacego zapisu ("Zapis: <tag>" / "Zapis bez nazwy"),
/**  widoczny tylko w grze (nie w menu glownym).
/**
/**  Klikniecie przechodzi do nastepnej nazwy z listy SaveTags_Names():
/**  (brak) -> Kamil -> Bartek -> (brak) -> ...
/**  Liste nazw edytujesz w SaveTags_Names() ponizej.
/**
/**  Uwaga: na PC gra nie udostepnia polu tekstowego dla skryptow, dlatego
/**  zamiast wpisywania jest cykl nazw. Dowolny tag ustawisz komenda
/**  tagsSet(...) w konsoli (~).
/***********************************************************************/


// ============================== lista nazw =================================
// Edytuj tutaj: dopisz/usun nazwy. Cykl: (brak) -> [0] -> [1] -> ... -> (brak)

function SaveTags_Names() : array< string >
{
	var names : array< string >;

	names.PushBack("Kamil");
	names.PushBack("Bartek");

	return names;
}


// ======================= dodatkowy wpis w menu gry ==========================

function SaveTags_MenuLabel() : string
{
	var current : string;
	var owner   : string;

	current = SaveTags_CfgGet("__current");
	owner   = "";

	if (StrLen(current) > 0)
	{
		owner = SaveTags_GetFile(current);
	}

	if (StrLen(owner) == 0)
	{
		return "Zapis bez nazwy";
	}

	return "Zapis: " + owner;
}

function SaveTags_AddMenuEntry(creator : IngameMenuStructureCreator, entries : CScriptedFlashArray)
{
	var menuEntry : CScriptedFlashObject;
	var subList   : CScriptedFlashArray;

	// tylko w grze, nie w menu glownym
	if (!creator.parentMenu || creator.parentMenu.isMainMenu)
	{
		return;
	}

	menuEntry = creator.m_flashValueStorage.CreateTempFlashObject();

	menuEntry.SetMemberFlashString("id", "modSaveTags_entry");
	menuEntry.SetMemberFlashString("label", SaveTags_MenuLabel());
	menuEntry.SetMemberFlashString("listTitle", SaveTags_MenuLabel());
	menuEntry.SetMemberFlashUInt("tag", SaveTags_MenuTag());
	menuEntry.SetMemberFlashUInt("type", IGMActionType_Button);

	subList = creator.m_flashValueStorage.CreateTempFlashArray();
	menuEntry.SetMemberFlashArray("subElements", subList);

	entries.PushBackFlashObject(menuEntry);
}

// Dokleja nasz wpis na koniec listy menu (czyli pod "Wyjdz z gry").
@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var entries : CScriptedFlashArray;

	SaveTags_TryMigrate();

	entries = wrappedMethod();

	SaveTags_AddMenuEntry(this, entries);

	return entries;
}


// =========================== cykl nazw (klik) ==============================

function SaveTags_MenuTag() : int
{
	return 777777;
}

function SaveTags_CycleCurrent(menu : CR4IngameMenu)
{
	var current : string;
	var owner   : string;
	var names   : array< string >;
	var idx     : int;
	var i       : int;

	current = SaveTags_CfgGet("__current");

	if (StrLen(current) == 0)
	{
		SaveTags_Say("Brak wczytanego zapisu - nie ma czego nazwac.");
		return;
	}

	names = SaveTags_Names();

	if (names.Size() == 0)
	{
		return;
	}

	owner = SaveTags_GetFile(current);
	idx   = -1;

	for (i = 0; i < names.Size(); i += 1)
	{
		if (names[i] == owner)
		{
			idx = i;
		}
	}

	if (idx < 0)
	{
		owner = names[0];              // nieznany tag -> pierwsza nazwa
	}
	else if (idx + 1 < names.Size())
	{
		owner = names[idx + 1];        // nastepna nazwa
	}
	else
	{
		owner = "";                    // po ostatniej -> brak nazwy
	}

	SaveTags_SetFile(current, owner);

	if (StrLen(owner) == 0)
	{
		SaveTags_Say("Zapis bez nazwy.");
	}
	else
	{
		SaveTags_Say("Zapis: '" + owner + "'");
	}

	SaveTags_RefreshMenu(menu);
}

// Przebudowuje liste menu, zeby etykieta wpisu od razu pokazala nowy tag.
function SaveTags_RefreshMenu(menu : CR4IngameMenu)
{
	var entries : CScriptedFlashArray;

	if (!menu || !menu.m_structureCreator)
	{
		return;
	}

	entries = menu.m_structureCreator.PopulateMenuData();
	menu.m_structureCreator.m_flashValueStorage.SetFlashArray("ingamemenu.entries", entries);
}

// Przechwycenie klikniecia naszego wpisu w menu pauzy.
@wrapMethod(CR4IngameMenu)
function OnItemActivated(actionType : int, menuTag : int)
{
	if (menuTag == SaveTags_MenuTag())
	{
		SaveTags_CycleCurrent(this);
	}
	else
	{
		wrappedMethod(actionType, menuTag);
	}
}
