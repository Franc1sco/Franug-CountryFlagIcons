/*  SM Franug Country Flag Icons
 *
 *  Copyright (C) 2019 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */
 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <geoip>
#undef REQUIRE_PLUGIN
#include <ScoreboardCustomLevels>


int m_iOffset = -1;
int m_iLevel[MAXPLAYERS+1];

char m_cFilePath[PLATFORM_MAX_PATH];

KeyValues kv;

bool g_bCustomLevels;

#define DATA "1.2"

public Plugin myinfo = 
{
	name = "SM Franug Country Flag Icons",
	author = "Franc1sco franug",
	description = "",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("SCL_GetLevel");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	m_iOffset = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");
	BuildPath(Path_SM, m_cFilePath, sizeof(m_cFilePath), "configs/franug_countryflags.cfg");
	
	for(int i = 1; i <= MaxClients; i++)
	{
		m_iLevel[i] = -1;
	}
	
	g_bCustomLevels = LibraryExists("ScoreboardCustomLevels");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "ScoreboardCustomLevels"))
		g_bCustomLevels = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "ScoreboardCustomLevels"))
		g_bCustomLevels = false;
}

public OnClientPostAdminCheck(client)
{
	m_iLevel[client] = -1;
	
	if (IsFakeClient(client))
		return;

	char ip[16];
	char code2[3];
	
	if (!GetClientIP(client, ip, sizeof(ip)))return;
	
	if (!GeoipCode2(ip, code2))return;
	
	
	if(!KvJumpToKey(kv, code2))
	{
		KvRewind(kv);
		return;
	}
	
	m_iLevel[client] = KvGetNum(kv, "index");
	KvRewind(kv);
}

public void OnClientDisconnect(int client)
{
	m_iLevel[client] = -1;
}


public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];

	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);

	if (kv != null)kv.Close();
	
	kv = CreateKeyValues("CountryFlags");
	FileToKeyValues(kv, m_cFilePath);
    
	if (!KvGotoFirstSubKey(kv)) return;

	do
	{
		Format(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/xp/level%i.png", KvGetNum(kv, "index"));
		AddFileToDownloadsTable(sBuffer);
    	
	} while (KvGotoNextKey(kv));
	
	KvRewind(kv);
}

public void OnThinkPost(int m_iEntity)
{
	int m_iLevelTemp[MAXPLAYERS+1] = 0;
	GetEntDataArray(m_iEntity, m_iOffset, m_iLevelTemp, MAXPLAYERS+1);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(m_iLevel[i] != -1)
		{
			if(m_iLevel[i] != m_iLevelTemp[i])
			{
				if (g_bCustomLevels && SCL_GetLevel(i) > -1)continue; // dont overwritte other custom level
				
				SetEntData(m_iEntity, m_iOffset + (i * 4), m_iLevel[i]);
			}
		}
	}
}