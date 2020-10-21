int gZombie_iClientTeam[MAXPLAYERS+1];
int gZombie_Health;
float gZombie_fSpawnCoords[MAXPLAYERS+1][3];
float gZombie_fKnockback;
char gZombie_Model[PLATFORM_MAX_PATH];
char gZombie_ModelArms[PLATFORM_MAX_PATH];
bool gZombie_IsZombie[MAXPLAYERS+1];

#define CSGO_KNOCKBACK_BOOST        251.0
#define CSGO_KNOCKBACK_BOOST_MAX    350.0

void ProcessZombie()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR)
		{
			// Temp godmode before round begin
			if (IsPlayerAlive(i))
				GodMode(i, true);
			
			gZombie_iClientTeam[i] = GetClientTeam(i);
			GetClientAbsOrigin(i, gZombie_fSpawnCoords[i]);
			gZombie_IsZombie[i] = false;
		}
	}
	
	gZombie_Health = g_KvConfig.GetNum("ZombieHP", 1000);
	if (gZombie_Health <= 0)
		gZombie_Health = 5000;
	
	g_KvConfig.GetString("ZombieSkin", gZombie_Model, sizeof(gZombie_Model), "");
	if (FileExists(gZombie_Model))
		PrecacheModel(gZombie_Model);
	if(g_bIsCSGO)
	{
		g_KvConfig.GetString("ZombieArms", gZombie_ModelArms, sizeof(gZombie_ModelArms), "");
		if (FileExists(gZombie_ModelArms))
			PrecacheModel(gZombie_ModelArms);
	}
	
	gZombie_fKnockback = g_KvConfig.GetFloat("zombie_knockback", 1.0);
	
	if (g_iWaitTimerT < 3)
		g_iWaitTimerT = 3;
	g_hTerTimer = CreateTimer(1.0, Timer_ProcessZombieStart, _, TIMER_REPEAT);
}

public Action Timer_ProcessZombieStart(Handle timer)
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
			PrintCenterTextAll("Игра не может быть начата. Требуется как минимум 2 игрока");
			CS_TerminateRound(1.0, CSRoundEnd_Draw);
			
			g_hTerTimer = null;
			return Plugin_Stop;
		}
		
		PrintCenterTextAll("До заражения %d секунд", g_iWaitTimerT);
		return Plugin_Continue;
	}
	
	int limit = g_KvConfig.GetNum("mother_zombies", 2);
	int randomCL;
	for (int i = 0; i < limit; ++i)
	{
		randomCL = JWP_GetRandomTeamClient(CS_TEAM_T, true);
		if (randomCL != -1)
			InfectPlayer(randomCL);
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i, _, false))
		{
			// Remove god mode
			GodMode(i, false);
			if (!gZombie_IsZombie[i])
			{
				CS_SwitchTeam(i, CS_TEAM_CT);
				GiveWpn(i, "weapon_m249");
			}
		}
	}
	
	if (g_iWaitTimerCT > 0)
	{
		g_hCtTimer = CreateTimer(1.0, ZombieGlobalTimer_Callback, _, TIMER_REPEAT);
		PrintToChatAll("\x01[\x02%s\x01] \x04Игра ограничена на %d секунд. Если зомби не успеют заразить, они будут убиты", g_cGameName, g_iWaitTimerCT);
	}
	
	g_hTerTimer = null;
	
	return Plugin_Stop;
}

public Action ZombieGlobalTimer_Callback(Handle timer)
{
	if (--g_iWaitTimerCT > 0)
	{
		int pl_count = 0;
		PrintHintTextToAll("Игра закончится через %d секунд", g_iWaitTimerCT);
		
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsValidClient(i) && GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i))
				pl_count++;
		}
		
		if (pl_count == 0)
		{
			PrintHintTextToAll("Зомби победили!");
			g_hCtTimer = null;
			return Plugin_Stop;
		}
		
		return Plugin_Continue;
	}
	
	if (GetTeamClientCount(CS_TEAM_CT) > 0)
	{
		PrintHintTextToAll("Зомби проиграли!");
		PrintToChatAll("\x01[\x02ZombieMod\x01] \x03Зомби проиграли, они не успели заразить всех людей");
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsValidClient(i, _, false) && (GetClientTeam(i) == CS_TEAM_T))
				ForcePlayerSuicide(i);
		}
	}
	else
		PrintHintTextToAll("Зомби победили!");
	
	g_hCtTimer = null;
	return Plugin_Stop;
} 

void InfectPlayer(int client, bool first_infection = true)
{
	gZombie_IsZombie[client] = true;
	if (first_infection)
	{
		if (gZombie_fSpawnCoords[client][0] == 0.0 && gZombie_fSpawnCoords[client][1] == 0.0 && gZombie_fSpawnCoords[client][2] == 0.0)
			GetClientAbsOrigin(client, gZombie_fSpawnCoords[client]);
		TeleportEntity(client, gZombie_fSpawnCoords[client], NULL_VECTOR, NULL_VECTOR);
		PrintToChat(client, "\x01\x03Вы первый \x02зомби\x04. Заразите остальных игроков!");
	}
	else
		PrintToChat(client, "\x01\x03Вас инфецировали, вы \x02Зомби\x04, заразите остальных!");
	
	RemoveAllWeapons(client);
	GiveWpn(client, "weapon_knife");
	SetEntityHealth(client, gZombie_Health);
	
	if (FileExists(gZombie_Model) && IsModelPrecached(gZombie_Model))
		SetEntityModel(client, gZombie_Model);
	if(g_bIsCSGO)
		if (FileExists(gZombie_ModelArms) && IsModelPrecached(gZombie_ModelArms))
			SetEntPropString(client, Prop_Send, "m_szArmsModel", gZombie_ModelArms);
	CS_SwitchTeam(client, CS_TEAM_T);
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_KvConfig.GetFloat("zombie_speed", 1.2));
}

void StopZombie()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR)
			CS_SwitchTeam(i, gZombie_iClientTeam[i]);
		gZombie_IsZombie[i] = false;
	}
}

/* This step of code is made by FrozDark from his plugin zu_knockback.sp */

void KnockbackSetVelocity(int client, const float startpoint[3], const float endpoint[3], float magnitude)
{
	float vector[3];
	MakeVectorFromPoints(startpoint, endpoint, vector);
	
	// Normalize the vector (equal magnitude at varying distances)
	NormalizeVector(vector, vector);
	
	ScaleVector(vector, magnitude);
	
	if (g_bIsCSGO)
	{
		int flags = GetEntityFlags(client);
		float velocity[3];
		ClientVelocity(client, velocity);
		
		if (velocity[2] > CSGO_KNOCKBACK_BOOST_MAX)
			vector[2] = 0.0;
		else if (flags & FL_ONGROUND && vector[2] < CSGO_KNOCKBACK_BOOST)
			vector[2] = CSGO_KNOCKBACK_BOOST;
	}
	
	ClientVelocity(client, vector);
}

stock void ClientVelocity(int client, float vecVelocity[3], bool apply = true, bool stack = true)
{
	if (!apply)
	{
		for (int x = 0; x < 3; x++)
		{
			vecVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
		}
		
		return;
	}

	if (stack)
	{
		float vecClientVelocity[3];
		
		for (int x = 0; x < 3; x++)
		{
			vecClientVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
		}
		
		AddVectors(vecClientVelocity, vecVelocity, vecVelocity);
	}

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}