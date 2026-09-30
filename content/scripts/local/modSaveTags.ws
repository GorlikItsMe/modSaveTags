/***********************************************************************/
/**  modSaveTags  (The Witcher 3 next-gen / 5.0)
/**
/**  WHY THIS MOD?
/**  When two people play on the same PC, saves look identical and it is
/**  hard to tell whose is whose. This mod lets you attach your own tag
/**  to a save and see it on the "Load game" list, e.g.:
/**      [Geralt] Beast of the White Orchard - Tuesday, ...
/**
/**  HOW DOES IT WORK (in short)?
/**  The game does not allow renaming a save, but it does allow replacing
/**  the piece of code that builds the save-list rows. We simply prepend
/**  the tag. The tag itself is stored in the game settings file, under a
/**  key equal to the save's file name.
/**
/**  THE PROBLEM: OVERWRITING A SAVE
/**  When you overwrite a save, the game creates a NEW file (the date and
/**  time in the name change) and removes the old one. The tag would then
/**  stay attached to the old file. So the mod:
/**    1) BEFORE saving: remembers the tag of the save being overwritten,
/**    2) AFTER saving: once the game shows the new file, moves the tag.
/**  This is done by SaveTags_TryMigrate().
/**
/**  MOD FILES (content/scripts/local/):
/**    modSaveTags.ws          - this file: tag storage + save list
/**    modSaveTagsHooks.ws     - hooks the save and load moments
/**    modSaveTagsMenu.ws      - extra pause-menu entry (change the tag)
/**
/**  NOTE: moving the tag works for saves made from the "Save game" menu.
/**  Quicksave (F5) and autosave are handled natively by the game - set
/**  the tag again for those.
/***********************************************************************/


// =========================================================================
//  PART 1: TAG STORAGE
//  We keep "save file name -> tag" pairs in the game settings.
//  We read/write "raw" settings values (without declaring the group in
//  XML) - the same way the game does for photomode presets.
// =========================================================================

// Name of the settings group that holds all tags.
function SaveTags_Group() : string
{
	return "SaveTags";
}

// Turns a file name into a "safe" key.
// A settings key may contain only letters, digits and underscore, so every
// other character becomes "_". Thanks to this the key is always valid, even
// if someone manually changed a file name (spaces, brackets, etc.).
function SaveTags_Key(file : string) : string
{
	var allowed : string;
	var result  : string;
	var i       : int;
	var ch      : string;

	allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";
	result  = "";

	for (i = 0; i < StrLen(file); i += 1)
	{
		ch = StrMid(file, i, 1);

		if (StrFindFirst(allowed, ch) >= 0)
		{
			result = result + ch;
		}
		else
		{
			result = result + "_";
		}
	}

	if (StrLen(result) == 0)
	{
		result = "unknown";
	}

	return result;
}

// Reads a single value from the game settings.
function SaveTags_CfgGet(key : string) : string
{
	return theGame.GetInGameConfigWrapper().GetRawConfigValueByStr(SaveTags_Group(), key);
}

// Writes a single value to the game settings (not to disk yet).
function SaveTags_CfgSet(key : string, value : string)
{
	theGame.GetInGameConfigWrapper().SetRawConfigValueByStr(SaveTags_Group(), key, value);
}

// Forces the settings to be written to disk (persistent save).
function SaveTags_Flush()
{
	theGame.SaveUserSettings();
}

// Reads the tag for the given save file (empty string = no tag).
function SaveTags_GetFile(file : string) : string
{
	return SaveTags_CfgGet(SaveTags_Key(file));
}

// The tag goes into the settings and onto the list, so we remove characters
// that could break the format ("|" is a separator, "=" is an assignment,
// "\n" is a newline). Plain text such as "Geralt" passes through unchanged.
function SaveTags_CleanOwner(owner : string) : string
{
	return StrReplaceAll(StrReplaceAll(StrReplaceAll(owner, "|", "_"), "=", "_"), "\n", " ");
}

