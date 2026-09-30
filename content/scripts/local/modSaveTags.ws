/***********************************************************************/
/**  modSaveTags - adds your own tag to a save, shown on the load list,
/**  e.g. "[Geralt] Beast of the White Orchard - Tuesday, ...".
/**
/**  Files: modSaveTags.ws (storage + list), modSaveTagsHooks.ws (save/load),
/**  modSaveTagsMenu.ws (pause-menu entry). See README.md.
/**
/**  Tags live in the game settings (group "SaveTags", key = save file name).
/**  Overwriting a save creates a new file, so SaveTags_TryMigrate() moves
/**  the tag to it. Works for the "Save game" menu; set F5/autosave tags again.
/***********************************************************************/


// ===== TAG STORAGE =====
// "save file name -> tag" pairs kept in the game settings.

// Settings group that holds all tags.
function SaveTags_Group() : string
{
	return "SaveTags";
}

// Turns a file name into a safe settings key (letters, digits and "_" only).
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

// Reads one value from the game settings.
function SaveTags_CfgGet(key : string) : string
{
	return theGame.GetInGameConfigWrapper().GetRawConfigValueByStr(SaveTags_Group(), key);
}

// Writes one value to the game settings (not to disk yet).
function SaveTags_CfgSet(key : string, value : string)
{
	theGame.GetInGameConfigWrapper().SetRawConfigValueByStr(SaveTags_Group(), key, value);
}

// Writes the settings to disk.
function SaveTags_Flush()
{
	theGame.SaveUserSettings();
}

// Reads the tag for a save file (empty = no tag).
function SaveTags_GetFile(file : string) : string
{
	return SaveTags_CfgGet(SaveTags_Key(file));
}

// Removes characters that could break the settings format ("|", "=", newline).
function SaveTags_CleanOwner(owner : string) : string
{
	return StrReplaceAll(StrReplaceAll(StrReplaceAll(owner, "|", "_"), "=", "_"), "\n", " ");
}

// Stores a tag for a save file (writes to disk).
function SaveTags_SetFile(file : string, owner : string)
{
	SaveTags_CfgSet(SaveTags_Key(file), SaveTags_CleanOwner(owner));
	SaveTags_Flush();
}

// Same as above, but for a save object instead of a file name.
function SaveTags_Get(save : SSavegameInfo) : string
{
	return SaveTags_GetFile(save.filename);
}

// Builds the list text: prepends "[tag] " when the save has a tag.
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


// ===== MOVING THE TAG WHEN OVERWRITING =====
// Overwriting makes a new file. We remember the tag before saving and assign
// it to the new file once the game can see it. Temp state uses "__" keys.

// All visible saves as "|file1|file2|" (easy to search later).
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

// First save of this type that was not in the old list = the new file ("" if
// the new file is not visible yet).
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

// Moves the remembered tag to the new file once the game sees it.
// Exits and retries later if the new file is not visible yet.
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


// ===== SAVE-LIST ROWS (vanilla function 5.0, only "label" gets the tag) =====

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


// ===== HELPERS =====

// Prints a message to the game log and on screen (HUD).
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
