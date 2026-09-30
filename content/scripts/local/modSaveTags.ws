/***********************************************************************/
/**  modSaveTags  (The Witcher 3 next-gen / 5.0)
/**  RDZEN: magazyn tagow, przenoszenie przy nadpisaniu, etykieta listy.
/**
/**  Pliki moda (content/scripts/local/):
/**    modSaveTags.ws          - ten plik: magazyn + hook listy zapisow
/**    modSaveTagsHooks.ws     - hooki zapisu/wczytania (kto jest biezacy)
/**    modSaveTagsMenu.ws      - wpis w menu pauzy + wpisywanie tagu
/**    modSaveTagsCommands.ws  - komendy konsoli
/**
/**  Po co: dwie osoby graja na jednym PC i zapisy wygladaja tak samo.
/**  Mod pozwala oznaczyc zapis wlasnym tagiem i widziec go na liscie
/**  "Wczytaj gre":  [Kamil] Bestia z Bialego Sadu - wtorek, ...
/**
/**  Dlaczego tak: natywnej nazwy zapisu nie da sie zmienic
/**    (SSavegameInfo nie ma pola nazwy, GetDisplayNameForSavedGame jest
/**    "import final", SaveGame nie przyjmuje nazwy, brak I/O plikow).
/**  Ale wiersze listy buduje zwykly skrypt, wiec podmieniamy go
/**  (@replaceMethod) i dodajemy prefiks z tagiem.
/**
/**  Tag trzymamy w ustawieniach gry (grupa "SaveTags") przez
/**  GetRawConfigValueByStr / SetRawConfigValueByStr - bez deklaracji
/**  grupy w XML (tak jak presety fotomode). Klucz = nazwa pliku zapisu.
/**
/**  Nadpisanie zapisu tworzy NOWY plik (data/czas w nazwie sie zmieniaja),
/**  dlatego tag jest przenoszony: przed zapisem pamietamy tag nadpisywanego
/**  zapisu, a po zapisie - gdy silnik zarejestruje nowy plik - przypisujemy
/**  mu ten tag (SaveTags_TryMigrate). Kolejnosc listy i slotIndex nie maja
/**  znaczenia, bo liczy sie nazwa pliku.
/**
/**  KOMENDY (konsola "~"):
/**    tagsList()                      lista zapisow: indeks, typ, plik, tag
/**    tagsSet(3, 'Kamil')             ustaw tag zapisowi o indeksie 3
/**    tagsSetFile('53db9', 'Kamil')   ustaw tag po fragmencie nazwy pliku
/**    tagsClear(3)                    usun tag z zapisu o indeksie 3
/**    tagsClearAll()                  usun wszystkie tagi
/**    tagsHelp()                      wypisz te komendy na ekranie
/**
/**  Uwaga: przenoszenie tagu dziala dla zapisow z menu "Zapisz gre".
/**  Szybki zapis (F5) i autozapis robi silnik natywnie - tam tag ustaw
/**  ponownie.
/***********************************************************************/


// ======================== magazyn tagow (nazwa pliku -> wlasciciel) =========

function SaveTags_Group() : string
{
	return "SaveTags";
}

// Klucz w ini ograniczamy do liter/cyfr/podkreslenia. Nazwy plikow zapisow
// silnika i tak sa bezpieczne (manualsave_...), ale to zabezpiecza na wypadek
// zapisu recznie zmienionego (spacje, nawiasy itp.).
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

function SaveTags_CfgGet(key : string) : string
{
	return theGame.GetInGameConfigWrapper().GetRawConfigValueByStr(SaveTags_Group(), key);
}

function SaveTags_CfgSet(key : string, value : string)
{
	theGame.GetInGameConfigWrapper().SetRawConfigValueByStr(SaveTags_Group(), key, value);
}

function SaveTags_Flush()
{
	theGame.SaveUserSettings();
}

function SaveTags_GetFile(file : string) : string
{
	return SaveTags_CfgGet(SaveTags_Key(file));
}

// Nazwa gracza trafia do ini i na liste, wiec usuwamy znaki, ktore moga
// rozjechac format ("|" separator, "=" przypisanie, nowa linia).
function SaveTags_CleanOwner(owner : string) : string
{
	return StrReplaceAll(StrReplaceAll(StrReplaceAll(owner, "|", "_"), "=", "_"), "\n", " ");
}

function SaveTags_SetFile(file : string, owner : string)
{
	SaveTags_CfgSet(SaveTags_Key(file), SaveTags_CleanOwner(owner));
	SaveTags_Flush();
}

function SaveTags_Get(save : SSavegameInfo) : string
{
	return SaveTags_GetFile(save.filename);
}

function SaveTags_Set(save : SSavegameInfo, owner : string)
{
	SaveTags_SetFile(save.filename, owner);
}

// Etykieta, ktora zobaczy gracz na liscie.
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


// ------------------- przenoszenie tagu przy nadpisaniu ----------------------

// "|plik1|plik2|..." - lista nazw wszystkich widocznych zapisow.
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

// Pierwszy zapis danego typu, ktorego nie bylo na liscie przed zapisem
// (czyli nowy plik powstal po nadpisaniu zapisu tego typu).
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

// Przenosi zapamietany tag na nowy plik, gdy ten jest juz widoczny na liscie.
// Wywolywane przy budowie listy zapisow i przed kolejnym zapisem - czyli
// wtedy, gdy silnik zdazyl juz zarejestrowac nowy plik.
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
		// nowy plik jeszcze nie jest widoczny - sprobujemy nastepnym razem
		return;
	}

	SaveTags_SetFile(newFile, pending);

	// Nadpisalismy aktualny zapis (albo tworzymy nowy) - on jest teraz biezacy.
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


// ======================== podmiana budowy wierszy listy =====================
// To jest cala vanilla-owa funkcja z 5.0 (game/gui/main_menu/ingamemenu/
// igmUtilities.ws:13). Zmienione jest tylko jedno: "label" dostaje prefiks
// z tagiem. Reszta (w tym membership "modded"/"trophiesDisabled") bez zmian.

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

	// Domknij odlozona migracje tagu, zanim zbudujemy wiersze listy.
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


// ============================== pomocnicze =================================

function SaveTags_Saves() : array< SSavegameInfo >
{
	var saves : array< SSavegameInfo >;
	theGame.ListSavedGames(saves, -1);
	return saves;
}

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
