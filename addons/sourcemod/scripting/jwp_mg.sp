#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <emitsoundany>
#include <csgocolors>

#undef REQUIRE_PLUGIN
#include <jwp>
#include <jwp_mg>
#include <hosties>
#include <lastrequest>
#define REQUIRE_PLUGIN

// Force 1.7 syntax
#pragma newdecls required

#define PLUGIN_VERSION "1.6"
#define ITEM "mg"

#define LOG_PATH "addons/sourcemod/logs/JWP_MG_Log.log"

bool g_bIsCSGO;

int g_iGameMode = -1, g_iGameId = -1, g_iLastGame;
bool g_bIsGameRunning = false;

char g_cGameName[32], g_cGameRules[192], g_cMusicAll[PLATFORM_MAX_PATH];
int g_iWaitTimerT, g_iWaitTimerCT;
int g_iBlockLR;
KeyValues g_KvConfig;

Handle	g_fwdMiniGameStart, g_fwdMiniGameEnd;

// Menu restrictions
int g_iMapLimit, g_iMapLimitCounter;
int g_iCoolDown, g_iCoolDownCounter;
bool g_bGamePassed;

Handle g_hTerTimer, g_hCtTimer, g_hWhistleCooldown[MAXPLAYERS+1];

// Zombie velocity
int g_iToolsVelocity;
// Collision off
int g_CollisionGroupOffset;

// Weapon & Ammo offsets
int g_iClipOffset, g_iAmmoOffset, g_iPrimaryAmmoTypeOffset, g_iActiveWeaponOffset;

public Plugin myinfo =
{
    name = "[JWP] MiniGames",
    description = "Minigames for Jail Warden Pro",
    author = "White Wolf, BaFeR",
    version = PLUGIN_VERSION
};

#include "jwp/mg/cvars.sp"
#include "jwp/mg/kv_config.sp"
#include "jwp/mg/menu.sp"
#include "jwp/mg/functions.sp"
#include "jwp/mg/games/zombie.sp"
#include "jwp/mg/games/hidenseek.sp"
#include "jwp/mg/games/chickenhunt.sp"
#include "jwp/mg/games/hotpotato.sp"
#include "jwp/mg/games/zeusdm.sp"
#include "jwp/mg/games/catchnfree.sp"
#include "jwp/mg/events.sp"

public void OnPluginStart()
{
    if (GetEngineVersion() == Engine_CSGO)
        g_bIsCSGO = true;
    else g_bIsCSGO = false;
    
    g_iClipOffset			  = UTIL_FindSendPropInfo("CBaseCombatWeapon",	"m_iClip1");
    g_iPrimaryAmmoTypeOffset  = UTIL_FindSendPropInfo("CBaseCombatWeapon",	"m_iPrimaryAmmoType");
    g_iAmmoOffset			  = UTIL_FindSendPropInfo("CCSPlayer",			"m_iAmmo");
    g_iActiveWeaponOffset	  = UTIL_FindSendPropInfo("CCSPlayer",			"m_hActiveWeapon");
    g_CollisionGroupOffset	  = UTIL_FindSendPropInfo("CBaseEntity",		"m_CollisionGroup");
    g_iToolsVelocity		  = UTIL_FindSendPropInfo("CBasePlayer",		"m_vecVelocity[0]");

    LoadTranslations("jwp_minigames.phrases");

    CvarInitialization();
    MenuInitialization();
    ReadGameModeConfigs();
    EventsInitialization();
    
    RegConsoleCmd("sm_mask", Command_Mask, "Pick up model for hidenseek");
    RegConsoleCmd("sm_whistle", Command_Whistle, "Whistle for hidenseek or chickenhunt");
    RegConsoleCmd("sm_lr", Listener_LRCommand); // AddCommandListener not block this command

    RegConsoleCmd("sm_mg_debug", cmd_hss);
    
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsValidClient(i))
            OnClientPutInServer(i);
    }
    
    if (JWP_IsStarted()) JWP_Started();
}

