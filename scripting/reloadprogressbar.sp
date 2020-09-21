#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

#pragma newdecls required

#if !defined SPPP_COMPILER
	#define decl static
#endif

public Plugin myinfo = 
{
	name = "Reload Progress Bar (Fork)",
	author = "xstage && Grey83 (Fork by Wend4r)",
	version	= "1.0"
};

int           m_hActiveWeapon = -1,
              m_flSimulationTime = -1,
              m_flProgressBarStartTime = -1,
              m_iProgressBarDuration = -1,
              m_iBlockingUseActionInProgress = -1;

Handle        g_hTimer[MAXPLAYERS + 1];

EngineVersion g_iEngine;

public void OnPluginStart()
{
	m_hActiveWeapon = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	m_flProgressBarStartTime = FindSendPropInfo("CCSPlayer", "m_flProgressBarStartTime");
	m_iProgressBarDuration = FindSendPropInfo("CCSPlayer", "m_iProgressBarDuration");

	if((g_iEngine = GetEngineVersion()) == Engine_CSGO)
	{
		m_flSimulationTime = FindSendPropInfo("CBaseEntity", "m_flSimulationTime");
		m_iBlockingUseActionInProgress = FindSendPropInfo("CCSPlayer", "m_iBlockingUseActionInProgress");
	}

	HookEvent("weapon_reload", OnWeaponReload);
}

void OnWeaponReload(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if(iClient && !IsFakeClient(iClient))
	{
		SDKHook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);

		int iActiveWeapon = GetEntDataEnt2(iClient, m_hActiveWeapon);

		if(iActiveWeapon != -1)
		{
			static int m_flNextPrimaryAttack = -1;

			if(m_flNextPrimaryAttack == -1)
			{
				m_flNextPrimaryAttack = FindDataMapInfo(iActiveWeapon, "m_flNextPrimaryAttack");
			}

			float flProgressBarTime = GetEntDataFloat(iActiveWeapon, m_flNextPrimaryAttack) - GetGameTime();

			SetProgressBarFloat(iClient, flProgressBarTime);

			g_hTimer[iClient] = CreateTimer(flProgressBarTime, OnResetProgress, GetClientUserId(iClient));
		}
	}
}

Action OnResetProgress(Handle hTimer, int iClient)
{
	if((iClient = GetClientOfUserId(iClient)) && IsClientInGame(iClient) /* When disconnecting it can have an index */)
	{
		SDKUnhook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);

		ResetProgressBar(iClient);
	}
}

void OnPlayerWeaponSwitch(int iClient, int iWeapon)
{
	SDKUnhook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);

	ResetProgressBar(iClient);

	if(g_hTimer[iClient] != INVALID_HANDLE)
	{
		KillTimer(g_hTimer[iClient]);
		g_hTimer[iClient] = INVALID_HANDLE;
	}
}

void SetProgressBarFloat(int iClient, float flProgressTime)
{
	int   iProgressTime = RoundToCeil(flProgressTime);

	float flGameTime = GetGameTime();

	SetEntData(iClient, m_iProgressBarDuration, iProgressTime, 4, true);
	SetEntDataFloat(iClient, m_flProgressBarStartTime, flGameTime - (float(iProgressTime) - flProgressTime), true);

	if(g_iEngine == Engine_CSGO)
	{
		SetEntDataFloat(iClient, m_flSimulationTime, flGameTime + flProgressTime, true);
		SetEntData(iClient, m_iBlockingUseActionInProgress, 0, 4, true);
		// SetEntData(iClient, m_iBlockingUseActionInProgress, GetRandomInt(0, 15), 4, true);		// Hmmm...
	}
}

void ResetProgressBar(int iClient)
{
	SetEntDataFloat(iClient, m_flProgressBarStartTime, 0.0, true);
	SetEntData(iClient, m_iProgressBarDuration, 0, 1, true);
}