// Stores a tag for the given save file (written to disk right away).
function SaveTags_SetFile(file : string, owner : string)
{
	SaveTags_CfgSet(SaveTags_Key(file), SaveTags_CleanOwner(owner));
	SaveTags_Flush();
}

// Shortcut that works on a save object (SSavegameInfo) instead of a file name.
function SaveTags_Get(save : SSavegameInfo) : string
{
	return SaveTags_GetFile(save.filename);
}

// Builds the text the player sees on the save list.
// Without a tag it returns the original game name; with a tag it prepends it:
//    "Beast of the White Orchard - Tuesday"  ->  "[Geralt] Beast of the White Orchard - ..."
function SaveTags_Label(save : SSavegameInfo, engineName : string) : string
{
	var owner : string;

	owner = SaveTags_Get(save);

	if (StrLen(owner) == 0)
	{
		return engineName;
	}

	return "[" + owner + "] " + engineName;
}


// =========================================================================
//  PART 2: MOVING THE TAG WHEN OVERWRITING
//  Overwriting a save = a new file. So that the tag does not stay on the
//  old file, we remember it before saving and assign it to the new file as
//  soon as the game can see it. The intermediate state is kept in the
//  settings under keys starting with "__".
// =========================================================================

// Builds a text list of all visible saves in the form:
//    "|file1|file2|file3|"
// The surrounding "|" make it easy to check whether a given file is on it.
function SaveTags_ListFiles() : string
{
	var saves  : array< SSavegameInfo >;
	var result : string;
	var i      : int;

	result = "|";
	theGame.ListSavedGames(saves, -1);

	for (i = 0; i < saves.Size(); i += 1)
	{
		result = result + saves[i].filename + "|";
	}

	return result;
}

// Looks for the first save of the given type that was NOT on the "snapshot"
// list before saving. That is exactly the file created by overwriting.
// Returns the file name, or "" when the new file is not visible yet.
function SaveTags_FindNewFileOfType(snapshot : string, type : int) : string
{
	var saves : array< SSavegameInfo >;
	var i     : int;

	theGame.ListSavedGames(saves, -1);

	for (i = 0; i < saves.Size(); i += 1)
	{
		if ((int)saves[i].slotType == type && !StrContains(snapshot, "|" + saves[i].filename + "|"))
		{
			return saves[i].filename;
		}
	}

	return "";
}

// Finishes the pending tag move from the remembered file to the new one.
// Called when the save list is built and before the next save - that is, at
// moments when the game has already registered the new file after an
// overwrite. If the new file is not visible yet, it exits unchanged and
// will try again later.
function SaveTags_TryMigrate()
{
	var snapshot : string;
	var pending  : string;
	var type     : int;
	var oldSave  : string;
	var newFile  : string;

	pending = SaveTags_CfgGet("__pending");

	if (StrLen(pending) == 0)
	{
		return;
	}

	snapshot = SaveTags_CfgGet("__snapshot");
	type     = StringToInt(SaveTags_CfgGet("__pendingtype"));
	oldSave  = SaveTags_CfgGet("__oldsave");
	newFile  = SaveTags_FindNewFileOfType(snapshot, type);

	if (StrLen(newFile) == 0)
	{
		// new file is not visible yet - we will try again next time
		return;
	}

	SaveTags_SetFile(newFile, pending);

	// We overwrote the current save (or are creating a new one) - it is now current.
	if (StrLen(oldSave) == 0 || oldSave == SaveTags_CfgGet("__current"))
	{
		SaveTags_CfgSet("__current", newFile);
	}

	SaveTags_CfgSet("__snapshot", "");
	SaveTags_CfgSet("__pending", "");
	SaveTags_CfgSet("__pendingtype", "");
	SaveTags_CfgSet("__oldsave", "");
	SaveTags_Flush();

	LogChannel('modSaveTags', "TryMigrate: '" + pending + "' -> " + newFile);
}


// =========================================================================
//  PART 3: REPLACING THE SAVE-LIST ROW BUILDER
//  This is the whole original game function (version 5.0). We changed
//  ONLY ONE thing in it: the "label" field goes through SaveTags_Label(),
//  which prepends the tag. Everything else works the same as the original.
//  (Original location: game/gui/main_menu/ingamemenu/igmUtilities.ws)
// =========================================================================

