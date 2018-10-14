bool g_bCatched[MAXPLAYERS+1];
Handle g_hCatchedTimer[MAXPLAYERS+1];
float g_flCatchDelay;

void ProcessCatchnFree()
{
	if (g_bIsCSGO == false)
	{
		LogError("Game %s not supported", g_cGameName);
		CS_TerminateRound(1.0, CSRoundEnd_Draw);
	}
	g_CvarTeammatesEnemies.SetBool(true, true, false);
	
	
	if (g_iWaitTimerT < 10)
		g_iWaitTimerT = 10;
	
	g_flTSpeed = g_KvConfig.GetFloat("t_speed", 1.4);
	g_flCTSpeed = g_KvConfig.GetFloat("ct_speed", 1.8);
	g_flCatchDelay = g_KvConfig.GetFloat("timer_catched", 6.0);
	if (g_flCatchDelay < 0.5) g_flCatchDelay = 0.5;
	
	if (g_flTSpeed < 1.0) g_flTSpeed = 1.0;
	if (g_flCTSpeed < 1.0) g_flCTSpeed = 1.0;
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		g_bCatched[i] = false;
		
		if (g_hCatchedTimer[i] != null)
			delete g_hCatchedTimer[i];
		
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (GetClientTeam(i) == CS_TEAM_T)
				SetClientSpeed(i, g_flTSpeed);
			else if (GetClientTeam(i) == CS_TEAM_CT)
			{
				SetEntityMoveType(i, MOVETYPE_NONE);
				SetClientSpeed(i, g_flCTSpeed);
			}
			
			RemoveAllWeapons(i);
			GiveWpn(i, "weapon_knife");
		}
	}
	
	g_hTerTimer = CreateTimer(1.0, Timer_ProcessCatchnFreeStart, _, TIMER_REPEAT);
}

public Action Timer_ProcessCatchnFreeStart(Handle timer)
{
	int pl_count = 0;
	if (--g_iWaitTimerT > 0)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
				pl_count++;
		}
		
		if (pl_count < 2)
		{
			PrintCenterTextAll("Игра не может быть начата. Требуется как минимум 2 игрока");
			for (int i = 1; i <= MaxClients; ++i)
			{
				if (IsClientInGame(i))
				{
					SetClientSpeed(i, 1.0);
				}
			}
			CS_TerminateRound(1.0, CSRoundEnd_Draw);
			
			g_hTerTimer = null;
			return Plugin_Stop;
		}
		
		PrintCenterTextAll("До начала игры %d секунд", g_iWaitTimerT);
		return Plugin_Continue;
	}
	
	
	
	if (g_iWaitTimerCT > 0)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
			{
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
				SetEntityMoveType(i, MOVETYPE_WALK);
				SetClientSpeed(i, g_flCTSpeed);
			}
		}
		g_hCtTimer = CreateTimer(1.0, CatchnFreeGlobalTimer_Callback, _, TIMER_REPEAT);
		PrintToChatAll("\x01[\x02%s\x01] \x04Игра ограничена на %d секунд. Надзиратели победят если всех Т заморозят", g_cGameName, g_iWaitTimerCT);
	}
	
	g_hTerTimer = null;
	return Plugin_Stop;
}

public Action CatchnFreeGlobalTimer_Callback(Handle timer, DataPack dp)
{
	int allTCount = 0, freezedTCount = 0;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (GetClientTeam(i) == CS_TEAM_T)
			{
				SetClientSpeed(i, g_flTSpeed);
				if (g_bCatched[i])
					freezedTCount++;
				allTCount++;
			}
			else if (GetClientTeam(i) == CS_TEAM_CT)
				SetClientSpeed(i, g_flCTSpeed);
		}
	}
	
	if (freezedTCount == allTCount)
	{
		PrintHintTextToAll("Зеки проиграли!");
		PrintToChatAll("\x01[\x02%s\x01] \x03Надзиратели победили, успели заморозить всех зеков", g_cGameName);
		g_hCtTimer = null;
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i))
			{
				SetClientSpeed(i, 1.0);
			}
		}
		CS_TerminateRound(3.0, CSRoundEnd_CTWin);
		
		return Plugin_Stop;
	}
	
	if (--g_iWaitTimerCT > 0)
	{
		PrintHintTextToAll("Игра закончится через %d секунд", g_iWaitTimerCT);
		return Plugin_Continue;
	}
	
	PrintHintTextToAll("Зеки победили!");
	PrintToChatAll("\x01[\x02%s\x01] \x03Надзиратели проиграли, не успели всех заморозить", g_cGameName);
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			SetClientSpeed(i, 1.0);
		}
	}
	g_hCtTimer = null;
	CS_TerminateRound(3.0, CSRoundEnd_TerroristWin);
	
	return Plugin_Stop;
}

public Action Timer_CatchnFreeDelay(Handle timer, any client)
{
	if (client && IsClientInGame(client))
		PrintToChat(client, "\x01[\x02JWP|MG\x01] \x03Вас уже можно разморозить");
	
	g_hCatchedTimer[client] = null;
}