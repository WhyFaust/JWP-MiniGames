Handle missTimer[MAXPLAYERS+1];

void EventsInitialization()
{
    HookEvent("round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_OnRoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
    HookEvent("weapon_fire", Event_OnWeaponFire);
    HookEvent("weapon_fire_on_empty", Event_OnWeaponFire, EventHookMode_Post);
    HookEvent("player_hurt", Event_OnPlayerHurt);
}

public void OnClientPutInServer(int client)
{
    if (client)
    {
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
        SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
        SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
        g_hWhistleCooldown[client] = null;
    }
}

public void OnClientDisconnect(int client)
{
    if (g_hWhistleCooldown[client] != null)
    {
        KillTimer(g_hWhistleCooldown[client]);
        g_hWhistleCooldown[client] = null;
    }
    
    if (g_hCatchedTimer[client] != null)
    {
        KillTimer(g_hCatchedTimer[client]);
        g_hCatchedTimer[client] = null;
    }
    
    if (g_iGameMode == hotpotato)
    {
        if (g_iLastPotatoClient == client)
        {
            char sName[MAX_NAME_LENGTH];
            GetClientName(client, sName, sizeof(sName));
            CPrintToChatAll("%t%t", "JWP_MG_PREFIX", "JWP_MG_POTATO_DISCONNECT", sName);
            if (g_hCtTimer != null)
            {
                //g_iLastPotatoClient = JWP_GetRandomTeamClient(-1, true);
                g_iLastPotatoClient = -1;
                FindNewEnemyTimer_Callback(g_hCtTimer);
            }
        }
    }
}

public void Event_OnRoundStart(Event event, const char[] name, bool silent)
{
    if (g_iCoolDown != 0)
    {
        if (g_bGamePassed) g_iCoolDownCounter++;
        if (g_iCoolDownCounter >= g_iCoolDown)
        {
            g_iCoolDownCounter = 0;
            g_bGamePassed = false;
        }
    }
    if (g_bIsGameRunning || g_iGameMode != -1)
    {
        g_bGamePassed = true;
        
        Panel p_rules;
        if (g_aRules.Length > 0)
        {
            char temp[MAX_RULES_SIZE];
            p_rules = new Panel();
            char sBuffer[128];
            Format(sBuffer, sizeof(sBuffer), "%t", "JWP_MG_GAME_RULES_TITLE")
            p_rules.SetTitle(sBuffer);
            for (int i = 0; i < g_aRules.Length; i++)
            {
                g_aRules.GetString(i, temp, sizeof(temp));
                p_rules.DrawText(temp);
            }
            Format(sBuffer, sizeof(sBuffer), "%t", "JWP_MG_ITEM_OK")
            p_rules.DrawItem(sBuffer);
        }
        
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsValidClient(i, _, false))
            {
                if (p_rules != null)
                    p_rules.Send(i, pRules_Callback, 20);
                SetEntData(i, g_CollisionGroupOffset, 2, 4, true);
            }
        }
        g_aRules.Clear();
        delete p_rules;
        
        ForceFirstPersonToAll();
        
        ClassicDoorsOpen();
        
        g_iGameMode = g_iGameId;
        g_iGameId = -1;
        g_bIsGameRunning = true;
        
        Call_StartForward(g_fwdMiniGameStart);
        Call_Finish();
        
        PrintToChatAll("%s", g_cGameRules); // Print rules to all chat
        
        if (g_iGameMode == zombiemod)
            ProcessZombie();
        else if (g_iGameMode == hidenseek)
            ProcessHidenSeek();
        else if (g_iGameMode == chickenhunt)
            ProcessChickenHunt();
        else if (g_iGameMode == zeusdm)
            ProcessZeusDm();
        else if (g_iGameMode == hotpotato)
            ProcessHotPotato();
        else if (g_iGameMode == catchnfree)
            ProcessCatchnFree();
        
        g_KvConfig.GetString("musicAll", g_cMusicAll, sizeof(g_cMusicAll), "");
        if (g_cMusicAll[0] != NULL_STRING[0])
        {
            // float sound_pos[3] = {0.0, ...};
            // EmitAmbientSoundAny(g_cMusicAll, sound_pos);
            // EmitAmbientSoundAny(g_cMusicAll, sound_pos);
            // EmitSoundToAllAny("tib/gc_game_remix.mp3", SOUND_FROM_PLAYER);
            
            for (int i = 1; i <= MaxClients; ++i)
            {
                if (IsValidClient(i))
                {
                    if(g_bIsCSGO)
                    { 
                        ClientCommand(i, "playgamesound Music.StopAllMusic");
                        ClientCommand(i, "play *%s", g_cMusicAll);
                    }
                    else
                    {
                        ClientCommand(i, "play %s", g_cMusicAll);
                    }
                }
            }
            
            // PrintToChatAll("Ambient music: %s", g_cMusicAll);
        }
    }
}

