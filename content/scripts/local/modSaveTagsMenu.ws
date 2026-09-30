/***********************************************************************/
/**  modSaveTags - dodatkowy wpis w menu pauzy.
/**
/**  CO ROBI TEN WPIS?
/**  W menu pauzy (klawisz Esc w grze) pojawia sie na dole pozycja:
/**       "Zapis: Kamil"   albo   "Zapis bez nazwy"
/**  Pokazuje ona etykiete aktualnie wczytanego zapisu.
/**
/**  PO KLIKNIECIU przechodzi do nastepnej nazwy z listy SaveTags_Names():
/**       (brak) -> Kamil -> Bartek -> (brak) -> ...
/**  Liste nazw edytujesz w funkcji SaveTags_Names() ponizej.
/**
/**  DLACZEGO CYKL, A NIE WPISYWANIE TEKSTU?
/**  Na PC gra nie udostepnia skryptom pola do wpisywania tekstu, dlatego
/**  zamiast tego klikniecie przelacza kolejne gotowe nazwy. Dowolna inna
/**  etykiete ustawisz komenda tagsSet(...) w konsoli (~).
/**
/**  Wpis widoczny jest tylko w grze (w menu pauzy), nie w menu glownym.
/***********************************************************************/


// =========================================================================
//  LISTA NAZW DO PRZELACZANIA
//  Tu edytujesz nazwy: dopisz lub usun linie names.PushBack("...");
//  Cykl: (brak) -> pierwsza -> druga -> ... -> ostatnia -> (brak)
// =========================================================================

function SaveTags_Names() : array< string >
{
	var names : array< string >;

	names.PushBack("Kamil");
	names.PushBack("Szymon");
	names.PushBack("Bartek");

	return names;
}


// =========================================================================
//  DODANIE WPISU DO MENU
// =========================================================================

// Zwraca tekst wpisu w menu na podstawie etykiety biezacego zapisu.
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

// Unikalny numer ("tag") naszego wpisu w menu. Gra rozpoznaje po nim,
// ktory wpis zostal klikniety - patrz SaveTags_MenuTag() nizej.
function SaveTags_MenuTag() : int
{
	return 777777;
}

// Tworzy obiekt wpisu i doklada go na koniec listy menu pauzy.
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

// Buduje liste menu pauzy i na koniec dokleja nasz wpis (pod "Wyjdz z gry").
@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var entries : CScriptedFlashArray;

	SaveTags_TryMigrate();

	entries = wrappedMethod();

	SaveTags_AddMenuEntry(this, entries);

	return entries;
}


// =========================================================================
//  OBSLUGA KLIKNIECIA - przelaczanie nazwy
// =========================================================================

// Ustala nastepna etykiete w cyklu i zapisuje ja biezacemu zapisowi.
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

	// Znajdz aktualna etykiete na liscie nazw (idx = -1 gdy jej tam nie ma).
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

// Przechwytuje klikniecia w menu pauzy.
// Jesli kliknieto NASZ wpis (po numerze z SaveTags_MenuTag()), przelaczamy
// nazwe; w kazdym innym przypadku oddajemy klikniecie oryginalnej grze.
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