public Action cmd_hss (int iClient, int iArgs)
{
    PrintToChatAll("g_iGameMode = %i, g_iGameId = %i;", g_iGameMode, g_iGameId);
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max) 
{
    g_fwdMiniGameStart = CreateGlobalForward("JWP_MG_GameStart", ET_Ignore, Param_Cell);
    g_fwdMiniGameEnd = CreateGlobalForward("JWP_MG_GameEnd", ET_Ignore, Param_Cell);
    
    
    //CreateNative("JWP_MG_GetGame", Native_JWP_MG_GetGame);
    
    RegPluginLibrary("jwp_mg");

    return APLRes_Success; // Для продолжения загрузки плагина нужно вернуть APLRes_Success
}

public int Native_JWP_MG_GetGame(Handle plugin, int numParams)
{
    return g_iGameMode;
}

/*
bool Forward_MiniGameStart()
{
    Call_StartForward(g_fwdMiniGameStart);
    if (Call_Finish(g_iGameMode != -1) != SP_ERROR_NONE)
        LogToFile(LOG_PATH, "Forward_MiniGameStart error");
    
    return g_iGameMode != -1;
}*/

public void OnMapStart()
{
    if (g_bIsCSGO)
    {
        PrecacheModel("models/player/tm_phoenix.mdl");
        PrecacheModel("models/chicken/chicken.mdl", true);
    }
    else
        PrecacheModel("models/player/t_leet.mdl");
    
    g_iGameId = -1;
    g_iGameMode = -1;
    g_bIsGameRunning = false;
    
    PrecacheMusic();
    
    CreateDoorList();
}

public Action Command_Mask(int client, int args)
{
    if (IsValidClient(client))
    {
        if (g_iGameMode != hidenseek)
        {
            CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_MASK_NOT_AVAILABLE");
            return Plugin_Handled;
        }
        if (GetClientTeam(client) == CS_TEAM_T)
        {
            if (IsPlayerAlive(client))
            {
                int propLimit = g_KvConfig.GetNum("max_masks", 0);
                if (propLimit < 0) propLimit = 0;
                
                if (!propLimit || g_iMaxMasks[client] < propLimit)
                    g_PropsMenu.Display(client, 20);
                else
                    CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_ITEMS_LIMIT", g_iMaxMasks[client], propLimit);
            }
            else
                CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_ONLY_ALIVE");
        }
        else
            CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_ONLY_T");
    }
    
    return Plugin_Handled;
}

public Action Command_Whistle(int client, int args)
{
    if (IsValidClient(client))
    {
        if (g_iGameMode != hidenseek && g_iGameMode != chickenhunt)
        {
            CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_WHISTLE_NOT_AVAILABLE");
            return Plugin_Handled;
        }
        if (GetClientTeam(client) == CS_TEAM_T)
        {
            if (IsPlayerAlive(client))
            {
                if (g_hWhistleCooldown[client] == null)
                {
                    g_hWhistleCooldown[client] = CreateTimer(15.0, WhistleCooldownTimer, client);
                    char sName[MAX_NAME_LENGTH];
                    GetClientName(client, sName, sizeof(sName));
                    CPrintToChatAll("%t%t", "JWP_MG_PREFIX", "JWP_MG_WHISTLE_ALERT", sName);
                    EmitSoundToAllAny("tib/curlik.mp3", client);
                }
                else
                    CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_WHISTLE_TIME");
            }
            else
                CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_ONLY_ALIVE");
        }
        else
            CPrintToChat(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_ONLY_T");
    }
    
    return Plugin_Handled;
}

public Action WhistleCooldownTimer(Handle timer, any client)
{
    g_hWhistleCooldown[client] = null;
}

public Action Listener_LRCommand(int client, int args)
{
    if (g_iGameMode != -1)
    {
        if (g_iBlockLR)
        {
            if (IsValidClient(client))
            {
                CReplyToCommand(client, "%t%t", "JWP_MG_PREFIX", "JWP_MG_BLOCK_LR");
                return Plugin_Stop;
            }
        }
    }
    return Plugin_Continue;
}

public void OnPluginEnd()
{
    JWP_RemoveFromMainMenu();
    if (g_MainMenu != null)
        delete g_MainMenu;
}

bool IsValidClient(int iClient, bool bAllowBots = false, bool bAllowDead = true)
{
    if (!(1 <= iClient <= MaxClients) || !IsClientInGame(iClient) || (IsFakeClient(iClient) && !bAllowBots) || IsClientSourceTV(iClient) || IsClientReplay(iClient) || (!bAllowDead && !IsPlayerAlive(iClient)))
    {
        return false;
    }
    return true;
}