#include <sourcemod>
#include <clientprefs>
#include <reloadprogressbar>

#if !defined SPPP_COMPILER
	#define decl static
#endif

bool   g_bReloadStatus[MAXPLAYERS+1];

Cookie g_hCookieStatus;

public Plugin myinfo =
{
	author = "[Reload Progress Bar] Command",
	name = "Wend4r",
	version = "1.1"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_rbp", OnToggleCommand);

	g_hCookieStatus = new Cookie("Reload Progress Bar", NULL_STRING, CookieAccess_Protected);

	LoadTranslations("rpb_command.phrases");
}

public void OnClientCookiesCached(int iClient)
{
	char sValue[2];

	GetClientCookie(iClient, g_hCookieStatus, sValue, sizeof(sValue));

	g_bReloadStatus[iClient] = sValue[0] != '0';
}

Action OnToggleCommand(int iClient, int iArgs)
{
	int iTime = GetTime();

	static int iTimeout[MAXPLAYERS + 1];

	if(iTimeout[iClient] < iTime)
	{
		PrintToChat(iClient, "%T", "ToggleProgressBar", iClient, (g_bReloadStatus[iClient] ^= true) ? "TurnOn" : "TurnOff", iClient);

		char sValue[2];

		sValue[0] = '0' + view_as<int>(g_bReloadStatus[iClient]);

		SetClientCookie(iClient, g_hCookieStatus, sValue);

		iTimeout[iClient] = iTime;
	}

	return Plugin_Handled;
}

public Action OnWeaponReloadProgressBar(int iClient, int iWeapon, float &flProgressBarTime)
{
	return g_bReloadStatus[iClient] ? Plugin_Continue : Plugin_Handled;
}