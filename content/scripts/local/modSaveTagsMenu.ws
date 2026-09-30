/***********************************************************************/
/**  modSaveTags - wpis w menu pauzy.
/**
/**  Wpis pokazuje tag biezacego zapisu ("Zapis: <tag>" / "Zapis bez nazwy"),
/**  widoczny tylko w grze (nie w menu glownym).
/**
/**  KLIKNIECIE (WIP, na razie nie dziala poprawnie): probuje otworzyc
/**  wirtualna klawiature i wpisac nowy tag. Zabezpieczone tak, ze puste
/**  wejscie NIE kasuje tagu. Funkcje bazowe sa w modSaveTags.ws.
/***********************************************************************/


// ======================= dodatkowy wpis w menu gry ==========================

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

function SaveTags_AddMenuEntry(creator : IngameMenuStructureCreator, entries : CScriptedFlashArray)
{
	var menuEntry : CScriptedFlashObject;
	var subList   : CScriptedFlashArray;

	// tylko w grze, nie w menu glownym
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

// Dokleja nasz wpis na koniec listy menu (czyli pod "Wyjdz z gry").
@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var entries : CScriptedFlashArray;

	SaveTags_TryMigrate();

	entries = wrappedMethod();

	SaveTags_AddMenuEntry(this, entries);

	return entries;
}


// ======================= wpisywanie nowego tagu (WIP) =======================

function SaveTags_MenuTag() : int
{
	return 777777;
}

function SaveTags_CurrentOwner() : string
{
	var current : string;

	current = SaveTags_CfgGet("__current");

	if (StrLen(current) == 0)
	{
		return "";
	}

	return SaveTags_GetFile(current);
}

function SaveTags_ApplyInput(owner : string)
{
	var current : string;

	// Puste wejscie (np. anulowanie klawiatury) NIE moze skasowac tagu.
	if (StrLen(owner) == 0)
	{
		return;
	}

	current = SaveTags_CfgGet("__current");

	if (StrLen(current) == 0)
	{
		SaveTags_Say("Brak wczytanego zapisu - nie ma czego nazwac.");
		return;
	}

	SaveTags_SetFile(current, owner);
	SaveTags_Say("Zapis: '" + owner + "'");
}

function SaveTags_OpenTextInput(menu : CR4IngameMenu)
{
	if (!menu.m_saveTagsTextInput)
	{
		menu.m_saveTagsTextInput = new SaveTagsTextInput in menu;
	}

	menu.m_saveTagsTextInput.OpenInput(menu, SaveTags_CurrentOwner());
}

// Pole na instancje maszyny stanow (musi zyc dluzej niz jedno klikniecie).
@addField(CR4IngameMenu)
public var m_saveTagsTextInput : SaveTagsTextInput;

statemachine class SaveTagsTextInput extends CR4MenuBase
{
	public var m_config : SVirtualKeyboardConfig;
	public var m_menu   : CR4MenuBase;

	default autoState = 'Idle';

	public function OpenInput(menu : CR4MenuBase, current : string)
	{
		var config : SVirtualKeyboardConfig;

		config.titleStr   = "Tag zapisu";
		config.defaultStr = current;

		m_config = config;
		m_menu   = menu;

		GotoState('Enter');
	}

	public function Done()
	{
		GotoState('Idle');
	}
}

state Idle in SaveTagsTextInput
{
	event OnEnterState(prevStateName : name)
	{
		super.OnEnterState(prevStateName);
	}
}

state Enter in SaveTagsTextInput
{
	event OnEnterState(prevStateName : name)
	{
		super.OnEnterState(prevStateName);
		RunInput();
	}

	entry function RunInput() : void
	{
		var result : string;

		result = theInput.OpenVirtualKeyboard(parent.m_config);
		SaveTags_ApplyInput(result);
		parent.Done();
	}
}

// Przechwycenie klikniecia naszego wpisu w menu pauzy.
@wrapMethod(CR4IngameMenu)
function OnItemActivated(actionType : int, menuTag : int)
{
	if (menuTag == SaveTags_MenuTag())
	{
		SaveTags_OpenTextInput(this);
	}
	else
	{
		wrappedMethod(actionType, menuTag);
	}
}
