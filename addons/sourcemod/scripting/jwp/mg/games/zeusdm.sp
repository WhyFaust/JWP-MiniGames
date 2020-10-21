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
			if (IsValidClient(i, _, false))
			{
				RemoveAllWeapons(i);
				pl_count++;
			}
		}
		
		if (pl_count < 2)
		{
			PrintCenterTextAll("%t", "JWP_MG_NO_START");
			CS_TerminateRound(1.0, CSRoundEnd_Draw);
			
			g_hTerTimer = null;
			return Plugin_Stop;
		}
		
		PrintCenterTextAll("%t", "JWP_MG_START_TIME", g_iWaitTimerT);
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i, _, false))
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
		CPrintToChatAll("%t%t", "JWP_MG_PREFIX", "JWP_MG_ZEUSDM_ALERT", g_iWaitTimerCT);
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
			if (IsValidClient(i, _, false))
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
		
		PrintHintTextToAll("%t", "JWP_MG_END_TIME", g_iWaitTimerCT);
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i, _, false))
		{
			ForcePlayerSuicide(i);
		}
	}
	
	g_hCtTimer = null;
	return Plugin_Stop;
}