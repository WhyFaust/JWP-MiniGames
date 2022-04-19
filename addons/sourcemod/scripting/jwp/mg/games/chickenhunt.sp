float g_flCTGravity, g_flTGravity;
char gHunter_Model[PLATFORM_MAX_PATH];
char gHunter_ModelArms[PLATFORM_MAX_PATH];

void ProcessChickenHunt()
{
	CreateTimer(3.0, Timer_ProcessChickenHuntDelay);
}

public Action Timer_ProcessChickenHuntDelay(Handle hTimer)
{
	if (g_iWaitTimerT < 10)
		g_iWaitTimerT = 10;
	int ct_health = g_KvConfig.GetNum("ct_health", 100);
	if (ct_health <= 0) ct_health = 1;
	int t_health = g_KvConfig.GetNum("t_health", 1);
	if (t_health <= 0) t_health = 1;
	// Speed sector
	g_flTSpeed = g_KvConfig.GetFloat("t_speed", 1.2);
	if (g_flTSpeed <= 0) g_flTSpeed = 0.1;
	
	g_flCTSpeed = g_KvConfig.GetFloat("ct_speed", 1.0);
	if (g_flCTSpeed <= 0) g_flCTSpeed = 0.1;
	
	// Gravity sector
	g_flTGravity = g_KvConfig.GetFloat("t_gravity", 0.3);
	if (g_flTGravity <= 0) g_flTGravity = 0.1;
	g_flCTGravity = g_KvConfig.GetFloat("ct_gravity", 0.3);
	if (g_flCTGravity <= 0) g_flCTGravity = 0.1;
	
	g_KvConfig.GetString("HunterSkin", gHunter_Model, sizeof(gHunter_Model), "");
	if(FileExists(gHunter_Model))
		PrecacheModel(gHunter_Model);
	if(g_bIsCSGO)
	{
		g_KvConfig.GetString("HunterArms", gHunter_ModelArms, sizeof(gHunter_ModelArms), "");
		if(FileExists(gHunter_ModelArms))
			PrecacheModel(gHunter_ModelArms);
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i, _, false))
		{
			if (GetClientTeam(i) == CS_TEAM_T)
			{
				TiB_SetThirdPerson(i, true);
				SetEntityHealth(i, t_health);
				SetEntityModel(i, "models/chicken/chicken.mdl");
				SetClientSpeed(i, g_flTSpeed);
				SetEntityGravity(i, g_flTGravity);
				RemoveAllWeapons(i);
			}
			else if (GetClientTeam(i) == CS_TEAM_CT)
			{
				SetEntityHealth(i, ct_health);
				if (FileExists(gHunter_Model) && IsModelPrecached(gHunter_Model))
					SetEntityModel(i, gHunter_Model);
				if(g_bIsCSGO)
					if (FileExists(gHunter_ModelArms) && IsModelPrecached(gHunter_ModelArms))
						SetEntPropString(i, Prop_Send, "m_szArmsModel", gHunter_ModelArms);
				SetEntityMoveType(i, MOVETYPE_NONE);
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
				SetClientSpeed(i, g_flCTSpeed);
				SetEntityGravity(i, g_flCTGravity);
				GivePlayerItem(i, "weapon_nova");
			}
		}
	}

	g_hTerTimer = CreateTimer(1.0, Timer_ProcessChickenHuntStart, _, TIMER_REPEAT);

	return Plugin_Stop;
}

public Action Timer_ProcessChickenHuntStart(Handle timer)
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
			PrintCenterTextAll("%t", "JWP_MG_NO_START");
			for (int i = 1; i <= MaxClients; ++i)
			{
				if (IsValidClient(i))
				{
					SetClientSpeed(i, 1.0);
					SetEntityGravity(i, 1.0);
				}
			}
			CS_TerminateRound(1.0, CSRoundEnd_Draw);
			
			g_hTerTimer = null;
			return Plugin_Stop;
		}
		
		PrintCenterTextAll("%t", "JWP_MG_START_TIME", g_iWaitTimerT);
		return Plugin_Continue;
	}
	
	if (g_iWaitTimerCT > 0)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsValidClient(i, _, false) && GetClientTeam(i) == CS_TEAM_CT)
			{
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
				SetEntityMoveType(i, MOVETYPE_WALK);
				SetClientSpeed(i, g_flCTSpeed);
			}
		}
		
		g_hCtTimer = CreateTimer(1.0, ChickenHuntGlobalTimer_Callback, _, TIMER_REPEAT);
		CPrintToChatAll("%t%t", "JWP_MG_PREFIX", "JWP_MG_CHICKENHUNT_ALERT", g_iWaitTimerCT);
	}
	
	g_hTerTimer = null;
	return Plugin_Stop;
}

public Action ChickenHuntGlobalTimer_Callback(Handle timer)
{
	if (--g_iWaitTimerCT > 0)
	{
		PrintHintTextToAll("%t", "JWP_MG_END_TIME", g_iWaitTimerCT);
		
		if (g_iWaitTimerCT % 5 == 0)
		{
			int randpl = GetRandomInt(1, MaxClients);
			if (IsValidClient(randpl) && GetClientTeam(randpl) == CS_TEAM_T && IsPlayerAlive(randpl))
			{
				EmitSoundToAllAny("tib/curlik.mp3");
			}
		}
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsValidClient(i, _, false))
			{
				if (GetClientTeam(i) == CS_TEAM_T)
				{
					SetClientSpeed(i, g_flTSpeed);
					SetEntityGravity(i, g_flTGravity);
				}
				else if (GetClientTeam(i) == CS_TEAM_CT)
				{
					SetClientSpeed(i, g_flCTSpeed);
					SetEntityGravity(i, g_flCTGravity);
				}
			}
		}
		return Plugin_Continue;
	}
	
	ForceFirstPersonToAll();
	
	int alive;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i))
		{
			SetClientSpeed(i, 1.0);
			SetEntityGravity(i, 1.0);
			if (GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
				alive++;
		}
	}
	
	if (alive > 0)
	{
		PrintHintTextToAll("%t", "JWP_MG_CHICKENHUNT_WIN_HINT");
		CPrintToChatAll("%t%t", "JWP_MG_PREFIX", "JWP_MG_CHICKENHUNT_WIN_CHAT");
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsValidClient(i, _, false))
			{
				if (GetClientTeam(i) == CS_TEAM_CT)
					ForcePlayerSuicide(i);
			}
		}
	}
	else
		PrintHintTextToAll("%t", "JWP_MG_CHICKENHUNT_LOST");
	
	g_hCtTimer = null;
	return Plugin_Stop;
}