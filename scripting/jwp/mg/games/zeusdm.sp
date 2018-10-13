void ProcessZeusDm()
{
	if (!g_bIsCSGO)
	{
		LogError("Game %s not supported", g_cGameName);
		CS_TerminateRound(1.0, CSRoundEnd_Draw);
	}
	g_CvarTeammatesEnemies.SetBool(true, true, false);
	
	g_hTerTimer = CreateTimer(1.0, Timer_ProcessZeusDM, _, TIMER_REPEAT);
}

public Action Timer_ProcessZeusDM(Handle timer)
{
	int pl_count = 0;
	if (--g_iWaitTimerT > 0)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				RemoveAllWeapons(i);
				pl_count++;
			}
		}
		
		if (pl_count < 2)
		{
			PrintCenterTextAll("Игра не может быть начата. Требуется как минимум 2 игрока");
			CS_TerminateRound(1.0, CSRoundEnd_Draw);
			
			g_hTerTimer = null;
			return Plugin_Stop;
		}
		
		PrintCenterTextAll("До начала игры %d секунд", g_iWaitTimerT);
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SetEntityHealth(i, 100);
			SetClientSpeed(i, 1.0);
			SetEntityGravity(i, 1.0);
			RemoveAllWeapons(i);
			GivePlayerItem(i, "weapon_taser");
		}
	}
	
	if (g_iWaitTimerCT > 0)
	{
		g_hCtTimer = CreateTimer(1.0, ZeusDmGlobalTimer_Callback, _, TIMER_REPEAT);
		PrintToChatAll("\x01[\x02%s\x01] \x04Игра ограничена на %d секунд. Это дезматч на тазерах, каждый сам по себе. Но у всех защита на 10 секунд", g_cGameName, g_iWaitTimerCT);
	}
	
	g_hTerTimer = null;
	return Plugin_Stop;
}

public Action ZeusDmGlobalTimer_Callback(Handle timer)
{
	if (--g_iWaitTimerCT > 0)
	{
		int alive;
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
				alive++;
		}
		
		if (alive <= 1)
		{
			if (g_hCtTimer != null)
				delete g_hCtTimer;
			if (g_hTerTimer != null)
				delete g_hTerTimer;
			CS_TerminateRound(1.0, CSRoundEnd_Draw);
		}
		
		PrintHintTextToAll("Игра закончится через %d секунд", g_iWaitTimerCT);
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			ForcePlayerSuicide(i);
		}
	}
	
	g_hCtTimer = null;
	return Plugin_Stop;
}