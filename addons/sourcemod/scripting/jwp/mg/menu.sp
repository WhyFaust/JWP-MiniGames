int g_iMaxMasks[MAXPLAYERS+1];

#define MAX_RULES_SIZE 64
ArrayList g_aRules;

void MenuInitialization()
{
	g_MainMenu = new Menu(g_MainMenu_Callback);
	g_MainMenu.SetTitle("Игровые дни:");
	g_MainMenu.ExitButton = true;
	g_MainMenu.ExitBackButton = true;
	
	g_PropsMenu = new Menu(g_PropsMenu_Callback);
	g_PropsMenu.SetTitle("[JWP|MG] Прятки маскировка:");
	
	g_aRules = new ArrayList(MAX_RULES_SIZE);
}

public int g_MainMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				JWP_ShowMainMenu(param1);
		}
		case MenuAction_Select:
		{
			if (JWP_IsWarden(param1))
			{
				char info[12];
				char temp[MAX_RULES_SIZE], buffer[PLATFORM_MAX_PATH];
				menu.GetItem(param2, info, sizeof(info));
				
				g_KvConfig.Rewind();
				
				if (g_KvConfig.JumpToKey(info, false))
				{
					char cFlags[8];
					g_KvConfig.GetString("flags", cFlags, sizeof(cFlags), "");
					if (cFlags[0] != NULL_STRING[0])
					{
						int bitflag = ReadFlagString(cFlags);
						if (!(GetUserFlagBits(param1) & bitflag || GetUserFlagBits(param1) & ADMFLAG_ROOT))
						{
							PrintToChat(param1, "[MG] У вас недостаточно прав поставить эту игру");
							g_MainMenu.Display(param1, MENU_TIME_FOREVER);
							return;
						}
					}
					
					g_iWaitTimerT = g_KvConfig.GetNum("timer_wait_t", 0);
					g_iWaitTimerCT = g_KvConfig.GetNum("timer_wait_ct", 0);
					g_KvConfig.GetString("rules", g_cGameRules, sizeof(g_cGameRules), "");
					g_KvConfig.GetString("musicAll", g_cMusicAll, sizeof(g_cMusicAll), "");
					g_KvConfig.GetString("game_name", g_cGameName, sizeof(g_cGameName), info);
					
					ReadKVCommands(g_aDisabledPlugins, "disabled_plugins");
					ReadKVCommands(g_aOnGameStart, "cvar_on_game_start");
					ReadKVCommands(g_aOnGameEnd, "cvar_on_game_end");
					
					for (int i = 1; i <= 6; i++)
					{
						Format(buffer, sizeof(buffer), "rule_%d", i);
						g_KvConfig.GetString(buffer, temp, sizeof(temp), "");
						if (temp[0] != NULL_STRING[0])
							g_aRules.PushString(temp);
					}
					
					JWP_ActionMsgAll("%N назначил игру %s в след. раунде", param1, g_cGameName);
					// Make menu inactive
					g_iMapLimitCounter++;
					JWP_RefreshMenuItem(ITEM, _, ITEMDRAW_DISABLED);
				}
				else
				{
					LogError("Specified game name %s not found", info);
					return;
				}
				
				g_iGameId = getGameId(info);
				if (g_iGameId == -1)
				{
					LogError("Specified game with id %d does not exist", g_iGameId);
					return;
				}
			}
		}
	}
}

public int g_PropsMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (g_iGameMode == 1)
		{
			if (IsValidClient(param1))
			{
				if (JWP_IsFlood(param1, 2)) return;
				char path[PLATFORM_MAX_PATH], name[32];
				menu.GetItem(param2, path, sizeof(path), _, name, sizeof(name));
				
				if (!IsModelPrecached(path))
					PrecacheModel(path);
				SetEntityModel(param1, path);
				g_iMaxMasks[param1]++;
				
				int propLimit = g_KvConfig.GetNum("max_masks", 0);
				if (propLimit < 0) propLimit = 0;
				
				if (!propLimit || g_iMaxMasks[param1] < propLimit)
					g_PropsMenu.DisplayAt(param1, menu.Selection, 20);
				else
					PrintToChat(param1, "\x01[\x03JWP|MG|Прятки\x01] \x02Вы превысили лимит выбора предметов (%d/%d)", g_iMaxMasks[param1], propLimit);
			}
		}
	}
}

/* Working with menu in Jail Warden Pro */

public void JWP_Started()
{
	JWP_AddToMainMenu(ITEM, OnFuncDisplay, OnFuncSelect);
}

public bool OnFuncDisplay(int client, char[] buffer, int maxlength, int style)
{
	FormatEx(buffer, maxlength, "Игры");
	if (g_iGameId != -1) style = ITEMDRAW_DEFAULT;
	else style = ITEMDRAW_DISABLED;
	return true;
}

public bool OnFuncSelect(int client)
{
	if (IsValidClient(client) && JWP_IsWarden(client))
	{
		g_MainMenu.Display(client, MENU_TIME_FOREVER);
		
		if ((g_iMapLimit != 0 && g_iMapLimitCounter >= g_iMapLimit) || (g_iCoolDownCounter > 0))
		{
			if (g_iCoolDownCounter > 0)
				JWP_ActionMsg(client, "Нужно подождать %d раунд(ов) перед игрой", g_iCoolDown - g_iCoolDownCounter);
			else
				JWP_ActionMsg(client, "Вы превысили лимит ограничение игр на карте. Доступно: %d", g_iMapLimit);
			return false;
		}
	}
	return true;
}