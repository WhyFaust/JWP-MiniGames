#define FFADE_IN			0x0001		// Just here so we don't pass 0 into the function
#define FFADE_OUT			0x0002		// Fade out (not in)
#define FFADE_MODULATE		0x0004		// Modulate (don't blend)
#define FFADE_STAYOUT		0x0008		// ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE			0x0010		// Purges all other fades, replacing them with this one

float NULL_VELOCITY[3] = {0.0, 0.0, 0.0};

int g_iaGrenadeOffsets[] = {15, 17, 16, 14, 18, 17};
ArrayList g_aDoors;

stock int GiveWpn(int client, const char[] weapon, int clip = -1, int ammo = -1)
{
	int iWeapon = GivePlayerItem(client, weapon);
	
	if (clip != -1)
		SetEntProp(iWeapon, Prop_Data, "m_iClip1", clip);
	if (ammo != -1)
	{
		if (g_bIsCSGO)
			SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
		else
			SetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoCount", ammo);
	}
	
	char buffer[64];
	Format(buffer, sizeof(buffer), "use %s", weapon);
	FakeClientCommand(client, buffer);
	
	return iWeapon;
}

void RemoveAllWeapons(int client)
{
	int weapon;
	for (int i = 0; i < 5; ++i)
	{
		weapon = GetPlayerWeaponSlot(client, i);
		if (IsValidEdict(weapon))
		{
			RemovePlayerItem(client, weapon);
			AcceptEntityInput(weapon, "Kill");
		}
		if (i == 3)
		{
			for (int k = 0; k < 6; ++k)
				SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, g_iaGrenadeOffsets[k]);
		}
	}
}

void CreateDoorList()
{
	if (g_aDoors == null)
		g_aDoors = new ArrayList(1);
	else
		g_aDoors.Clear();
	
	int ent = GetMaxEntities();
	char class[28];
	while (ent > MaxClients)
	{
		ent--;
		if (IsValidEntity(ent) && GetEntityClassname(ent, class, sizeof(class)) && TiB_IsDoor(class))
			g_aDoors.Push(ent);
	}
}

bool TiB_IsDoor(const char[] classname)
{
	return (StrContains(classname, "movelinear", false) || StrContains(classname, "door", false));
}

void ClassicDoorsOpen()
{
	if (!g_aDoors.Length) return;
	
	int ent;
	char class[28];
	for (int i = 0; i < g_aDoors.Length; ++i)
	{
		ent = g_aDoors.Get(i);
		if (IsValidEntity(ent) && GetEntityClassname(ent, class, sizeof(class)) && TiB_IsDoor(class))
		{
			AcceptEntityInput(ent, "Unlock");
			AcceptEntityInput(ent, "Open");
		}
	}
}

void ScreenFade(int client, int duration, int mode, int holdtime=-1, int r=0, int g=0, int b=0, int a=255)
{
	Handle userMessage = StartMessageOne("Fade", client, USERMSG_RELIABLE);
	
	if (GetUserMessageType() == UM_Protobuf)
	{
		int color[4];
		color[0] = r;
		color[1] = g;
		color[2] = b;
		color[3] = a;
		
		PbSetInt(userMessage, "duration", duration);
		PbSetInt(userMessage, "hold_time", holdtime);
		PbSetInt(userMessage, "flags", mode);
		PbSetColor(userMessage, "clr", color);
	}
	else
	{
		BfWriteShort(userMessage,	duration);	// Fade duration
		BfWriteShort(userMessage,	holdtime);	// Fade hold time
		BfWriteShort(userMessage,	mode);		// What to do
		BfWriteByte(userMessage,	r);			// Color R
		BfWriteByte(userMessage,	g);			// Color G
		BfWriteByte(userMessage,	b);			// Color B
		BfWriteByte(userMessage,	a);			// Color Alpha
	}
	
	EndMessage();
}

void TiB_SetThirdPerson(int client, bool status)
{
	if (status)
	{
		if (g_bIsCSGO)
			ClientCommand(client, "thirdperson");
		else
		{
			SetEntPropEnt(client, Prop_Data, "m_hObserverTarget", 0);
			SetEntProp(client, Prop_Data, "m_iObserverMode", 1, 4);
			SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 0, 4);
			SetEntProp(client, Prop_Data, "m_iFOV", 120, 4);
		}
	}
	else
	{
		if (g_bIsCSGO)
			ClientCommand(client, "firstperson");
		else
		{
			SetEntPropEnt(client, Prop_Data, "m_hObserverTarget", -1);
			SetEntProp(client, Prop_Data, "m_iObserverMode", 0, 4);
			SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 1, 4);
			SetEntProp(client, Prop_Data, "m_iFOV", 90, 4);
		}
	}
}

void ForceFirstPersonToAll()
{
	/* Force first person for all players Necessary! */ 
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			TiB_SetThirdPerson(i, false);
		}
	}
}

void RegenAmmo(int client)
{
	if (client && IsClientInGame(client) && !IsFakeClient(client))
	{
		int weapon = GetEntDataEnt2(client, g_iActiveWeaponOffset);
		int ammotype = GetEntData(weapon, g_iPrimaryAmmoTypeOffset);
		if (ammotype == -1) return;
		if (IsValidEdict(weapon))
		{
			SetEntData(weapon, g_iClipOffset, 2, 4, true); // 2 ammo
			if (g_bIsCSGO)
				SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
			else
				SetEntData(client, g_iAmmoOffset+(ammotype*4), 0, _, true);
		}
	}
}

void GodMode(int client, bool isOn)
{
	if (isOn)
		SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);
	else
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
}

void SetClientSpeed(int client, float speed)
{
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed);
}