public void Event_OnRoundEnd(Event event, const char[] name, bool silent)
{
    if (g_hTerTimer != null)
    {
        KillTimer(g_hTerTimer);
        g_hTerTimer = null;
    }
    
    if (g_hCtTimer != null)
    {
        KillTimer(g_hCtTimer);
        g_hCtTimer = null;
    }
    
    // If game is chosen, but not active
    if (g_iGameId != -1)
    {
        g_bIsGameRunning = true;
        
        // ExecuteServerCommand(g_aDisabledPlugins, "disabled_plugins", true, true);
        ExecuteServerCommand(g_aDisabledPlugins, true, true);
        ExecuteServerCommand(g_aOnGameStart, false, true);
        
        if (g_iBlockLR)
        {
            if (g_CvarLastRequest != null)
                g_CvarLastRequest.SetInt(0, false, true); // Disable last request while game is running
        }
        
        
        // For some games change cvars
        // Something cvars to change
    }
    
    // If game active
    if (g_iGameMode != -1)
    {
        if (g_iGameMode == zombiemod)StopZombie();
        else if (g_iGameMode == hidenseek || g_iGameMode == chickenhunt) ForceFirstPersonToAll();
        else if (g_iGameMode == zeusdm)
            g_CvarTeammatesEnemies.SetBool(false, true, false);
        else if (g_iGameMode == hotpotato)
            g_CvarIgnoreWinRound.SetBool(false, true, false);
        else if (g_iGameMode == catchnfree)
            g_CvarTeammatesEnemies.SetBool(false, true, false);
        
        g_iGameMode = -1;
        g_bIsGameRunning = false;
        
        Call_StartForward(g_fwdMiniGameEnd);
        Call_Finish();
        
        // Enable disabled plugins
        ExecuteServerCommand(g_aDisabledPlugins, true, false);
        ExecuteServerCommand(g_aOnGameEnd, false, false);
        
        if (g_iBlockLR)
        {
            if (g_CvarLastRequest != null)
            {
                g_CvarLastRequest.SetInt(1, false, true); // Enable last request while game is running
            }
        }
        
        g_KvConfig.Rewind();
        
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsValidClient(i, _, false))
            {
                SetEntData(i, g_CollisionGroupOffset, 5, 4, true);
                SetClientSpeed(i, 1.0);
            }
        }
    }
}

void ExecuteServerCommand(ArrayList &array, bool isPlugin, bool onGameStart)
{
    if (array == null || g_KvConfig == null) return;
    
    if (array.Length == 0) return;
    
    char cBuffer[64];
    for (int i = 0; i < array.Length; ++i)
    {
        array.GetString(i, cBuffer, sizeof(cBuffer));
        if (isPlugin)
        {
            if (onGameStart)
                Format(cBuffer, sizeof(cBuffer), "sm plugins unload %s", cBuffer);
            else
                Format(cBuffer, sizeof(cBuffer), "sm plugins load %s", cBuffer);
            ServerCommand(cBuffer);
        }
        else
        {
            ServerCommand(cBuffer);
        }
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (g_iGameMode == hidenseek || g_iGameMode == chickenhunt)
    {
        if (IsValidClient(client) && GetClientTeam(client) == CS_TEAM_T)
        {
            if (buttons & IN_ATTACK)
                buttons &= ~IN_ATTACK;
        }
    }
    
    return Plugin_Continue;
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool silent)
{
    int alive_ct, alive_t, alive;
    int iLastAlive = -1;
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsValidClient(i, _, false))
        {
            if (GetClientTeam(i) == CS_TEAM_CT)
                alive_ct++;
            if (GetClientTeam(i) == CS_TEAM_T)
                alive_t++;
            alive++;
            iLastAlive = i;
        }
    }
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_iGameMode == zombiemod)
    {	
        if (alive_ct == 0)
        {
            if (g_hCtTimer != null)
                delete g_hCtTimer;
            if (g_hTerTimer != null)
                delete g_hTerTimer;
            CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
        }
    }
    else if (g_iGameMode == hidenseek)
    {
        TiB_SetThirdPerson(client, false);
        
        if (g_bIsCSGO)
            SetEntityModel(client, "models/player/tm_phoenix.mdl");
        else
            SetEntityModel(client, "models/player/t_leet.mdl");
        
        int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
        if (ragdoll && IsValidEdict(ragdoll))
            AcceptEntityInput(ragdoll, "Kill");
    }
    else if (g_iGameMode == chickenhunt)
    {
        TiB_SetThirdPerson(client, false);
    }
    else if (g_iGameMode == zeusdm)
    {
        if (!alive) CS_TerminateRound(1.0, CSRoundEnd_Draw);
    }
    else if (g_iGameMode == hotpotato)
    {
        if (alive == 0) CS_TerminateRound(1.0, CSRoundEnd_Draw);
        else if (alive == 1)
        {
            int iTeam = GetClientTeam(iLastAlive);
            if (iTeam == CS_TEAM_T)
                CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
            else
                CS_TerminateRound(1.0, CSRoundEnd_CTWin);
        }
    }
    else if (g_iGameMode == catchnfree)
    {
        if (alive_t == 0 || alive_ct == 0)
        {
            CS_TerminateRound(1.0, CSRoundEnd_Draw);
        }
    }
    
    return Plugin_Continue;
}

