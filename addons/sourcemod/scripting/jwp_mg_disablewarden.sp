#include <sourcemod>
#include <jwp>
#include <jwp_mg>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"

bool g_bEnabled = true;

public Plugin myinfo = 
{
	name = "[JWP_MG] Disable Warden",
	description = "Remove warden & zam if MiniGame started",
	author = "BaFeR",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public int JWP_MG_GameStart()
{
	// Disable searching for a new warden
	g_bEnabled = false;
	// announce just notify that LR is available and can be disabled
	// At first we remove zam and after warden
	JWP_SetZamWarden(0);
	JWP_SetWarden(0);
	
	JWP_ActionMsgAll("КМД заблокирован во время игровых дней");
}

public int JWP_MG_GameEnd()
{
	g_bEnabled = true;
		
	JWP_ActionMsgAll("КМД снова доступен");
}

public bool JWP_OnWardenChoosing()
{
	return g_bEnabled;
}