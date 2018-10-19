char g_cGamesList[][16] =
{
	"zombiemod",
	"hidenseek",
	"chickenhunt",
	"zeusdm",
	"hotpotato",
	"catchnfree"
};

enum
{
	zombiemod = 0,
	hidenseek,
	chickenhunt,
	zeusdm,
	hotpotato,
	catchnfree
};

Menu g_MainMenu;
Menu g_PropsMenu;

ArrayList g_aOnGameStart;
ArrayList g_aOnGameEnd;
ArrayList g_aDisabledPlugins;
ArrayList g_aMusicList;

void ReadGameModeConfigs()
{
	g_aOnGameStart = new ArrayList(64);
	g_aOnGameEnd = new ArrayList(64);
	g_aDisabledPlugins = new ArrayList(48);
	
	g_aMusicList = new ArrayList(PLATFORM_MAX_PATH);
	g_KvConfig = new KeyValues("MultiGames");
	
	char cGameName[PLATFORM_MAX_PATH];
	char cPath[] = "cfg/jwp/multigames/config.txt";
	if (!g_KvConfig.ImportFromFile(cPath))
		SetFailState("Couldn't parse file %s", cPath);
	
	if (g_KvConfig.GotoFirstSubKey(true))
	{
		g_aMusicList.Clear();
		int gid;
		
		g_iMapLimit = g_KvConfig.GetNum("limit", 0);
		if (g_iMapLimit < 0) g_iMapLimit = 0;
		g_iCoolDown = g_KvConfig.GetNum("cooldown", 3);
		if (g_iCoolDown < 0) g_iCoolDown = 0;

		g_bBlockLR = g_KvConfig.GetNum("blocklr", 1);
		
		do
		{
			if (g_KvConfig.GetSectionName(cGameName, sizeof(cGameName)))
			{
				gid = getGameId(cGameName);
				if (gid != -1)
				{
					g_KvConfig.GetString("game_name", g_cGameName, sizeof(g_cGameName), cGameName);
					g_MainMenu.AddItem(cGameName, g_cGameName);
					
					g_KvConfig.GetString("musicAll", cGameName, sizeof(cGameName), "");
					if (cGameName[0] != NULL_STRING[0])
						g_aMusicList.PushString(cGameName);
				}
			}
		} while (g_KvConfig.GotoNextKey(true));
		g_cGameName[0] = '\0';
		g_KvConfig.Rewind();
	}
	
	LoadPropsFromFile();
}

void PrecacheMusic()
{
	char buffer[PLATFORM_MAX_PATH];
	for (int i = 0; i < g_aMusicList.Length; ++i)
	{
		g_aMusicList.GetString(i, buffer, sizeof(buffer));
		PrecacheSoundAny(buffer);
		Format(buffer, sizeof(buffer), "sound/%s", buffer);
		AddFileToDownloadsTable(buffer);
	}
	
	PrecacheSoundAny("tib/curlik.mp3");
	AddFileToDownloadsTable("sound/tib/curlik.mp3");
}

void LoadPropsFromFile()
{
	KeyValues kv = new KeyValues("Props");
	if (!kv.ImportFromFile("cfg/jwp/multigames/props.txt"))
		SetFailState("Couldn't parse file cfg/jwp/multigames/props.txt");
	
	char path[PLATFORM_MAX_PATH], name[32];
	if (kv.GotoFirstSubKey(true))
	{
		do
		{
			if (kv.GetSectionName(name, sizeof(name)))
			{
				kv.GetString("model", path, sizeof(path), "");
				
				if (path[0] == 'm')
				{
					PrecacheModel(path);
					g_PropsMenu.AddItem(path, name);
				}
			}
		} while (kv.GotoNextKey(true));
	}
	
	delete kv;
	
	g_PropsMenu.ExitButton = true;
}

int getGameId(char[] gameName)
{
	for (int i = 0; i < sizeof(g_cGamesList); ++i)
	{
		if (strcmp(gameName, g_cGamesList[i]) == 0) return i;
	}
	return -1;
}

void ReadKVCommands(ArrayList &array, char[] key)
{
	if (array == null || g_KvConfig == null) return;
	
	array.Clear();
	char cBuffer[768];
	char cEachBuffer[16][48];
	
	g_KvConfig.GetString(key, cBuffer, sizeof(cBuffer), "");
	if (cBuffer[0] != NULL_STRING[0])
	{
		int args = ExplodeString(cBuffer, ";", cEachBuffer, sizeof(cEachBuffer), sizeof(cEachBuffer[]));
		if (args > 0)
		{
			for (int i = 0; i < args; ++i)
			{
				array.PushString(cEachBuffer[i]);
			}
		}
	}
}