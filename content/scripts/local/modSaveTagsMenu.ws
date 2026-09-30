/***********************************************************************/
/**  modSaveTags - pause-menu entry.
/**  Shows the current save's tag: "Zapis: Geralt" / "Zapis bez nazwy".
/**  Clicking cycles the rotation names, e.g.:
/**      (none) -> Geralt -> Yennefer -> Triss -> ... -> (none)
/**  The names live in the config (see README.md). Visible in game only.
/***********************************************************************/


// ===== ROTATION NAMES (from the game settings) =====

// Defaults used until you edit the config.
function SaveTags_DefaultNames() : string
{
	return "Geralt|Yennefer|Triss|Jaskier|Ciri|";
}

// Splits the stored "A|B|C|" text into a clean list (skips empty entries).
function SaveTags_ParseNames(raw : string) : array< string >
{
	var parts : array< string >;
	var names : array< string >;
	var i     : int;

	parts = StrSplit(raw, "|");

	for (i = 0; i < parts.Size(); i += 1)
	{
		if (StrLen(parts[i]) > 0)
		{
			names.PushBack(parts[i]);
		}
	}

	return names;
}

// Returns the rotation names, creating the config entry from the defaults
// above if it does not exist yet.
function SaveTags_Names() : array< string >
{
	var stored : string;

	stored = SaveTags_CfgGet("names");

	if (StrLen(stored) == 0)
	{
		stored = SaveTags_DefaultNames();
		SaveTags_CfgSet("names", stored);
		SaveTags_Flush();
	}

	return SaveTags_ParseNames(stored);
}


// ===== ADDING THE ENTRY =====

// Entry text from the current save's tag.
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

// Unique id of our entry, so we can recognize its click.
function SaveTags_MenuTag() : int
{
	return 2137007;
}

// Adds our entry to the pause-menu list (in game only).
function SaveTags_AddMenuEntry(creator : IngameMenuStructureCreator, entries : CScriptedFlashArray)
{
	var menuEntry : CScriptedFlashObject;
	var subList   : CScriptedFlashArray;

	// in game only, not in the main menu
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

// Builds the list and appends our entry at the end.
@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var entries : CScriptedFlashArray;

	SaveTags_TryMigrate();

	entries = wrappedMethod();

	SaveTags_AddMenuEntry(this, entries);

	return entries;
}


// ===== CLICK HANDLING (cycling the name) =====

// Stores the next rotation name on the current save.
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

	// Find the current tag on the name list (idx = -1 when it is not there).
	for (i = 0; i < names.Size(); i += 1)
	{
		if (names[i] == owner)
		{
			idx = i;
		}
	}

	if (idx < 0)
	{
		owner = names[0];              // unknown tag -> first name
	}
	else if (idx + 1 < names.Size())
	{
		owner = names[idx + 1];        // next name
	}
	else
	{
		owner = "";                    // past the last one -> no name
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

// Rebuilds the menu so the label updates at once.
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

// If our entry was clicked, cycle the name; otherwise pass the click on.
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