public Action Event_OnPlayerHurt(Event event, const char[] name, bool silent)
{
    if (g_iGameMode == zombiemod)
    {
        int attacker = GetClientOfUserId(event.GetInt("attacker"));
        if (!IsValidClient(attacker) || gZombie_IsZombie[attacker])
            return Plugin_Continue;
        
        int client = GetClientOfUserId(event.GetInt("userid"));
        
        if (!IsValidClient(client) || !gZombie_IsZombie[client])
            return Plugin_Continue;
        
        
        float clientloc[3], attackerloc[3];
        GetClientAbsOrigin(client, clientloc);
        GetClientEyePosition(attacker, attackerloc);
        
        float attackerang[3];
        GetClientEyeAngles(attacker, attackerang);
        
        TR_TraceRayFilter(attackerloc, attackerang, MASK_ALL, RayType_Infinite, KnockbackTRFilter);
        TR_GetEndPosition(clientloc);
        
        // Override knockback value
        gZombie_fKnockback = 1.0;
        gZombie_fKnockback = g_KvConfig.GetFloat("zombie_knockback", 1.0)
        KnockbackSetVelocity(client, attackerloc, clientloc, gZombie_fKnockback)
        
    }
    else if (g_iGameMode == hidenseek)
    {
        int client = GetClientOfUserId(event.GetInt("attacker"));
        
        if (!client) return Plugin_Continue;
        
        if (missTimer[client] != null)
        {
            KillTimer(missTimer[client]);
            missTimer[client] = null;
        }
    }
    
    return Plugin_Continue;
}

