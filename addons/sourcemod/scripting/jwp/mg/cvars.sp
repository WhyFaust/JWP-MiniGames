ConVar	g_CvarThirdPerson,
		g_CvarPlayerId,
		g_CvarLastRequest,
		g_CvarTeammatesEnemies,
		g_CvarIgnoreWinRound;

void CvarInitialization()
{
	if (g_bIsCSGO)
	{
		g_CvarThirdPerson = FindConVar("sv_allow_thirdperson");
		g_CvarTeammatesEnemies = FindConVar("mp_teammates_are_enemies");
	}
	g_CvarPlayerId = FindConVar("mp_playerid");
	g_CvarLastRequest = FindConVar("sm_hosties_lr");
	g_CvarIgnoreWinRound = FindConVar("mp_ignore_round_win_conditions");
}

public void OnConfigsExecuted()
{
	if (g_CvarThirdPerson != null)
	{
		g_CvarThirdPerson.SetBool(true, false, false);
	}
}