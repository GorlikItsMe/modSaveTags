/***********************************************************************/
/**  modSaveTags  (Wiedzmin 3 next-gen / 5.0)
/**
/**  PO CO TEN MOD?
/**  Gdy dwie osoby graja na jednym komputerze, zapisy wygladaja
/**  identycznie i trudno rozpoznac, ktory jest czyj. Ten mod pozwala
/**  dopisac do zapisu wlasna etykiete i zobaczyc ja na liscie
/**  "Wczytaj gre", np.:  [Kamil] Bestia z Bialego Sadu - wtorek, ...
/**
/**  JAK TO DZIALA (w skrocie)?
/**  Gra nie pozwala zmienic nazwy zapisu, ale pozwala podmienic
/**  kawalek kodu, ktory buduje wiersze listy zapisow. My doklejamy
/**  tylko etykiete na poczatku. Sama etykieta jest trzymana w pliku
/**  ustawien gry, pod kluczem rownym nazwie pliku zapisu.
/**
/**  PROBLEM: NADPISYWANIE ZAPISU
/**  Kiedy nadpiszesz zapis, gra tworzy NOWY plik (zmienia sie data
/**  i godzina w nazwie) i usuwa stary. Etykieta zostalaby wiec przy
/**  starym pliku. Dlatego mod:
/**    1) PRZED zapisem pamieta etykiete nadpisywanego zapisu,
/**    2) PO zapisie, gdy gra pokaze juz nowy plik, przenosi etykiete.
/**  Robi to funkcja SaveTags_TryMigrate().
/**
/**  PLIKI MODA (content/scripts/local/):
/**    modSaveTags.ws          - ten plik: pamiec etykiet + lista zapisow
/**    modSaveTagsHooks.ws     - podsluchuje moment zapisu i wczytania
/**    modSaveTagsMenu.ws      - dodatkowy wpis w menu pauzy (zmiana etykiety)
/**    modSaveTagsCommands.ws  - komendy do konsoli (~)
/**
/**  KOMENDY W KONSOLI (~):
/**    tagsList()                      wyswietl zapisy: numer, typ, plik, etykieta
/**    tagsSet(3, 'Kamil')             ustaw etykiete zapisowi nr 3
/**    tagsSetFile('53db9', 'Kamil')   ustaw etykiete po fragmencie nazwy pliku
/**    tagsClear(3)                    usun etykiete z zapisu nr 3
/**    tagsClearAll()                  usun wszystkie etykiety
/**    tagsHelp()                      wyswietl pomoc na ekranie
/**
/**  UWAGA: przenoszenie etykiety dziala dla zapisow z menu "Zapisz gre".
/**  Szybki zapis (F5) i autozapis robi gra po swojemu - tam ustaw
/**  etykiete ponownie.
/***********************************************************************/


// =========================================================================
//  CZESC 1: PAMIEC ETYKIET
//  Trzymamy pary "nazwa pliku zapisu -> etykieta" w ustawieniach gry.
//  Do zapisu i odczytu uzywamy "surowych" ustawien (bez deklaracji grupy
//  w XML) - tak samo jak robi to gra dla presetow fotomode.
// =========================================================================

// Nazwa grupy w ustawieniach gry, pod ktora leza wszystkie etykiety.
function SaveTags_Group() : string
{
	return "SaveTags";
}

// Zamienia nazwe pliku na "bezpieczny" klucz.
// Klucz w ustawieniach moze zawierac tylko litery, cyfry i podkreslenie,
// wiec kazdy inny znak zamieniamy na "_". Dzieki temu klucz jest poprawny
// nawet gdy ktos recznie zmieni nazwe pliku (spacje, nawiasy itp.).
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

// Odczyt jednej wartosci z ustawien gry.
function SaveTags_CfgGet(key : string) : string
{
	return theGame.GetInGameConfigWrapper().GetRawConfigValueByStr(SaveTags_Group(), key);
}

// Zapis jednej wartosci do ustawien gry (jeszcze nie na dysk).
function SaveTags_CfgSet(key : string, value : string)
{
	theGame.GetInGameConfigWrapper().SetRawConfigValueByStr(SaveTags_Group(), key, value);
}

