float g_flCTSpeed, g_flTSpeed;

void ProcessHidenSeek()
{
	if (g_iWaitTimerT < 10)
		g_iWaitTimerT = 10;
	int ct_health = g_KvConfig.GetNum("ct_health", 100);
	if (ct_health <= 0) ct_health = 1;
	int t_health = g_KvConfig.GetNum("t_health", 100);
	if (t_health <= 0) t_health = 1;
	
	g_flCTSpeed = g_KvConfig.GetFloat("ct_speed", 1.2);
	if (g_flCTSpeed < 0.1) g_flCTSpeed = 0.1;
	
	g_flTSpeed = g_KvConfig.GetFloat("t_speed", 1.0);
	if (g_flTSpeed < 0.1) g_flTSpeed = 0.1;
	
	g_CvarPlayerId.SetInt(1, false, false);
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i, _, false))
		{
			g_iMaxMasks[i] = 0; // Reset max masks
			if (GetClientTeam(i) == CS_TEAM_T)
			{
				TiB_SetThirdPerson(i, true);
				SetEntityHealth(i, t_health);
				RemoveAllWeapons(i);
				PrintToChat(i, "\x01[\x02%s\x01] \x04Пишите !mask чтобы замаскироваться под предмет", g_cGameName);
				SetClientSpeed(i, g_flTSpeed);
				g_PropsMenu.Display(i, 20);
			}
			else if (GetClientTeam(i) == CS_TEAM_CT)
			{
				SetEntityHealth(i, ct_health);
				SetEntityMoveType(i, MOVETYPE_NONE);
				SetClientSpeed(i, 0.0);
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
				ScreenFade(i, g_iWaitTimerT, FFADE_IN|FFADE_PURGE);
			}
		}
	}
	g_hTerTimer = CreateTimer(1.0, Timer_ProcessHideStart, _, TIMER_REPEAT);
}

public Action Timer_ProcessHideStart(Handle timer)
{
	int pl_count = 0;
	if (--g_iWaitTimerT > 0)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsValidClient(i, _, false))
				pl_count++;
		}
		
		if (pl_count < 2)
		{
			ForceFirstPersonToAll();
			PrintCenterTextAll("Игра не может быть начата. Требуется как минимум 2 игрока");
			
			for (int i = 1; i <= MaxClients; ++i)
			{
				if (IsValidClient(i))
				{
					SetClientSpeed(i, 1.0); // return speed to normal
				}
			}
			
			CS_TerminateRound(1.0, CSRoundEnd_Draw);
			
			g_hTerTimer = null;
			return Plugin_Stop;
		}
		
		PrintCenterTextAll("До начала игры %d секунд", g_iWaitTimerT);
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i, _, false) && GetClientTeam(i) == CS_TEAM_CT)
		{
			ScreenFade(i, 10, FFADE_OUT|FFADE_PURGE, -1, 0, 0, 0, 0);
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
			SetEntityMoveType(i, MOVETYPE_WALK);
			SetClientSpeed(i, g_flCTSpeed);
		}
	}
	
	if (g_iWaitTimerCT > 0)
	{
		g_hCtTimer = CreateTimer(1.0, HideGlobalTimer_Callback, _, TIMER_REPEAT);
		PrintToChatAll("\x01[\x02%s\x01] \x04Игра ограничена на %d секунд. Если кт не найдут все предметы, то умрут", g_cGameName, g_iWaitTimerCT);
	}
	
	g_hTerTimer = null;
	return Plugin_Stop;
}

public Action HideGlobalTimer_Callback(Handle timer)
{
	if (--g_iWaitTimerCT > 0)
	{
		PrintHintTextToAll("Игра закончится через %d секунд", g_iWaitTimerCT);
		return Plugin_Continue;
	}
	
	ForceFirstPersonToAll();
	
	int alive;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i, _, false) && GetClientTeam(i) == CS_TEAM_T)
			alive++;
	}
	
	if (alive > 0)
	{
		PrintHintTextToAll("Пропы победили!");
		PrintToChatAll("\x01[\x02%s\x01] \x03КТ Проиграли, они не сумели найти все пропы", g_cGameName);
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i))
			{
				SetClientSpeed(i, 1.0);
				if (IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
					ForcePlayerSuicide(i);
			}
		}
	}
	else
		PrintHintTextToAll("Пропы проиграли!");
	g_CvarPlayerId.SetInt(0, false, false);
	
	g_hCtTimer = null;
	return Plugin_Stop;
}