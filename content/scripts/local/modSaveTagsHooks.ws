/***********************************************************************/
/**  modSaveTags - hooking the save and load moments of the game.
/**
/**  This file does NOT store tags - modSaveTags.ws does that.
/**  Its job is to "catch" the moments when the game saves or loads, and
/**  pass that information on:
/**
/**   - before saving: remembers the tag of the save being overwritten
/**     (so it can be moved to the new file), plus the file list,
/**   - after saving: if the save failed, clears the remembered data,
/**   - on load / new game: remembers which save is currently loaded
/**     (__current), so the pause menu can show its tag.
/**
/**  A note on the "@wrapMethod" / "@replaceMethod" prefixes:
/**  these are "hooks" - they replace or wrap a game function. Thanks to
/**  them we do not copy the whole game code, we only add our own part.
/***********************************************************************/


// =========================================================================
//  SAVING THE GAME
//
//  Order of events when saving:
//    1) executeSave()      - BEFORE saving; the game has not changed anything yet
//    2) (the game writes the file)
//    3) OnSaveCompleted()  - AFTER saving; but the game does NOT see the new file yet
//    4) later: when the game refreshes the save list, SaveTags_TryMigrate()
//       from modSaveTags.ws moves the tag to the new file.
// =========================================================================

// Step 1: runs right before the game saves.
// We remember:
//   __pending     - the tag of the save that is about to be overwritten,
//   __pendingtype - the save type (quicksave/autosave/manual),
//   __oldsave     - the file name of the save being overwritten,
//   __snapshot    - the list of save files BEFORE saving.
// This way we later know which file is new, and what to assign to it.
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

// Step 3: runs after saving finishes.
// On success we move NOTHING here (the game does not see the new file yet) -
// SaveTags_TryMigrate() does that later. On failure we clear the remembered
// data, because there is nothing to move.
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

	// On success we do NOT move the tag here: at this moment the engine still
	// does not see the new file on the list. That is done by
	// SaveTags_TryMigrate() once the list is up to date (when the save list is
	// built or on the next save).
}


// =========================================================================
//  LOADING THE GAME - who is the "current" save?
//
//  The pause menu shows the tag of the current save, so we need to know
//  which save the player has actually loaded. We store its file name in
//  the settings under the key "__current".
// =========================================================================

// The player picked a specific save from the "Load game" list.
@wrapMethod(CR4IngameMenu)
function LoadSaveRequested(saveSlotRef : SSavegameInfo) : void
{
	SaveTags_CfgSet("__current", saveSlotRef.filename);
	SaveTags_Flush();

	wrappedMethod(saveSlotRef);
}

// The "Continue" option loads the last save without giving a file name -
// we take the newest one from the list.
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

// A new game does not have any save yet.
@wrapMethod(CR4IngameMenu)
function NewGameRequested() : void
{
	SaveTags_CfgSet("__current", "");
	SaveTags_Flush();

	wrappedMethod();
}
