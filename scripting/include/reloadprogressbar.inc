#if defined _reloadprogressbar_included
	#endinput
#endif
#define _reloadprogressbar_included

/**
 * Called before displaying ProgressBar 
 * when the player wants to reload the weapon.
 * 
 * @param iClient             Client index.
 * @param iWeapon             Weapon entity index, that wants to reload.
 * @param flProgressBarTime   What time will be set for ProgressBar.
 *                            Return Plugin_Changed for apply changes.
 * 
 * @return                    Return Plugin_Continue to ignore actions.
 *                            Plugin_Changed if result was changed.
 *                            Plugin_Handled to block displaying ProgressBar.
 */
forward Action OnWeaponReloadProgressBar(int iClient, int iWeapon, float &flProgressBarTime);

/**
 * Called after displayed ProgressBar 
 * when the player wants to reload the weapon.
 * 
 * @param iClient             Client index.
 * @param iWeapon             Weapon entity index, that wants to reload.
 * @param flProgressBarTime   What time was set for ProgressBar.
 * 
 * @noreturn
 */
forward void OnWeaponReloadProgressBarPost(int iClient, int iWeapon, float flProgressBarTime);

/**
 * Called when the ProgressBar has expired.
 * 
 * @param iClient             Client index.
 * 
 * @noreturn
 */
forward void OnWeaponReloadProgressBarEnd(int iClient);



public SharedPlugin __pl_reloadprogressbar = 
{
	name = "reloadprogressbar",
	file = "reloadprogressbar.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};