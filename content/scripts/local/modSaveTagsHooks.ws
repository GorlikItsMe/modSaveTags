/***********************************************************************/
/**  modSaveTags - podsluchiwanie zapisu i wczytania gry.
/**
/**  Ten plik NIE przechowuje etykiet - to robi modSaveTags.ws.
/**  Jego zadanie to "podsluchac" momenty, w ktorych gra zapisuje albo
/**  wczytuje gre, i przekazac te informacje dalej:
/**
/**   - przed zapisem: zapamietuje etykiete nadpisywanego zapisu
/**     (zeby moc ja przeniesc na nowy plik), oraz liste plikow,
/**   - po zapisie: jesli zapis sie nie udal, czysci zapamietane dane,
/**   - przy wczytaniu / nowej grze: zapamietuje, ktory zapis jest biezacy
/**     (__current), zeby menu pauzy moglo pokazac jego etykiete.
/**
/**  Uwaga o nazwach funkcji z prefiksem "@wrapMethod" i "@replaceMethod":
/**  to "haczyki" (hooki) - podmieniaja lub opakowuja funkcje gry. Dzieki
/**  nim nie musimy kopiowac calego kodu gry, tylko dodajemy swoje.
/***********************************************************************/


// =========================================================================
//  ZAPIS GRY
//
//  Kolejnosc zdarzen przy zapisie:
//    1) executeSave()      - PRZED zapisem; gra jeszcze nic nie zmienila
//    2) (gra zapisuje plik)
//    3) OnSaveCompleted()  - PO zapisie; ale gra JESZCZE nie widzi nowego pliku
//    4) pozniej: gdy gra odswiezy liste zapisow, SaveTags_TryMigrate()
//       z modSaveTags.ws przenosi etykiete na nowy plik.
// =========================================================================

// Punkt 1: uruchamiane tuz przed zapisem gry.
// Zapamietujemy:
//   __pending     - etykiete zapisu, ktory zaraz zostanie nadpisany,
//   __pendingtype - typ zapisu (szybki/autozapis/reczny),
//   __oldsave     - nazwe pliku nadpisywanego zapisu,
//   __snapshot    - liste plikow zapisow PRZED zapisem.
// Dzieki temu pozniej wiemy, ktory plik jest nowy, i co mu przypisac.
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

// Punkt 3: uruchamiane po zakonczeniu zapisu.
// Przy sukcesie NIC tu nie przenosimy (gra jeszcze nie widzi nowego pliku) -
// zrobi to pozniej SaveTags_TryMigrate(). Przy niepowodzeniu czyscimy
// zapamietane dane, bo nie ma czego przenosic.
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


// =========================================================================
//  WCZYTANIE GRY - kto jest "biezacym" zapisem?
//
//  Menu pauzy pokazuje etykiete biezacego zapisu, wiec musimy wiedziec,
//  ktory zapis gracz aktualnie wczytal. Zapisujemy jego nazwe pliku
//  w ustawieniach pod kluczem "__current".
// =========================================================================

// Gracz wybral konkretny zapis z listy "Wczytaj gre".
@wrapMethod(CR4IngameMenu)
function LoadSaveRequested(saveSlotRef : SSavegameInfo) : void
{
	SaveTags_CfgSet("__current", saveSlotRef.filename);
	SaveTags_Flush();

	wrappedMethod(saveSlotRef);
}

// Opcja "Kontynuuj" wczytuje ostatni zapis bez podania pliku -
// bierzemy najswiezszy z listy.
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
