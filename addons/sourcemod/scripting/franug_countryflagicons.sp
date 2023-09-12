/*  SM Franug Country Flag Icons
 *
 *  Copyright (C) 2019-2023 Francisco 'Franc1sco' García
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
#include <clientprefs>

int m_iOffset = -1;
int m_iLevel[MAXPLAYERS+1];

Cookie hShowFlagCookie;

char m_cFilePath[PLATFORM_MAX_PATH];
char serverIp[16];

KeyValues kv;

bool g_bCustomLevels;
bool g_hShowflag[MAXPLAYERS + 1] = {true, ...};

ConVar net_public_adr = null;

#define DATA "1.4.1"

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
	net_public_adr = FindConVar("net_public_adr");

	m_iOffset = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");
	BuildPath(Path_SM, m_cFilePath, sizeof(m_cFilePath), "configs/franug_countryflags.cfg");

	RegConsoleCmd("sm_showflag", Cmd_Showflag, "This allows players to hide their flag");
	hShowFlagCookie = new Cookie("Flags-Icons_No_Flags_Cookie", "Show or hide the flag.", CookieAccess_Private);

	for(int i = 1; i <= MaxClients; i++)
	{
		m_iLevel[i] = -1;
	}

	g_bCustomLevels = LibraryExists("ScoreboardCustomLevels");
}

public void OnConfigsExecuted()
{
	net_public_adr.GetString(serverIp, sizeof(serverIp));
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

	if (!GetClientIP(client, ip, sizeof(ip)) || !IsLocalAddress(ip) && !GeoipCode2(ip, code2) || !g_hShowflag[client])
	{
		if(kv.JumpToKey("UNKNOWN"))
		{
			m_iLevel[client] = kv.GetNum("index");
		}

		kv.Rewind();
		return;
	}

	if(IsLocalAddress(ip))
	{
		GeoipCode2(serverIp, code2);
	}

	if(!kv.JumpToKey(code2))
	{
		kv.Rewind();
		if(kv.JumpToKey("UNKNOWN"))
		{
			m_iLevel[client] = kv.GetNum("index");
		}

		kv.Rewind();
		return;
	}

	m_iLevel[client] = kv.GetNum("index");
	kv.Rewind();
}

public void OnClientDisconnect(int client)
{
	m_iLevel[client] = -1;
}

public Action Cmd_Showflag(int client, int args)
{
	if (AreClientCookiesCached(client))
	{
		char sCookieValue[12];
		hShowFlagCookie.Get(client, sCookieValue, sizeof(sCookieValue));
		int cookieValue = StringToInt(sCookieValue);
		if (cookieValue == 1)
		{
			cookieValue = 0;
			g_hShowflag[client] = true;
			IntToString(cookieValue, sCookieValue, sizeof(sCookieValue));
			hShowFlagCookie.Set(client, sCookieValue);
			OnClientPostAdminCheck(client);
			ReplyToCommand(client, "[SM] Your flag is now visible");
		}
		else
		{
			cookieValue = 1;
			g_hShowflag[client] = false;
			IntToString(cookieValue, sCookieValue, sizeof(sCookieValue));
			hShowFlagCookie.Set(client, sCookieValue);
			OnClientPostAdminCheck(client);
			ReplyToCommand(client, "[SM] Your flag is no longer visible");
		}
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];

	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);

	if (kv != null)kv.Close();

	kv = new KeyValues("CountryFlags");
	kv.ImportFromFile(m_cFilePath);

	if (!kv.GotoFirstSubKey()) return;

	do
	{
		Format(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/xp/level%i.png", kv.GetNum("index"));
		AddFileToDownloadsTable(sBuffer);

	} while (kv.GotoNextKey());

	kv.Rewind();
}

public void OnClientCookiesCached(int client)
{
	char sCookieValue[12];
	GetClientCookie(client, hShowFlagCookie, sCookieValue, sizeof(sCookieValue));
	if (StrEqual(sCookieValue, ""))
	{
		sCookieValue = "1"
		SetClientCookie(client, hShowFlagCookie, sCookieValue);
	}
	int cookieValue = StringToInt(sCookieValue);
	if (cookieValue == 0)
	{
		g_hShowflag[client] = true;
		OnClientPostAdminCheck(client);
	}
	return;
}

public void OnThinkPost(int m_iEntity)
{
	int m_iLevelTemp[MAXPLAYERS+1] = {0, ...};
	GetEntDataArray(m_iEntity, m_iOffset, m_iLevelTemp, sizeof(m_iLevelTemp));

	for(int i = 1; i <= MaxClients; i++)
	{
		if(m_iLevel[i] != -1)
		{
			if(m_iLevel[i] != m_iLevelTemp[i])
			{
				if (g_bCustomLevels && SCL_GetLevel(i) > 0)continue; // dont overwritte other custom level

				SetEntData(m_iEntity, m_iOffset + (i * 4), m_iLevel[i]);
			}
		}
	}
}

stock bool IsLocalAddress(const char ip[16])
{
	// 192.168.0.0 - 192.168.255.255 (65,536 IP addresses)
	// 10.0.0.0 - 10.255.255.255 (16,777,216 IP addresses)
	if(StrContains(ip, "192.168", false) == 0 || StrContains(ip, "10.", false) == 0)
	{
		return true;
	}

	// 172.16.0.0 - 172.31.255.255 (1,048,576 IP addresses)
	char octets[4][3];
	if(ExplodeString(ip, ".", octets, 4, 3) == 4)
	{
		if(StrContains(octets[0], "172", false) == 0)
		{
			int octet = StringToInt(octets[1]);

			return (!(octet < 16) || !(octet > 31));
		}
	}

	return false;
}