@replaceMethod
function IngameMenu_PopulateSaveDataForSlotType(flashStorageUtility : CScriptedFlashValueStorage, saveType:int, parentObject:CScriptedFlashArray, allowEmptySlot:bool) : void
{
	var currentData		: CScriptedFlashObject;
	var numSaveSlots	: int;
	var saveDisplayName : string;
	var currentSave		: SSavegameInfo;
	var i				: int;
	var saveGames		: array< SSavegameInfo >;
	var numSavesAdded	: int;
	var isModdedSave	: bool;

	// Finish the pending tag move before we build the list rows.
	SaveTags_TryMigrate();

	theGame.ListSavedGames( saveGames, saveType );

	if (saveType == -1)
	{
		numSaveSlots = 0;
	}
	else
	{
		numSaveSlots = theGame.GetNumSaveSlots(saveType);
	}

	numSavesAdded = 0;

	for (i = 0; i < saveGames.Size(); i += 1)
	{
		currentSave = saveGames[i];
		saveDisplayName = theGame.GetDisplayNameForSavedGame(currentSave);

		if (saveType == currentSave.slotType || saveType == -1)
		{
			numSavesAdded += 1;
		}
	}

	if (allowEmptySlot && (numSaveSlots == -1 || numSavesAdded < numSaveSlots) )
	{
		currentData = flashStorageUtility.CreateTempFlashObject();

		currentData.SetMemberFlashString("id", "EMPTY");
		currentData.SetMemberFlashString("label", GetPlatformLocString("Empty_Save_Slot"));
		currentData.SetMemberFlashString("filename", "");
		currentData.SetMemberFlashInt("tag", -1);
		currentData.SetMemberFlashUInt("saveType", saveType);

		if (theGame.IsGalaxyUserSignedIn() && theGame.GetInGameConfigWrapper().GetVarValue( 'Gameplay', 'CrossProgression'))
		{
			currentData.SetMemberFlashUInt("cloudStatus", SCO_Uploading);
		}
		else
		{
			currentData.SetMemberFlashUInt("cloudStatus", SCO_Local);
		}

		currentData.SetMemberFlashBool("modded", false);
		currentData.SetMemberFlashBool("trophiesDisabled", false);

		parentObject.PushBackFlashObject(currentData);
	}

	for (i = 0; i < saveGames.Size(); i += 1)
	{
		currentSave = saveGames[i];
		saveDisplayName = theGame.GetDisplayNameForSavedGame(currentSave);

		if (saveType == currentSave.slotType || saveType == -1)
		{
			currentData = flashStorageUtility.CreateTempFlashObject();

			currentData.SetMemberFlashString("id", saveDisplayName);
			currentData.SetMemberFlashString("label", SaveTags_Label(currentSave, saveDisplayName));
			currentData.SetMemberFlashString("filename", currentSave.filename);
			currentData.SetMemberFlashInt("tag", i);
			currentData.SetMemberFlashUInt("saveType", currentSave.slotType);
			currentData.SetMemberFlashUInt("cloudStatus", currentSave.comboStatus );

			isModdedSave = theGame.GetModHandlerSystem().IsModdedSave(currentSave);
			currentData.SetMemberFlashBool("modded", isModdedSave);
			currentData.SetMemberFlashBool("trophiesDisabled", theGame.GetPlatform() != Platform_PC && theGame.GetPlatform() != Platform_PC_GDK && isModdedSave);

			parentObject.PushBackFlashObject(currentData);
		}
	}
}


// =========================================================================
//  PART 4: HELPER FUNCTIONS
// =========================================================================

// Prints a message both to the game log and on screen (HUD).
// Gives the player quick feedback, e.g. after changing a tag in the pause menu.
function SaveTags_Say(text : string)
{
	var witcher : W3PlayerWitcher;
	witcher = GetWitcherPlayer();

	LogChannel('modSaveTags', text);

	if (witcher)
	{
		witcher.DisplayHudMessage(text);
	}
}
