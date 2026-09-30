/***********************************************************************/
/**  modSaveTags - localized text (translations).
/**
/**  All player-visible text lives in  content/<language>.w3strings  and is
/**  read here with GetLocStringByKeyExt() - the same mechanism the game
/**  itself uses for its own strings.
/**
/**  Sources are the CSVs in  strings/  (one per language). See strings/README.md
/**  for how to add a language or fix a translation.
/**
/**  When the player's language has no file, or a key is missing, we fall back
/**  to the English text passed by the caller - the mod never shows an empty
/**  message, and the missing key is written to the game log.
/***********************************************************************/

// Reads one translated text from the game's localization.
// key      - key from the strings CSV (e.g. "mst_save_none")
// fallback - English text used when there is no translation
function SaveTags_Loc(key : string, fallback : string) : string
{
	var text : string;

	text = GetLocStringByKeyExt(key);

	if (StrLen(text) == 0)
	{
		LogChannel('modSaveTags', "no translation for '" + key + "' - using English fallback");
		return fallback;
	}

	return text;
}
