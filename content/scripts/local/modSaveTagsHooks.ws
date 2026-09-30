/***********************************************************************/
/**  modSaveTags - hooki zapisu i wczytania.
/**
/**  Pilnuje, ktory zapis jest biezacy (__current) i zapamietuje tag
/**  nadpisywanego zapisu, zeby SaveTags_TryMigrate() mogl go przeniesc
/**  na nowy plik. Funkcje bazowe (magazyn, migracja) sa w modSaveTags.ws.
/***********************************************************************/


// ============================== hooki zapisu ================================
// Przed zapisem (executeSave): zapamietaj tag nadpisywanego zapisu i liste
// plikow. Po zapisie (OnSaveCompleted) nic nie przenosimy - silnik jeszcze nie
// widzi nowego pliku. Przenosi go SaveTags_TryMigrate(), gdy lista jest juz
// aktualna (przy budowie listy zapisow albo przed kolejnym zapisem).

@wrapMethod(CR4IngameMenu)
function executeSave(type : ESaveGameType, slot : int) : void
{
	var saves   : array< SSavegameInfo >;
	var pending : string;
	var oldSave : string;
	var i       : int;

	// Domknij poprzednia migracje, jesli silnik zdazyl juz zaktualizowac liste.
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
		// zapis sie nie udal - nie ma czego przenosic
		SaveTags_CfgSet("__snapshot", "");
		SaveTags_CfgSet("__pending", "");
		SaveTags_CfgSet("__pendingtype", "");
		SaveTags_CfgSet("__oldsave", "");
		SaveTags_Flush();
	}

	// Przy sukcesie NIE przenosimy tagu tutaj: w tej chwili silnik jeszcze nie
	// widzi nowego pliku na liscie. Robi to SaveTags_TryMigrate(), gdy lista
	// jest juz aktualna (przy budowie listy zapisow lub kolejnym zapisie).
}


// ------------------------- kto jest biezacym zapisem -----------------------

// Zapamietaj, ktory zapis jest wczytany - jego tag pokazujemy w menu gry.
@wrapMethod(CR4IngameMenu)
function LoadSaveRequested(saveSlotRef : SSavegameInfo) : void
{
	SaveTags_CfgSet("__current", saveSlotRef.filename);
	SaveTags_Flush();

	wrappedMethod(saveSlotRef);
}

// Opcja "Kontynuuj" laduje ostatni zapis bez podania pliku - bierzemy
// najswiezszy z listy.
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

// Nowa gra nie ma jeszcze zadnego zapisu.
@wrapMethod(CR4IngameMenu)
function NewGameRequested() : void
{
	SaveTags_CfgSet("__current", "");
	SaveTags_Flush();

	wrappedMethod();
}