public Action Event_OnWeaponFire(Event event, const char[] name, bool silent)
{
    if (g_iGameMode == zombiemod || g_iGameMode == chickenhunt)
    {
        int client = GetClientOfUserId(event.GetInt("userid"));
        
        if (!IsValidClient(client) || GetClientTeam(client) != CS_TEAM_CT)
            return Plugin_Continue;
        RegenAmmo(client);
    }
    
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    if (g_iGameMode == hidenseek)
    {
        int entity = GetEntDataEnt2(client, g_iActiveWeaponOffset);
        char cWeapon[24];
        GetEntityClassname(entity, cWeapon, sizeof(cWeapon));
        // Timer not currently running
        if (missTimer[client] == null)
        {
            // Should filter knife and grenades
            if (StrContains(cWeapon, "grenade", false) == -1 && StrContains(cWeapon, "flash", false) == -1 && StrContains(cWeapon, "knife", false) == -1)
            {
                Handle datapack;
                missTimer[client] = CreateDataTimer(0.1, Missed, datapack);
                WritePackCell(datapack, client);
                WritePackCell(datapack, userid);
                ResetPack(datapack);
            }
        }
    }
    if (g_iGameMode == zeusdm)
    {
        if (IsValidClient(client, _, false))
        {
            char cWeapon[32];
            event.GetString("weapon", cWeapon, sizeof(cWeapon));
            if (StrEqual(cWeapon, "weapon_taser", false))
            {
                int weapon = GetEntDataEnt2(client, g_iActiveWeaponOffset);
                SetEntData(weapon, g_iClipOffset, 2, 4, true); // 2 ammo (unlimited ammo)
                SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Missed(Handle timer, Handle datapack)
{
    int client = ReadPackCell(datapack);
    missTimer[client] = null; // clear timer handle
    
    int userid = ReadPackCell(datapack);
    if (!IsValidClient(client, _, false)) // Not in game anymore or dead
        return;
    if (g_iGameMode == hidenseek)
    {
        bool isSlapDamage = view_as<bool>(g_KvConfig.GetNum("slap_penalty", 0));
        
        int hp = g_KvConfig.GetNum("missing_penalty", 10);
        if (hp < 0) hp = 0;
        if (hp > 0)
        {
            if (isSlapDamage)
                SlapPlayer(client, hp, false);
            else
                SDKHooks_TakeDamage(client, client, client, float(hp), DMG_CLUB);
        }
    }
}

public bool KnockbackTRFilter(int entity, int contentsMask)
{
    if (entity > 0 && entity < MAXPLAYERS)
        return false;
    return true;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (IsValidClient(attacker) && IsValidClient(victim))
    {
        if (g_iGameMode == zombiemod)
        {
            if (gZombie_IsZombie[attacker] && GetTeamClientCount(CS_TEAM_CT) > 1)
            {
                if (gZombie_IsZombie[victim])
                    return Plugin_Handled;
                else
                    InfectPlayer(victim, false);
            }
            else return Plugin_Continue;
        }
        else if (g_iGameMode == hotpotato)
        {
            return Plugin_Handled;
        }
        else if (g_iGameMode == hidenseek || g_iGameMode == chickenhunt)
        {
            if (GetClientTeam(attacker) == CS_TEAM_T) return Plugin_Handled;
        }
        else if (g_iGameMode == catchnfree)
        {
            if (GetClientTeam(attacker) == CS_TEAM_T)
            {
                if (g_hCatchedTimer[victim] == null && GetClientTeam(victim) == CS_TEAM_T && g_bCatched[victim])
                {
                    g_bCatched[victim] = false;
                    GiveWpn(victim, "weapon_knife");
                }
            }
            else
            {
                if (g_hCatchedTimer[victim] == null && GetClientTeam(victim) == CS_TEAM_T && g_bCatched[victim] == false)
                {
                    g_bCatched[victim] = true;
                    g_hCatchedTimer[victim] = CreateTimer(g_flCatchDelay, Timer_CatchnFreeDelay, victim);
                    
                    CPrintToChat(victim, "%t%t", "JWP_MG_PREFIX", "JWP_MG_CATCH_TIME_DEFROST", g_flCatchDelay);
                    RemoveAllWeapons(victim);
                }
            }
            
            if (g_bCatched[victim])
            {
                SetEntityMoveType(victim, MOVETYPE_NONE);
            }
            else
            {
                SetEntityMoveType(victim, MOVETYPE_WALK);
                float fSpeed = g_KvConfig.GetFloat("t_speed", 1.6);
                if (fSpeed < 1.0) fSpeed = 1.0;
                SetClientSpeed(victim, fSpeed);
            }
            
            return Plugin_Handled; // and block any damage
        }
        // Else other game
    }
    
    return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
    char class[24];
    GetEntityClassname(weapon, class, sizeof(class));
    if (g_iGameMode == zombiemod)
    {
        if (gZombie_IsZombie[client])
        {
            if (!StrEqual(class, "weapon_knife"))
                return Plugin_Handled;
        }
    }
    else if (g_iGameMode == hidenseek || g_iGameMode == chickenhunt)
    {
        if (GetClientTeam(client) == CS_TEAM_T) return Plugin_Handled;
    }
    else if (g_iGameMode == zeusdm)
    {
        if (!StrEqual(class, "weapon_taser"))
            return Plugin_Handled;
    }
    else if (g_iGameMode == hotpotato)
    {
        if (weapon != g_iEntityPotato)
            return Plugin_Handled;
    }
    else if (g_iGameMode == catchnfree)
    {
        if (StrEqual(class, "weapon_knife") == false)
            return Plugin_Handled;
    }
    return Plugin_Continue;
}

public Action OnWeaponEquip(int client, int weapon)
{
    if (g_iGameMode == hotpotato)
    {
        if (weapon == g_iEntityPotato)
        {
            if (client != g_iLastPotatoClient)
            {
                char sName[MAX_NAME_LENGTH];
                GetClientName(client, sName, sizeof(sName));
                CPrintToChat(g_iLastPotatoClient, "%t%t", "JWP_MG_PREFIX", "JWP_MG_POTATO_PASSED", sName);
                g_iLastPotatoClient = client;
                SetClientSpeed(client, g_flPotatoSpeed);
                CPrintToChat(g_iLastPotatoClient, "%t%t", "JWP_MG_PREFIX", "JWP_MG_POTATO_THROWN");
            }
        }
    }
    else if (g_iGameMode == hidenseek || g_iGameMode == chickenhunt)
    {
        if (GetClientTeam(client) == CS_TEAM_T)
            return Plugin_Handled;
    }
    else if (g_iGameMode == catchnfree)
    {
        char class[24];
        GetEntityClassname(weapon, class, sizeof(class));
        if (StrEqual(class, "weapon_knife") == false)
            return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action CS_OnCSWeaponDrop(int client, int weaponIndex)
{
    if (g_iGameMode == hotpotato)
    {
        if (weaponIndex == g_iEntityPotato)
            SetClientSpeed(client, 1.0);
    }
    
    return Plugin_Continue;
}

public int pRules_Callback(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End: delete menu;
    }
}