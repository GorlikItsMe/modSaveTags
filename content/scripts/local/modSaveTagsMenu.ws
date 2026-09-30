/***********************************************************************/
/**  modSaveTags - extra entry in the pause menu.
/**
/**  WHAT DOES THIS ENTRY DO?
/**  In the pause menu (Esc in game) an item appears at the bottom:
/**       "Zapis: Kamil"   or   "Zapis bez nazwy"
/**  It shows the tag of the currently loaded save.
/**
/**  WHEN CLICKED it advances to the next name from the SaveTags_Names()
/**  list:
/**       (none) -> Kamil -> Bartek -> (none) -> ...
/**  You edit the name list in SaveTags_Names() below.
/**
/**  WHY A CYCLE INSTEAD OF TYPING TEXT?
/**  On PC the game does not expose a text-input field to scripts, so
/**  instead a click cycles through ready-made names. Any other tag can be
/**  set with the tagsSet(...) command in the console (~).
/**
/**  The entry is visible only in game (pause menu), not in the main menu.
/***********************************************************************/


// =========================================================================
//  LIST OF NAMES TO CYCLE THROUGH
//  Edit the names here: add or remove lines names.PushBack("...");
//  Cycle: (none) -> first -> second -> ... -> last -> (none)
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
//  ADDING THE ENTRY TO THE MENU
// =========================================================================

// Returns the menu entry text based on the tag of the current save.
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

// Unique number ("tag") of our menu entry. The game uses it to recognize
// which entry was clicked - see SaveTags_MenuTag() below.
function SaveTags_MenuTag() : int
{
	return 2137007;
}

// Creates the entry object and appends it to the end of the pause-menu list.
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

// Builds the pause-menu list and appends our entry at the end (under "Exit game").
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
//  CLICK HANDLING - cycling the name
// =========================================================================

// Picks the next tag in the cycle and stores it on the current save.
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

// Rebuilds the menu list so the entry label immediately shows the new tag.
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

// Intercepts clicks in the pause menu.
// If OUR entry was clicked (by the number from SaveTags_MenuTag()), we cycle
// the name; in every other case we pass the click to the original game.
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
