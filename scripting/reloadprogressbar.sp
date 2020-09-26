#pragma semicolon 1

#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>

#pragma newdecls required

#if !defined SPPP_COMPILER
	#define decl static
#endif

public Plugin myinfo = 
{
	name = "Reload Progress Bar (Fork)",
	author = "xstage (Fork by Wend4r)",
	version	= "1.0"
};

int           m_hOwnerEntity = -1,
              m_flSimulationTime = -1,
              m_hActiveWeapon = -1,
              m_flProgressBarStartTime = -1,
              m_iProgressBarDuration = -1,
              m_iBlockingUseActionInProgress = -1,
              m_flNextPrimaryAttack = -1,
              m_flTimeWeaponIdle = -1,
              m_reloadState = -1;

// Elimination of the timer time error with ProgressBar synchronization.
const float   g_flSourcemodTimerInterval = 0.07;

GlobalForward g_hWeaponReloadForward,
              g_hWeaponReloadPostForward,
              g_hWeaponReloadEndForward;

EngineVersion g_iEngine;

Handle        g_hTimer[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrorSize)
{
	if((g_iEngine = GetEngineVersion()) != Engine_CSGO && g_iEngine != Engine_CSS && g_iEngine != Engine_SourceSDK2006)
	{
		strcopy(sError, iErrorSize, "This plugin works only on CS:GO, CS:S OB and CS:S v34");

		return APLRes_SilentFailure;
	}
	
	g_hWeaponReloadForward = new GlobalForward("OnWeaponReloadProgressBar", ET_Hook /* Action */, Param_Cell /* int iClient */, Param_Cell /* int iWeapon */, Param_FloatByRef /* float &flProgressBarTime */);
	g_hWeaponReloadPostForward = new GlobalForward("OnWeaponReloadProgressBarPost", ET_Ignore /* void */, Param_Cell /* int iClient */, Param_Cell /* int iWeapon */, Param_Float /* float flProgressBarTime */);
	g_hWeaponReloadEndForward = new GlobalForward("OnWeaponReloadProgressBarEnd", ET_Ignore /* void */, Param_Cell /* int iClient */);

	RegPluginLibrary("reloadprogressbar");

	return APLRes_Success;
}

public void OnPluginStart()
{
	m_hOwnerEntity = FindSendPropInfo("CBaseEntity", "m_hOwnerEntity");
	m_hActiveWeapon = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	m_flProgressBarStartTime = FindSendPropInfo("CCSPlayer", "m_flProgressBarStartTime");
	m_iProgressBarDuration = FindSendPropInfo("CCSPlayer", "m_iProgressBarDuration");
	m_flNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");
	m_flTimeWeaponIdle = FindSendPropInfo("CBaseCombatWeapon", "m_flTimeWeaponIdle");

	if((g_iEngine = GetEngineVersion()) == Engine_CSGO)
	{
		m_flSimulationTime = FindSendPropInfo("CBaseEntity", "m_flSimulationTime");
		m_iBlockingUseActionInProgress = FindSendPropInfo("CCSPlayer", "m_iBlockingUseActionInProgress");
	}

	int iEntity = -1;

	while((iEntity = FindEntityByClassname(iEntity, "weapon_*")) != -1)
	{
		SDKHook(iEntity, SDKHook_ReloadPost, OnWeaponReloadPost);
	}
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(!strncmp(sClassname, "weapon_", 7))
	{
		SDKHook(iEntity, SDKHook_ReloadPost, OnWeaponReloadPost);
	}
}

void OnWeaponReloadPost(int iWeapon, bool bSuccessful)
{
	if(bSuccessful)
	{
		int iClient = GetEntDataEnt2(iWeapon, m_hOwnerEntity);

		if(iClient != -1 && !g_hTimer[iClient])
		{
			bool bIsShotgun = IsShotgun(iWeapon);

			float flReloadSuccessfulTime = GetEntDataFloat(iWeapon, m_flNextPrimaryAttack);

			if(bIsShotgun)
			{
				flReloadSuccessfulTime += GetEntDataFloat(iWeapon, m_flTimeWeaponIdle) - GetGameTime();
			}

			StartReloadProgressBar(iClient, iWeapon, flReloadSuccessfulTime, bIsShotgun);
		}
	}
}

void StartReloadProgressBar(int iClient, int iWeapon, float flReloadSuccessfulTime, bool IsShotgun)
{
	float flProgressBarTime = 0.0;

	Action iResult = Plugin_Continue;

	Call_StartForward(g_hWeaponReloadForward);
	Call_PushCell(iClient);
	Call_PushCell(iWeapon);
	Call_PushFloatRef(flProgressBarTime);
	Call_Finish(iResult);

	if(iResult != Plugin_Handled && iResult != Plugin_Stop)
	{
		SDKHook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);

		if(iResult != Plugin_Changed)
		{
			float flGameTime = GetGameTime();

			if(!IsShotgun)
			{
				flGameTime += g_flSourcemodTimerInterval;
			}

			flProgressBarTime = flReloadSuccessfulTime - flGameTime;
		}

		if(flProgressBarTime > 0.0)
		{
			SetProgressBarFloat(iClient, flProgressBarTime);

			g_hTimer[iClient] = CreateTimer(flProgressBarTime + g_flSourcemodTimerInterval, IsShotgun ? OnShotgunPokeTimer : OnResetProgressTimer, GetClientUserId(iClient));

			Call_StartForward(g_hWeaponReloadPostForward);
			Call_PushCell(iClient);
			Call_PushCell(iWeapon);
			Call_PushFloat(flProgressBarTime);
			Call_Finish();
		}
		else
		{
			ResetProgressBar(iClient);
		}
	}
}

bool IsShotgun(int iEntity)
{
	decl char sNetCalss[64];

	if(GetEntityNetClass(iEntity, sNetCalss, sizeof(sNetCalss)))
	{
		int m_reloadStateOffset = FindSendPropInfo(sNetCalss, "m_reloadState");

		if(m_reloadStateOffset != -1)
		{
			m_reloadState = m_reloadStateOffset;

			return true;
		}
	}

	return false;
}

Action OnShotgunPokeTimer(Handle hTimer, int iClient)
{
	if(IsClientUserIDToIndex(iClient))
	{
		g_hTimer[iClient] = null;

		SDKUnhook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);

		int iWeapon = GetEntDataEnt2(iClient, m_hActiveWeapon);

		if(iWeapon != -1)
		{
			if(GetEntData(iWeapon, m_reloadState, 1))
			{
				StartReloadProgressBar(iClient, iWeapon, GetEntDataFloat(iWeapon, m_flTimeWeaponIdle), true);
			}
			else
			{
				ResetProgressBar(iClient);
			}
		}
	}
}

Action OnResetProgressTimer(Handle hTimer, int iClient)
{
	if(IsClientUserIDToIndex(iClient))
	{
		SDKUnhook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);

		ResetProgressBar(iClient);

		Call_StartForward(g_hWeaponReloadEndForward);
		Call_PushCell(iClient);
		Call_Finish();
	}

	g_hTimer[iClient] = null;
}

bool IsClientUserIDToIndex(int &iClient)
{
	return (iClient = GetClientOfUserId(iClient)) && IsClientInGame(iClient) /* When disconnecting it can have an index */;
}

void OnPlayerWeaponSwitch(int iClient, int iWeapon)
{
	SDKUnhook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);

	ResetProgressBar(iClient);

	if(g_hTimer[iClient])
	{
		KillTimer(g_hTimer[iClient]);
		g_hTimer[iClient] = null;
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