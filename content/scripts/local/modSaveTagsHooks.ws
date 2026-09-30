/***********************************************************************/
/**  modSaveTags - hooks for saving and loading.
/**  Tracks the current save (__current) and, before a save, remembers the
/**  overwritten save's tag so it can be moved. Storage lives in modSaveTags.ws.
/***********************************************************************/


// ===== SAVING =====
// executeSave runs before saving, OnSaveCompleted after. The tag move itself
// happens later in SaveTags_TryMigrate() (the new file is not visible here yet).

// Before saving: remember the overwritten save's tag, type, file name and the
// file list (keys __pending, __pendingtype, __oldsave, __snapshot).
@wrapMethod(CR4IngameMenu)
function executeSave(type : ESaveGameType, slot : int) : void
{
	var saves   : array< SSavegameInfo >;
	var pending : string;
	var oldSave : string;
	var i       : int;

	// Finish the previous move if the engine has already updated the list.
	SaveTags_TryMigrate();

	pending = "";
	oldSave = "";

	if (slot >= 0)
	{
		theGame.GetRecentListSG(saves);

		for (i = 0; i < saves.Size(); i += 1)
		{
			if ((int)saves[i].slotType == (int)type && saves[i].slotIndex == slot)
			{
				oldSave = saves[i].filename;
				pending = SaveTags_GetFile(oldSave);
			}
		}
	}

	SaveTags_CfgSet("__snapshot", SaveTags_ListFiles());
	SaveTags_CfgSet("__pending", pending);
	SaveTags_CfgSet("__pendingtype", IntToString((int)type));
	SaveTags_CfgSet("__oldsave", oldSave);

	LogChannel('modSaveTags', "executeSave type=" + IntToString((int)type)
		+ " slot=" + IntToString(slot)
		+ " pending='" + pending + "'");

	wrappedMethod(type, slot);
}

// After saving: on failure clear the remembered data (nothing to move).
// On success we do nothing here - SaveTags_TryMigrate() moves the tag later.
@wrapMethod(CR4Game)
function OnSaveCompleted(type : ESaveGameType, succeeded : bool)
{
	var ok : string;

	if (succeeded)
	{
		ok = "true";
	}
	else
	{
		ok = "false";
	}

	LogChannel('modSaveTags', "OnSaveCompleted type=" + IntToString((int)type) + " ok=" + ok);

	wrappedMethod(type, succeeded);

	if (!succeeded)
	{
		// the save failed - there is nothing to move
		SaveTags_CfgSet("__snapshot", "");
		SaveTags_CfgSet("__pending", "");
		SaveTags_CfgSet("__pendingtype", "");
		SaveTags_CfgSet("__oldsave", "");
		SaveTags_Flush();
	}
}


// ===== LOADING (which save is current?) =====
// Stored in the settings under "__current" so the pause menu can show its tag.

// Player picked a save from the "Load game" list.
@wrapMethod(CR4IngameMenu)
function LoadSaveRequested(saveSlotRef : SSavegameInfo) : void
{
	SaveTags_CfgSet("__current", saveSlotRef.filename);
	SaveTags_Flush();

	wrappedMethod(saveSlotRef);
}

// "Continue": take the newest save.
@wrapMethod(CR4IngameMenu)
function LoadLastSave(allowModCheck : bool) : void
{
	var saves : array< SSavegameInfo >;

	theGame.GetRecentListSG(saves);

	if (saves.Size() > 0)
	{
		SaveTags_CfgSet("__current", saves[0].filename);
		SaveTags_Flush();
	}

	wrappedMethod(allowModCheck);
}

// New game: no save yet.
@wrapMethod(CR4IngameMenu)
function NewGameRequested() : void
{
	SaveTags_CfgSet("__current", "");
	SaveTags_Flush();

	wrappedMethod();
}