// Wymuszenie zapisu ustawien na dysk (trwaly zapis).
function SaveTags_Flush()
{
	theGame.SaveUserSettings();
}

// Odczyt etykiety dla podanego pliku zapisu (pusty napis = brak etykiety).
function SaveTags_GetFile(file : string) : string
{
	return SaveTags_CfgGet(SaveTags_Key(file));
}

// Etykieta trafia do ustawien i na liste, wiec usuwamy znaki, ktore moga
// popsuc format zapisu ("|" to separator, "=" to przypisanie, "\n" to nowa
// linia). Zwykly tekst, np. "Kamil", przechodzi bez zmian.
function SaveTags_CleanOwner(owner : string) : string
{
	return StrReplaceAll(StrReplaceAll(StrReplaceAll(owner, "|", "_"), "=", "_"), "\n", " ");
}

// Zapisuje etykiete dla danego pliku zapisu (od razu na dysk).
function SaveTags_SetFile(file : string, owner : string)
{
	SaveTags_CfgSet(SaveTags_Key(file), SaveTags_CleanOwner(owner));
	SaveTags_Flush();
}

// Skroty pracujace na obiekcie zapisu (SSavegameInfo) zamiast na nazwie pliku.
function SaveTags_Get(save : SSavegameInfo) : string
{
	return SaveTags_GetFile(save.filename);
}

function SaveTags_Set(save : SSavegameInfo, owner : string)
{
	SaveTags_SetFile(save.filename, owner);
}

// Buduje tekst, ktory gracz zobaczy na liscie zapisow.
// Bez etykiety zwraca oryginalna nazwe gry; z etykieta dokleja ja z przodu:
//    "Bestia z Bialego Sadu - wtorek"  ->  "[Kamil] Bestia z Bialego Sadu - ..."
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
//  CZESC 2: PRZENOSZENIE ETYKIETY PRZY NADPISANIU
//  Nadpisanie zapisu = nowy plik. Zeby etykieta nie zostala przy starym,
//  zapamietujemy ja przed zapisem i przypisujemy nowemu plikowi, gdy gra
//  juz go widzi. Stan posredni trzymamy w ustawieniach pod kluczami
//  zaczynajacymi sie od "__".
// =========================================================================

// Buduje liste nazw wszystkich widocznych zapisow w formie tekstu:
//    "|plik1|plik2|plik3|"
// Dzieki otaczajacym "|" latwo sprawdzic, czy dany plik juz na niej jest.
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

// Szuka pierwszego zapisu danego typu, ktorego NIE bylo na liscie "snapshot"
// przed zapisem. To wlasnie ten plik powstal w wyniku nadpisania.
// Zwraca nazwe pliku albo "" gdy nowego pliku jeszcze nie widac.
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

// Domysla (konczy) odlozona migracje etykiety z zapamietanego pliku na nowy.
// Wywolywana przy budowie listy zapisow i przed kolejnym zapisem, czyli
// w momentach, gdy gra zdazyla juz zarejestrowac nowy plik po nadpisaniu.
// Jesli nowego pliku jeszcze nie widac, konczy bez zmian i sprobuje pozniej.
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


// =========================================================================
//  CZESC 3: PODMIANA BUDOWY WIERSZY LISTY ZAPISOW
//  To jest cala oryginalna funkcja z gry (wersja 5.0). Zmienilismy w niej
//  TYLKO JEDNO: pole "label" przechodzi przez SaveTags_Label(), ktore
//  dokleja etykiete. Reszta dziala tak samo jak w oryginale.
//  (Lokalizacja oryginalu: game/gui/main_menu/ingamemenu/igmUtilities.ws)
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

	// Domknij odlozona migracje etykiety, zanim zbudujemy wiersze listy.
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
//  CZESC 4: FUNKCJE POMOCNICZE
// =========================================================================

// Zwraca liste wszystkich widocznych zapisow.
function SaveTags_Saves() : array< SSavegameInfo >
{
	var saves : array< SSavegameInfo >;
	theGame.ListSavedGames(saves, -1);
	return saves;
}

// Wypisuje komunikat jednoczesnie do logu gry i na ekran (HUD).
// Przydatne w komendach konsoli - od razu widzisz efekt.
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
