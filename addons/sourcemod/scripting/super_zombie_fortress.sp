/*
             << Super Zombie Fortress >>
                     < Redux >

       Original Author of Zombie Fortress, Sirot
 https://forums.alliedmods.net/showthread.php?p=688433

                Recoded by dirtyminuth
 https://forums.alliedmods.net/showthread.php?p=1227078

            Updated again by Mecha the Slag
 https://forums.alliedmods.net/showthread.php?p=1467101

                Revamped by Batfoxkid

*/

#pragma semicolon 1

//
// Includes
//
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <tf2_stocks>
#include <morecolors>
#include <tf2items>
#include <tf2attributes>
//#include <super_zombie_fortress>
#tryinclude <tf2idb>
#if SOURCEMOD_V_MAJOR==1 && SOURCEMOD_V_MINOR<=9
#tryinclude <steamtools>
#endif

#include "szf_util_base.inc"
#include "szf_util_pref.inc"

#pragma newdecls required

//
// Plugin Information
//
#define MAJOR_REVISION "Alpha"
#define MINOR_REVISION "0"
#define STABLE_REVISION "0"
#define DEV_REVISION "Build"
#if !defined DEV_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION
#else
	#define PLUGIN_VERSION DEV_REVISION..."-"...BUILD_NUMBER
#endif

#define BUILD_NUMBER MINOR_REVISION...STABLE_REVISION..."049"

#define debugmode true

#if defined _steamtools_included
bool steamtools = false;
#endif

// File paths
#define ConfigPath "configs/super_zombie_fortress"
#define DataPath "data/super_zombie_fortress"
#define WeaponCFG "weapons.cfg"

public Plugin myinfo = 
{
	name		=	"Super Zombie Fortress Redux",
	author		=	"Many many people",
	description	=	"Pits a team of survivors aganist an endless onslaught of zombies.",
	version		=	PLUGIN_VERSION,
};

#define PLAYERBUILTOBJECT_ID_DISPENSER	0
#define PLAYERBUILTOBJECT_ID_TELENT	1
#define PLAYERBUILTOBJECT_ID_TELEXIT	2
#define PLAYERBUILTOBJECT_ID_SENTRY	3

#define GOO_INCREASE_RATE	3

#define SOUND_BONUS	"ui/trade_ready.wav"

int OtherTeam=2;
int ZomTeam=3;
int Enabled;
bool LastMan=true;
int MapType=0;
int RedAlivePlayers=0;
int BlueAlivePlayers=0;
int RedDeadPlayers=0;
int BlueDeadPlayers=0;

float GlowTimer[MAXPLAYERS+1];

//
// State
//

// Global State
int zf_bNewRound;
int zf_spawnSurvivorsKilledCounter;
int zf_spawnZombiesKilledCounter;
// Client State
int szf_critBonus[MAXPLAYERS+1];
int zf_hoardeBonus[MAXPLAYERS+1];
int zf_rageTimer[MAXPLAYERS+1];

// Global Timer Handles
Handle szf_tMain;
Handle szf_tMainFast;
Handle szf_tMainSlow;
Handle szf_tHoarde;
Handle szf_tDataCollect;// Cvar Handles
Handle kvWeaponMods=INVALID_HANDLE;
Handle GameConfig;
Handle WearableEquip;

ConVar cvarForceOn;
ConVar cvarRatio;
ConVar cvarAllowTeamPref;
ConVar cvarSwapOnPayload;
ConVar cvarSwapOnAttdef;
ConVar cvarTankHealth;
ConVar cvarTankHealthMin;
ConVar cvarTankHealthMax;
ConVar cvarTankTime;
ConVar cvarFrenzyChance;
ConVar cvarFrenzyTankChance;
ConVar cvarRemoveWeapon;
ConVar cvarTankOnce;
ConVar cvarExtraClass;

float g_fZombieDamageScale = 1.0;

int g_StartTime = 0;
int g_AdditionalTime = 0;

// Sound system
Handle g_hMusicArray = INVALID_HANDLE;
Handle g_hFastRespawnArray = INVALID_HANDLE;

bool g_bBackstabbed[MAXPLAYERS+1] = false;
Handle g_hBonus[MAXPLAYERS+1] = INVALID_HANDLE;
Handle g_hBonusTimers[MAXPLAYERS+1] = INVALID_HANDLE;
int g_iBonusCombo[MAXPLAYERS+1] = 0;
int g_iHitBonusCombo[MAXPLAYERS+1] = 0;
bool g_bBonusAlt[MAXPLAYERS+1] = false;
float g_fDamageTakenLife[MAXPLAYERS+1] = 0.0;
float g_fDamageDealtLife[MAXPLAYERS+1] = 0.0;
bool g_bRoundActive = false;

int g_iControlPointsInfo[20][2];
int g_iControlPoints = 0;
bool g_bCapturingLastPoint = false;
int g_iCarryingItem[MAXPLAYERS+1] = -1;
bool stripMap = false;

#define GAMEMODE_DEFAULT	0
#define GAMEMODE_NEW		1
int g_iMode = GAMEMODE_DEFAULT;

#define MUSIC_DRUMS		0
#define MUSIC_SLAYER_MILD	1
#define MUSIC_SLAYER		2
#define MUSIC_TRUMPET		3
#define MUSIC_SNARE		4
#define MUSIC_BANJO		5
#define MUSIC_HEART_SLOW	6
#define MUSIC_HEART_MEDIUM	7
#define MUSIC_HEART_FAST	8
#define MUSIC_RABIES		9
#define MUSIC_DEAD		10
#define MUSIC_INCOMING		11
#define MUSIC_PREPARE		12
#define MUSIC_DROWN		13
#define MUSIC_TANK		14
#define MUSIC_LASTSTAND		15
#define MUSIC_NEARDEATH		16
#define MUSIC_NEARDEATH2	17
#define MUSIC_AWARD		18
#define MUSIC_LASTTENSECONDS	19
#define MUSIC_ROUNDWIN		20
#define MUSIC_ROUNDLOSE		21
#define MUSIC_MAX		22

#define MUSIC_NONE			0
#define MUSIC_INTENSE			1
#define MUSIC_MILD			2
#define MUSIC_VERYMILD3			3
#define MUSIC_VERYMILD2			4
#define MUSIC_VERYMILD1			5
#define MUSIC_GOO			6
#define MUSIC_TANKMOOD			7
#define MUSIC_LASTSTANDMOOD		8
#define MUSIC_PLAYERNEARDEATH		9
#define MUSIC_LASTTENSECONDSMOOD	10

#define CHANNEL_MUSIC_NONE	0
#define CHANNEL_MUSIC_DRUMS	350
#define CHANNEL_MUSIC_SLAYER	351
#define CHANNEL_MUSIC_SINGLE	352

#define DISTANCE_GOO	6.0
#define TIME_GOO	6.0

#define INFECTED_NONE	0
#define INFECTED_COMMON	1
#define INFECTED_RARE	2
#define INFECTED_TANK	3
#define INFECTED_BOSS	4

enum TFClassWeapon
{
	TFClassWeapon_Unknown = 0,
	TFClassWeapon_Scout,
	TFClassWeapon_Sniper,
	TFClassWeapon_Soldier,
	TFClassWeapon_DemoMan,
	TFClassWeapon_Medic,
	TFClassWeapon_Heavy,
	TFClassWeapon_Pyro,
	TFClassWeapon_Spy,
	TFClassWeapon_Engineer,
	TFClassWeapon_Group_Shotgun
};


int g_iMusicCount[MUSIC_MAX] = 0;
char g_strMusicLast[MAXPLAYERS+1][MUSIC_MAX][PLATFORM_MAX_PATH];
int g_iMusicLevel[MAXPLAYERS+1] = 0;
Handle g_hMusicTimer[MAXPLAYERS+1] = INVALID_HANDLE;
int g_iMusicRandom[MAXPLAYERS+1][2];
int g_iMusicFull[MAXPLAYERS+1] = 0;
Handle g_hGoo = INVALID_HANDLE;

bool g_bZombieRage = false;
int g_iZombieTank = 0;
bool g_bZombieRageAllowRespawn = false;
int g_iGooId = 0;
int g_iGooMultiplier[MAXPLAYERS+1] = 0;
bool g_bGooified[MAXPLAYERS+1] = false;
bool g_bHitOnce[MAXPLAYERS+1] = false;

int g_iSpecialInfected[MAXPLAYERS+1] = 0;
int g_iDamage[MAXPLAYERS+1] = 0;
int g_iKillsThisLife[MAXPLAYERS+1] = 0;
int g_iSuperHealthSubtract[MAXPLAYERS+1] = 0;
int g_iStartSurvivors = 0;

bool g_bTankOnce = false;

char g_strSoundFleshHit[][128] =
{
	"physics/flesh/flesh_impact_bullet1.wav",
	"physics/flesh/flesh_impact_bullet2.wav",
	"physics/flesh/flesh_impact_bullet3.wav",
	"physics/flesh/flesh_impact_bullet4.wav",
	"physics/flesh/flesh_impact_bullet5.wav"
};

char g_strSoundCritHit[][128] =
{
	"player/crit_received1.wav",
	"player/crit_received2.wav",
	"player/crit_received3.wav"
};

char g_weaponModels[][128] =
{
	//"models/weapons/c_models/c_dartgun.mdl",
	"models/weapons/c_models/c_dex_sniperrifle/c_dex_sniperrifle.mdl",	//
	"models/weapons/c_models/urinejar.mdl",	//
	"models/weapons/c_models/c_bow/c_bow.mdl",	//
	"models/weapons/c_models/c_leechgun/c_leechgun.mdl",	// ?
	"models/weapons/c_models/c_crusaders_crossbow/c_crusaders_crossbow.mdl",	//
	"models/weapons/c_models/c_proto_syringegun/c_proto_syringegun.mdl",	//
	"models/weapons/c_models/c_proto_medigun/c_proto_medigun.mdl",	//
	"models/weapons/c_models/c_drg_manmelter/c_drg_manmelter.mdl",	//
	"models/weapons/c_models/c_flamethrower/c_flamethrower.mdl",	//
	"models/weapons/c_models/c_drg_phlogistinator/c_drg_phlogistinator.mdl",	//
	"models/weapons/c_models/c_shogun_warhorn/c_shogun_warhorn.mdl",	//
	"models/weapons/c_models/c_syringegun/c_syringegun.mdl",	//
	"models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl",	//
	"models/weapons/c_models/c_bet_rocketlauncher/c_bet_rocketlauncher.mdl",	// ?
	"models/weapons/c_models/c_directhit/c_directhit.mdl",	//
	"models/weapons/c_models/c_blackbox/c_blackbox.mdl",	//
	"models/weapons/c_models/c_shotgun/c_shotgun.mdl",	//
	"models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl",	//
	"models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl",	//
	"models/weapons/c_models/c_bugle/c_bugle.mdl",	// ?
	"models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl",	//
	"models/weapons/c_models/c_detonator/c_detonator.mdl",	//
	"models/weapons/c_models/c_degreaser/c_degreaser.mdl",	//
	"models/weapons/c_models/c_liberty_launcher/c_liberty_launcher.mdl",	//
	"models/weapons/c_models/c_lochnload/c_lochnload.mdl",	//
	"models/weapons/c_models/c_sticky_jumper/c_sticky_jumper.mdl",	// ?
	"models/weapons/c_models/c_scottish_resistance.mdl",	//
	"models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl",	// ?
	"models/weapons/c_models/c_medigun/c_medigun.mdl",	// ?
	"models/weapons/c_models/c_syringegun/c_syringegun.mdl",	//
	"models/weapons/c_models/c_bazaar_sniper/c_bazaar_sniper.mdl",	//
	"models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl",	//
	"models/weapons/c_models/c_ttg_max_gun/c_ttg_max_gun.mdl",	//
	"models/weapons/c_models/c_pistol/c_pistol.mdl",	//
	"models/weapons/c_models/c_wrangler.mdl"	//
};

////////////////////////////////////////////////////////////
//
// Sourcemod Callbacks
//
////////////////////////////////////////////////////////////
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	#if defined _steamtools_included
	MarkNativeAsOptional("Steam_SetGameDescription");
	#endif
	
	return APLRes_Success;

}

public void OnPluginStart()
{
	// Check for necessary extensions
	if(GetExtensionFileStatus("sdkhooks.ext") < 1)
		SetFailState("SDK Hooks is not loaded.");

	LoadTranslations("super_zombie_fortress.phrases");	

	// Initialize global state
	Enabled = false;
	zf_bNewRound = true;
	setRoundState(RoundInit1);
			
	// Initialize timer handles
	szf_tMain = INVALID_HANDLE;
	szf_tMainSlow = INVALID_HANDLE;
	szf_tMainFast = INVALID_HANDLE;
	szf_tHoarde = INVALID_HANDLE;
	
	// Initialize other packages
	utilBaseInit();
	utilPrefInit();
	
	// Register cvars
	CreateConVar("szf_version", PLUGIN_VERSION, "Current Zombie Fortress Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY); 
	cvarForceOn = CreateConVar("szf_force_on", "1", "<0/1> Activate ZF for non-ZF maps.", _, true, 0.0, true, 1.0);
	cvarRatio = CreateConVar("szf_ratio", "0.8", "<0.01-1.00> Percentage of players that start as survivors.", _, true, 0.01, true, 1.0);
	cvarAllowTeamPref = CreateConVar("szf_allowteampref", "0", "<0/1> Allow use of team preference criteria.", _, true, 0.0, true, 1.0);
	cvarSwapOnPayload = CreateConVar("szf_swaponpayload", "1", "<0/1> Swap teams on non-ZF payload maps.", _, true, 0.0, true, 1.0);
	cvarSwapOnAttdef = CreateConVar("szf_swaponattdef", "1", "<0/1> Swap teams on non-ZF attack/defend maps.", _, true, 0.0, true, 1.0);
	cvarTankHealth = CreateConVar("sszf_tank_health", "400", "Amount of health the Tank gets per alive survivor", _, true, 10.0);
	cvarTankHealthMin = CreateConVar("sszf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with", _, true, 0.0);
	cvarTankHealthMax = CreateConVar("sszf_tank_health_max", "8000", "Maximum amount of health the Tank can spawn with", _, true, 0.0);
	cvarTankTime = CreateConVar("szf_tank_time", "50.0", "Adjusts the damage the Tank takes per second. If the value is 70.0, the Tank will take damage that will make him die (if unhurt by survivors) after 70 seconds. 0 to disable.", _, true, 0.0);
	cvarFrenzyChance = CreateConVar("szf_frenzy_chance", "5.0", "% Chance of a random frenzy", _, true, 0.0);
	cvarFrenzyTankChance = CreateConVar("szf_frenzy_tank", "25.0", "% Chance of a Tank appearing instead of a frenzy", _, true, 0.0);
	cvarRemoveWeapon = CreateConVar("szf_pickup_remove", "1", "0-Leave weapon, 1-Remove weapon once picked up", _, true, 0.0, true, 1.0);
	cvarTankOnce = CreateConVar("szf_tank_once", "60.0", "Every round there is at least one Tank. If no Tank has appeared, a Tank will be manually created when there is sm_szf_tank_once time left. Ie. if the value is 60, the Tank will be spawned when there's 60% of the time left.", _, true, 0.0);
	cvarExtraClass = CreateConVar("szf_pickup_more", "1", "0-Use TF2 logic, 1-Allow logic like Engineers and Reserve Shooter", _, true, 0.0, true, 1.0);

	// Hook events
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_setup_finished", OnSetupEnd);
	HookEvent("teamplay_round_win", OnRoundEnd);
	HookEvent("teamplay_timer_time_added", OnTimeAdded);
	HookEvent("teamplay_broadcast_audio", OnBroadcast, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn);	
	HookEvent("player_death", OnPlayerDeath);
	//HookEvent("post_inventory_application", OnPlayerInventory);
	
	//HookEvent("player_builtobject", OnPlayerBuiltObject); 
	HookEvent("teamplay_point_captured", OnCPCapture); 
	HookEvent("teamplay_point_startcapture", OnCPCaptureStart); 

	// Register Admin Commands
	RegAdminCmd("szf_enable", command_zfEnable, ADMFLAG_RCON, "Activates the Zombie Fortress plugin.");
	RegAdminCmd("szf_disable", command_zfDisable, ADMFLAG_RCON, "Deactivates the Zombie Fortress plugin.");
	RegAdminCmd("szf_swapteams", command_zfSwapTeams, ADMFLAG_RCON, "Swaps current team roles.");
	RegAdminCmd("szf_rabies", command_rabies, ADMFLAG_CHEATS, "Rabies.");
	RegAdminCmd("szf_goo", command_goo, ADMFLAG_CHEATS, "Goo!");
	RegAdminCmd("szf_tank", command_tank, ADMFLAG_CHEATS, "Become a tank");
	RegAdminCmd("szf_tank_random", command_tank_random, ADMFLAG_CHEATS, "Pick a random tank");
	
	// Hook Client Commands
	AddCommandListener(OnJoinTeam, "jointeam");
	AddCommandListener(OnJoinTeam, "autoteam");
	AddCommandListener(OnChangeClass, "joinclass");
	AddCommandListener(OnCallMedic, "voicemenu"); 
	// Hook Client Console Commands	
	//AddCommandListener(CommandTeamPref, "szf_teampref");
	// Hook Client Chat / Console Commands
	RegConsoleCmd("szf", CommandMenu);
	RegConsoleCmd("szf_menu", CommandMenu);
	RegConsoleCmd("szf_pref", CommandTeamPref);
	
	CreateTimer(10.0, SpookySound, 0, TIMER_REPEAT);
	
	CheckStartWeapons();

	GameConfig = LoadGameConfigFile("szf_gamedata");

	if(!GameConfig)
	{
		LogError("Failed to find szf_gamedata.txt gamedata!");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(GameConfig, SDKConf_Virtual, "EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	WearableEquip = EndPrepSDKCall();

	if(!WearableEquip)
	{
		LogError("Failed to prepare the SDKCall for giving cosmetics. Try updating gamedata or restarting your server.");
	}

	#if defined _steamtools_included
	steamtools = LibraryExists("SteamTools");
	#endif
}

public void OnLibraryAdded(const char[] name)
{
	#if defined _steamtools_included
	if(!strcmp(name, "SteamTools", false))
	{
		steamtools = true;
	}
	#endif
}

public void OnLibraryRemoved(const char[] name)
{
	#if defined _steamtools_included
	if(!strcmp(name, "SteamTools", false))
	{
		steamtools = false;
	}
	#endif
}

public void OnConfigsExecuted()
{
	// Determine whether to enable ZF.
	// + For "zf_" prefixed maps, enable ZF.
	// + For non-"zf_" prefixed maps, disable ZF unless sm_zf_force_on is set.
	if(mapIsZF())
	{
		zfEnable();
	}
	else
	{
		GetConVarBool(cvarForceOn) ? zfEnable() : zfDisable();
	} 

	setRoundState(RoundInit1);
}	

public void OnMapEnd()
{
	// Close timer handles
	if(szf_tMain != INVALID_HANDLE)
	{			
		CloseHandle(szf_tMain);
		szf_tMain = INVALID_HANDLE;
	}
	if(szf_tMainSlow != INVALID_HANDLE)
	{
		CloseHandle(szf_tMainSlow);
		szf_tMainSlow = INVALID_HANDLE;
	}
	
	if(szf_tMainFast != INVALID_HANDLE)
	{
		CloseHandle(szf_tMainFast);
		szf_tMainFast = INVALID_HANDLE;
	}
	if(szf_tHoarde != INVALID_HANDLE)
	{
		CloseHandle(szf_tHoarde);
		szf_tHoarde = INVALID_HANDLE;		
	}
	setRoundState(RoundPost);
	g_bRoundActive = false;
}
	
public void OnClientPostAdminCheck(int client)
{
	if(!Enabled)
		return;
	
	CreateTimer(10.0, timer_initialHelp, client, TIMER_FLAG_NO_MAPCHANGE);
	
	SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	g_iDamage[client] = GetAverageDamage();
	
	pref_OnClientConnect(client);
}

public void OnClientDisconnect(int client)
{
	if(!Enabled)
		return;

	pref_OnClientDisconnect(client);
	StopSoundSystem(client);
	DropCarryingItem(client);
	if(client == g_iZombieTank)
		g_iZombieTank = 0;
}

////////////////////////////////////////////////////////////
//
// SDKHooks Callbacks
//
////////////////////////////////////////////////////////////
public void OnPreThinkPost(int client)
{	
	if(!Enabled)
		return;

	UpdateClientCarrying(client);
}

#define DMGTYPE_MELEE		134221952
#define DMGTYPE_MELEE_CRIT	135270528

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflicter, float &fDamage, int &iDamagetype, int &iWeapon, float fForce[3], float fForcePos[3], int damagecustom)
{
	if(!Enabled)
		return Plugin_Continue;

	if(!CanRecieveDamage(iVictim))
		return Plugin_Continue;
	
	bool bChanged = false;
	if(validClient(iVictim) && validClient(iAttacker))
	{
		g_bHitOnce[iVictim] = true;
		g_bHitOnce[iAttacker] = true;
		if(GetClientTeam(iVictim) != GetClientTeam(iAttacker))
		{
			EndGracePeriod();
		}
	}

	if(iVictim != iAttacker)
	{
		/*if(validSur(iAttacker) && validZom(iVictim))
		{
			if(RedAlivePlayers==1)
			{
				fDamage *= (BlueAlivePlayers+BlueDeadPlayers+4)/8.0;
			}
			else
			{
				fDamage *= (BlueAlivePlayers+BlueDeadPlayers+4)/(RedAlivePlayers+6);
			}
			return Plugin_Changed;
		}*/
		if(validZom(iAttacker) && validSur(iVictim) && fDamage > 0.0)
		{
			int iDamage = RoundFloat(fDamage);
			if(iDamage > 300)
				iDamage = 300;

			g_iDamage[iAttacker] += iDamage;
			int iPitch = g_iHitBonusCombo[iAttacker] * 10 + 50;
			if(iPitch > 250)
				iPitch = 250;

			EmitSoundToClient(iAttacker, SOUND_BONUS, _, _, SNDLEVEL_ROCKET, SND_CHANGEPITCH, _, iPitch);
			EmitSoundToClient(iAttacker, SOUND_BONUS, _, _, SNDLEVEL_ROCKET, SND_CHANGEPITCH, _, iPitch);
			EmitSoundToClient(iAttacker, SOUND_BONUS, _, _, SNDLEVEL_ROCKET, SND_CHANGEPITCH, _, iPitch);
			EmitSoundToClient(iAttacker, SOUND_BONUS, _, _, SNDLEVEL_ROCKET, SND_CHANGEPITCH, _, iPitch);
			EmitSoundToClient(iAttacker, SOUND_BONUS, _, _, SNDLEVEL_ROCKET, SND_CHANGEPITCH, _, iPitch);
			EmitSoundToClient(iAttacker, SOUND_BONUS, _, _, SNDLEVEL_ROCKET, SND_CHANGEPITCH, _, iPitch);
			g_iHitBonusCombo[iAttacker]++;
		}
		if(validClient(iVictim) && validClient(iAttacker) && iAttacker != iVictim)
		{
			g_fDamageTakenLife[iVictim] += fDamage;
			g_fDamageDealtLife[iAttacker] += fDamage;
		}
	}
	if(bChanged)
		return Plugin_Changed;

	return Plugin_Continue;
}

public Action Timer_CheckAlivePlayers(Handle timer)
{
	if(roundState()!=RoundActive)
		return Plugin_Continue;

	RedAlivePlayers=0;
	BlueAlivePlayers=0;
	RedDeadPlayers=0;
	BlueDeadPlayers=0;
	int LastMann=0;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client))
			{
				if(GetClientTeam(client)==OtherTeam)
				{
					RedAlivePlayers++;
					LastMann=client;
				}
				else if(GetClientTeam(client)==ZomTeam)
				{
					BlueAlivePlayers++;
				}
			}
			else
			{
				if(GetClientTeam(client)==OtherTeam)
				{
					RedDeadPlayers++;
				}
				else if(GetClientTeam(client)==ZomTeam)
				{
					BlueDeadPlayers++;
				}
			}
		}
	}
	if(!RedAlivePlayers)
	{
		ForceTeamWin(ZomTeam);
	}
	else if(RedAlivePlayers==1 && BlueAlivePlayers && GetClientTeam(LastMann)==OtherTeam && LastMan)
	{
		SetEntityHealth(LastMann, 255);
		CPrintToChat(LastMann, "{olive}[SZF]{default} %t", "Last Mann", LastMann);
		MusicHandleClient(LastMann);
		TF2_AddCondition(LastMann, TFCond_Buffed, TFCondDuration_Infinite);
		SetClientGlow(LastMann, 3600.0);
		LastMan=false;
	}
	else if(RedAlivePlayers<5)
	{
		for(int client=1; client<=MaxClients; client++)
		{
			if(IsClientInGame(client) && IsPlayerAlive(client))
			{
				if(GetClientTeam(client)==OtherTeam)
				{
					SetClientGlow(client, 20.0, (120.0/RedAlivePlayers));
					TF2_AddCondition(client, TFCond_SpawnOutline, TFCondDuration_Infinite);
				}
			}
		}
	}
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Admin Console Command Handlers
//
////////////////////////////////////////////////////////////
public Action command_zfEnable(int client, int args)
{
	ServerCommand("mp_restartgame 6");
	CPrintToChatAll("{olive}[SZF]{default} %t", "SZF Enabled");

	if(!Enabled)
		zfEnable();

	return Plugin_Continue;
}

public Action command_zfDisable(int client, int args)
{
	if(!Enabled)
		return Plugin_Continue;

	ServerCommand("mp_restartgame 6");
	CPrintToChatAll("{olive}[SZF]{default} %t", "SZF Disabled");
	zfDisable();

	return Plugin_Continue;
}

public Action command_zfSwapTeams(int client, int args)
{
	if(!Enabled)
		return Plugin_Continue;

	zfSwapTeams();
	ServerCommand("mp_restartgame 6");
	CPrintToChatAll("{olive}[SZF]{default} %t", "Team Swap");

	zf_bNewRound = true;			
	setRoundState(RoundInit2);
			
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Client Console / Chat Command Handlers
//
////////////////////////////////////////////////////////////
public Action OnJoinTeam(int client, const char[] command, int args)
{	
	if(!Enabled || roundState()==RoundActive || roundState()==RoundPost)
	{
		return Plugin_Continue;
	}

	int oldTeam = GetClientTeam(client);
	if(StrEqual(command, "autoteam", false))
	{
		if(oldTeam <= view_as<int>(TFTeam_Spectator))
		{
			ChangeClientTeam(client, ZomTeam);
		}
		return Plugin_Handled;
	}

	if(!args)
	{
		return Plugin_Continue;
	}

	char teamString[10];
	GetCmdArg(1, teamString, sizeof(teamString));
	if(StrEqual(teamString, "spectate", false))
	{
		return Plugin_Continue;
	}
	else if(oldTeam <= view_as<int>(TFTeam_Spectator))
	{
		ChangeClientTeam(client, ZomTeam);
	}
	return Plugin_Handled;
}

public Action OnChangeClass(int client, const char[] command, int args)
{
	char cmd1[32];
	
	if(!Enabled)
		return Plugin_Continue;

	if(args < 1)
		return Plugin_Continue;

	GetCmdArg(1, cmd1, sizeof(cmd1));
	
	if(GetClientTeam(client) == ZomTeam)	 
	{
		// If an invalid zombie class is selected, print a message and
		// accept joinclass command. ZF spawn logic will correct this
		// issue when the player spawns.
		if(!(StrEqual(cmd1, "scout", false) || StrEqual(cmd1, "spy", false) || StrEqual(cmd1, "heavyweapons", false)))
		{
			CPrintToChat(client, "{olive}[SZF]{default} %t", "Zombies Classes");
		}
	}

	else if(GetClientTeam(client) == OtherTeam)
	{
		// Prevent survivors from switching classes during the round.
		if(roundState() == RoundActive)
		{
			CPrintToChat(client, "{olive}[SZF]{default} %t", "Class Change Deny");
			return Plugin_Handled;
		}
		// If an invalid survivor class is selected, print a message
		// and accept the joincalss command. ZF spawn logic will
		// correct this issue when the player spawns.
		else if(!(StrEqual(cmd1, "soldier", false) ||
			  StrEqual(cmd1, "pyro", false) ||
			  StrEqual(cmd1, "demoman", false) ||
			  StrEqual(cmd1, "engineer", false) ||
			  StrEqual(cmd1, "medic", false) ||
			  StrEqual(cmd1, "sniper", false)) && MapType==1)
		{
			CPrintToChat(client, "{olive}[SZF]{default} %t", "Survivor Classes");
		}			 
	}
		
	return Plugin_Continue;
}

public Action OnCallMedic(int client, const char[] command, int argc)
{
	char cmd1[32], cmd2[32];
	
	if(!Enabled)
		return Plugin_Continue;	
	if(argc < 2)
		return Plugin_Handled;
	
	GetCmdArg(1, cmd1, sizeof(cmd1));
	GetCmdArg(2, cmd2, sizeof(cmd2));
	
	// Capture call for medic commands (represented by "voicemenu 0 0").
	// Activate zombie Rage ability (150% health), if possible. Rage 
	// can't be activated below full health or if it's already active.
	// Rage recharges after 30 seconds.
	if(StrEqual(cmd1, "0") && StrEqual(cmd2, "0") && IsPlayerAlive(client))
	{
		if(GetClientTeam(client)==ZomTeam && g_iSpecialInfected[client] == INFECTED_NONE)
		{		
			int curH = GetClientHealth(client);
			int maxH = GetEntProp(client, Prop_Data, "m_iMaxHealth");			 
	
			if((zf_rageTimer[client] == 0) && (curH >= maxH))
			{
				zf_rageTimer[client] = 30;
				
				SetEntityHealth(client, RoundToCeil(maxH * 1.5));
									
				ClientCommand(client, "voicemenu 2 1");
				PrintHintText(client, "%t", "Rage Activated");	
			}
			else
			{
				ClientCommand(client, "voicemenu 2 5");
				PrintHintText(client, "%t", "Can't Activate Rage"); 
			}
					
			return Plugin_Handled;
		}
		else if(GetClientTeam(client) == OtherTeam)
		{
			if(AttemptCarryItem(client))
				return Plugin_Handled;
			else if(AttemptGrabItem(client))
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action CommandTeamPref(int client, int args)
{
	char cmd[32];
	
	if(!Enabled)
		return Plugin_Continue;

	// Get team preference
	if(args == 0)
	{
		if(prefGet(client, TeamPref) == ZF_TEAMPREF_SUR)
			ReplyToCommand(client, "[SZF] %t", "Survivors");
		else if(prefGet(client, TeamPref) == ZF_TEAMPREF_ZOM)
			ReplyToCommand(client, "[SZF] %t", "Zombies");
		else if(prefGet(client, TeamPref) == ZF_TEAMPREF_NONE)
			ReplyToCommand(client, "[SZF] %t", "None");

		return Plugin_Handled;
	}

	GetCmdArg(1, cmd, sizeof(cmd));
	
	// Set team preference
	if(StrEqual(cmd, "sur", false))
	{
		prefSet(client, TeamPref, ZF_TEAMPREF_SUR);
	}
	else if(StrEqual(cmd, "zom", false))
	{
		prefSet(client, TeamPref, ZF_TEAMPREF_ZOM);
	}
	else if(StrEqual(cmd, "no", false))
	{
		prefSet(client, TeamPref, ZF_TEAMPREF_NONE);
	}
	else
	{
		// Error in command format, display usage
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "[SZF] Usage: {1} [sur|zom|none]", cmd);		
	}
	
	return Plugin_Handled;
}

public Action CommandMenu(int client, int args)
{
	if(!Enabled)
		return Plugin_Continue; 
	panel_PrintMain(client);
	
	return Plugin_Handled;		
}

////////////////////////////////////////////////////////////
//
// TF2 Gameplay Event Handlers
//
////////////////////////////////////////////////////////////
public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{	
	if(!Enabled)
		return Plugin_Continue;
				
	// Handle special cases.
	// + Being kritzed overrides other crit calculations.
	if(isKritzed(client))
		return Plugin_Continue;

	// Handle crit bonuses.
	// + Survivors: Crit result is combination of bonus and standard crit calulations.
	// + Zombies: Crit result is based solely on bonus calculation. 
	if(GetClientTeam(client)==OtherTeam)
	{
		if(GetRandomInt(0, 1))
		{
			result = false;
			return Plugin_Changed;
		}
	}
	/*else
	{
		result = (szf_critBonus[client] > GetRandomInt(0, 99));
		return Plugin_Changed;
	}*/
	
	return Plugin_Continue;
}

//
// Round Start Event
//
public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
		return Plugin_Continue; 

	CreateTimer(1.0, SetupMapWeapons, true, TIMER_FLAG_NO_MAPCHANGE);
	//RemovePhysicObjects();
	DetermineControlPoints();
	
	int players[MAXPLAYERS+1] = -1;
	int playerCount;
	int surCount;
 
	g_StartTime = GetTime();
	g_AdditionalTime = 0;
	
	for(int i=1; i<=MaxClients; i++)
	{
		g_iDamage[i] = 0;
		g_iKillsThisLife[i] = 0;
		g_iSpecialInfected[i] = INFECTED_NONE;
		g_iSuperHealthSubtract[i] = 0;
	}
	
	g_iZombieTank = 0;
	g_bTankOnce = false;
	LastMan = true;
	RemoveAllGoo();

	//
	// Handle round state.
	// + "teamplay_round_start" event is fired twice on new map loads.
	//
	if(roundState() == RoundInit1) 
	{
		setRoundState(RoundInit2);
		return Plugin_Continue;
	}
	else
	{
		setRoundState(RoundGrace);
		CPrintToChatAll("{olive}[SZF]{default} %t", "Grace Period Start");	
	}
	
	//
	// Assign players to zombie and survivor teams.
	//
	if(zf_bNewRound)
	{
		// Find all active players.
		playerCount = 0;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && (GetClientTeam(i)>1))
			{
				players[playerCount] = i;
				playerCount++;
			}
		}
				
		// Randomize, sort players 
		SortIntegers(players, playerCount, Sort_Random);
		// NOTE: As of SM 1.3.1, SortIntegers w/ Sort_Random doesn't 
		//			 sort the first element of the array. Temp fix below.	
		int idx = GetRandomInt(0,playerCount-1);
		int temp = players[idx];
		players[idx] = players[0];
		players[0] = temp;		
		
		// Sort players using team preference criteria
		if(GetConVarBool(cvarAllowTeamPref)) 
		{
			SortCustom1D(players, playerCount, view_as<SortFunc1D>(Sort_Preference));
		}
		
		// Calculate team counts. At least one survivor must exist.	 
		surCount = RoundToFloor(playerCount*GetConVarFloat(cvarRatio));
		if((surCount==0) && (playerCount>0))
		{
			surCount = 1;
		}	
			
		// Assign active players to survivor and zombie teams.
		g_iStartSurvivors = 0;
		bool bSurvivors[MAXPLAYERS+1] = false;
		int i = 1;
		while(surCount>0 && i<=playerCount)
		{
			int iClient = players[i];
			if(validClient(iClient))
			{
				bool bGood = true;
				if(bGood)
				{
					spawnClient(iClient, surTeam());
					bSurvivors[iClient] = true;
					g_iStartSurvivors++;
					surCount--;
				}
			}
			i++;
		}			
		for(i = 1; i <= playerCount; i++)
		{
			if(validClient(players[i]) && !bSurvivors[players[i]])
				spawnClient(players[i], zomTeam());
		}
		
	}

	// Handle zombie spawn state.	
	zf_spawnSurvivorsKilledCounter = 1;
				 
	// Handle grace period timers.
	CreateTimer(0.5, timer_graceStartPost, TIMER_FLAG_NO_MAPCHANGE);	 
	CreateTimer(45.0, timer_graceEnd, TIMER_FLAG_NO_MAPCHANGE);	
		
	SetGlow();
	UpdateZombieDamageScale();
		
	return Plugin_Continue;
}

//
// Setup End Event
//
public Action OnSetupEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
		return Plugin_Continue;

	CreateTimer(0.5, SetupMapWeapons, false, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.2, Timer_CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
	EndGracePeriod();
	
	g_StartTime = GetTime();
	g_AdditionalTime = 0;
	g_bRoundActive = true;
	
	return Plugin_Continue;
}

public Action SetupMapWeapons(Handle timer, bool starter)
{
	if(!Enabled)
		return Plugin_Continue;

	int entity = -1;
	char name[64];
	int method = 3;
	// 0 = Nothing
	// 1 = Remodel
	// 2 = Replace
	// 3 = Replace & Remodel

	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	if(!StrContains(map, "szf_expedition", false))
	{
		if(starter)
			method = 0;
		else
			method = 1;
	}
	else if(!StrContains(map, "szf_labs_remake", false) || !StrContains(map, "szf_4way", false) || !StrContains(map, "szf_fort", false))
	{
		method = 1;
	}

	int weapon;
	char model[255];
	if(method!=0)
	{
		while((entity = FindEntityByClassname2(entity, "prop_dynamic"))!=-1)
		{
			GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			if((starter && StrEqual(name, "szf_weapon_spawn", false)) ||
			   (!starter && !StrEqual(name, "szf_weapon_spawn", false) && StrEqual(name, "szf_weapon", false)))
			{
				if(method>1)
				{
					weapon = CreateEntityByName("prop_dynamic");
					if(!IsValidEntity(weapon))
					{
						return Plugin_Continue;
					}
					SetEntProp(weapon, Prop_Data, "m_takedamage", 0);
					//SetEntityRenderMode(entity, RENDER_NONE); 
					//SetEntityRenderColor(entity, 0, 0, 0, 0);
					//SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
					//SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);
					//SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
				}
				else
					weapon = entity;

				if(method==2)
				{
					GetEntityModel(entity, model, sizeof(model));
					SetEntityModel(weapon, model);
				}
				else if(GetRandomInt(0, 6)>4 && !starter)
				{
					switch(GetRandomInt(3, 18))
					{
						case 3:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_dex_sniperrifle/c_dex_sniperrifle.mdl");
						}
						case 4:
						{
							SetEntityModel(weapon, "models/weapons/c_models/urinejar.mdl");
						}
						case 5:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_bow/c_bow.mdl");
						}
						case 6:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_leechgun/c_leechgun.mdl");
						}
						case 7:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_crusaders_crossbow/c_crusaders_crossbow.mdl");
						}
						case 8:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_proto_syringegun/c_proto_syringegun.mdl");
						}
						case 9:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_proto_medigun/c_proto_medigun.mdl");
						}
						case 10:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_drg_manmelter/c_drg_manmelter.mdl");
						}
						case 11:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_flamethrower/c_flamethrower.mdl");
						}
						case 12:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_drg_phlogistinator/c_drg_phlogistinator.mdl");
						}
						case 13:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_shogun_warhorn/c_shogun_warhorn.mdl");
						}
						case 14:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_syringegun/c_syringegun.mdl");
						}
						case 15:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl");
						}
						case 16:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_bet_rocketlauncher/c_bet_rocketlauncher.mdl");
						}
						case 17:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_directhit/c_directhit.mdl");
						}
						case 18:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_blackbox/c_blackbox.mdl");
						}
					}
				}
				else if(GetRandomInt(0, 2)>0)
				{
					switch(GetRandomInt(2, 15))
					{
						case 2:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_shotgun/c_shotgun.mdl");
						}
						case 3:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl");
						}
						case 4:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_bugle/c_bugle.mdl");
						}
						case 5:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl");
						}
						case 6:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_detonator/c_detonator.mdl");
						}
						case 7:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_degreaser/c_degreaser.mdl");
						}
						case 8:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_liberty_launcher/c_liberty_launcher.mdl");
						}
						case 9:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_lochnload/c_lochnload.mdl");
						}
						case 10:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_sticky_jumper/c_sticky_jumper.mdl");
						}
						case 11:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_scottish_resistance.mdl");
						}
						case 12:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl");
						}
						case 13:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_medigun/c_medigun.mdl");
						}
						case 14:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_syringegun/c_syringegun.mdl");
						}
						case 15:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_bazaar_sniper/c_bazaar_sniper.mdl");
						}
					}
				}
				else
				{
					switch(GetRandomInt(1, 4))
					{
						case 1:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl");
						}
						case 2:
						{
							if(GetRandomInt(0, 4)>3)
								SetEntityModel(weapon, "models/weapons/c_models/c_ttg_max_gun/c_ttg_max_gun.mdl");
							else
								SetEntityModel(weapon, "models/weapons/c_models/c_pistol/c_pistol.mdl");
						}
						case 3:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl");
						}
						case 4:
						{
							SetEntityModel(weapon, "models/weapons/c_models/c_wrangler.mdl");
						}
					}
				}
				if(method>1)
				{
					static float angle[3];
					GetEntPropVector(entity, Prop_Send, "m_angRotation", angle);

					static float position[3];
					GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);

					DispatchSpawn(weapon);
					TeleportEntity(weapon, position, angle, NULL_VECTOR);
					SetEntProp(weapon, Prop_Data, "m_takedamage", 0);

					SetEntProp(weapon, Prop_Send, "m_nSolidType", 6);
					SetEntProp(weapon, Prop_Send, "m_usSolidFlags", 2);
					SetEntProp(weapon, Prop_Send, "m_CollisionGroup", 5);
					//SetEntPropString(weapon, Prop_Data, "m_iName", name);

					AcceptEntityInput(entity, "Kill");
				}
			}
		}
	}

	return Plugin_Continue;
}

void EndGracePeriod()
{
	if(!Enabled || roundState()==RoundActive || roundState()==RoundPost)
		return;
	
	setRoundState(RoundActive);
	CPrintToChatAll("{olive}[SZF]{default} %t", "Grace Period End");
	ZombieRage(true);
}

//
// Round End Event
//
public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
		return Plugin_Continue;

	//
	// Prepare for a completely new round, if
	// + Round was a full round (full_round flag is set), OR
	// + Zombies are the winning team.
	//
	zf_bNewRound = GetEventBool(event, "full_round") || (GetEventInt(event, "team") == zomTeam());
	setRoundState(RoundPost);

	char strPath[PLATFORM_MAX_PATH];
	MusicGetPath((GetEventInt(event, "team")==zomTeam()) ? MUSIC_ROUNDLOSE : MUSIC_ROUNDWIN, 0, strPath, sizeof(strPath));
	EmitSoundToAll(strPath);

	for(int client=1; client<=MaxClients; client++)
	{
		SetClientGlow(client, -3600.0, 0.0);
	}

	SetGlow();
	UpdateZombieDamageScale();
	g_bRoundActive = false;
	stripMap = false;
	
	return Plugin_Continue;
}

//
// Player Spawn Event
//
public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{	 
	if(!Enabled)
		return Plugin_Continue;	
			
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	//StartSoundSystem(client, MUSIC_NONE);
	
	g_iSuperHealthSubtract[client] = 0;
	g_bHitOnce[client] = false;
	g_iHitBonusCombo[client] = 0;
	g_bBackstabbed[client] = false;
	g_iKillsThisLife[client] = 0;
	g_fDamageTakenLife[client] = 0.0;
	g_fDamageDealtLife[client] = 0.0;
	
	DropCarryingItem(client, false);
	
	if(roundState()==RoundActive)
	{
		CreateTimer(0.1, Timer_CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	SetEntityRenderColor(client, 255, 255, 255, 255);
	SetEntityRenderMode(client, RENDER_NORMAL);
	
	if(roundState() == RoundActive)
	{
		if(g_iZombieTank > 0 && g_iZombieTank == client && g_iSpecialInfected[client] == INFECTED_NONE)
		{
			if(TF2_GetPlayerClass(client) != TFClass_Heavy)
			{
				TF2_SetPlayerClass(client, TFClass_Heavy, true, true);
				TF2_RespawnPlayer(client);
				CreateTimer(0.1, timer_postSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Stop;
			}
			else
			{
				g_iZombieTank = 0;
				g_iSpecialInfected[client] = INFECTED_TANK;
				
				int iSurvivors = GetSurvivorCount();
				int iHealth = GetConVarInt(cvarTankHealth) * iSurvivors;
				if(iHealth < GetConVarInt(cvarTankHealthMin))
					iHealth = GetConVarInt(cvarTankHealthMin);
				if(iHealth > GetConVarInt(cvarTankHealthMax))
					iHealth = GetConVarInt(cvarTankHealthMax);
				
				int iSubtract = 0;
				if(GetConVarFloat(cvarTankTime) > 0.0)
				{
					iSubtract = RoundFloat(float(iHealth) / GetConVarFloat(cvarTankTime));
					if(iSubtract < 3)
						iSubtract = 3;
				}
				g_iSuperHealthSubtract[client] = iSubtract;
				TF2_AddCondition(client, TFCond_Kritzkrieged, TFCondDuration_Infinite);
				SetEntityHealth(client, iHealth);
				
				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				SetEntityRenderColor(client, 0, 255, 0, 255);
				PerformFastRespawn2(client);

				for(int slot; slot<7; slot++)
				{
					TF2_RemoveWeaponSlot(client, slot);
				}
				int weapon = SpawnWeapon(client, "tf_weapon_fists", 331, 101, 14, "1 ; 0.54 ; 107 ; 1.15 ; 252 ; 0.5 ; 329 ; 0.5");
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);

				TF2Attrib_SetByDefIndex(weapon, 26, 300.0+float(iHealth));
				
				MusicHandleAll();
				
				CPrintToChatAll("{olive}[SZF]{default} %t", "Tank");
			}
		}
	}
	
	TFClassType clientClass = TF2_GetPlayerClass(client);
	

	resetClientState(client);
	CreateZombieSkin(client);
				
	// 1. Prevent players spawning on survivors if round has started.
	//		Prevent players spawning on survivors as an invalid class.
	//		Prevent players spawning on zombies as an invalid class.
	if(GetClientTeam(client)==OtherTeam)
	{
		if(roundState() == RoundActive)
		{
			spawnClient(client, zomTeam());
			return Plugin_Continue;
		}
		if(!validSurvivor(clientClass) && MapType==1)
		{
			spawnClient(client, surTeam()); 
			return Plugin_Continue;
		}			
	}
	else if(GetClientTeam(client)==ZomTeam)
	{
		if(!validZombie(clientClass))
		{
			spawnClient(client, zomTeam()); 
			return Plugin_Continue;
		}
		if(roundState() == RoundActive)
		{
			if(g_iSpecialInfected[client]!=INFECTED_TANK && !PerformFastRespawn(client))
				TF2_AddCondition(client, TFCond_Ubercharged, 2.0);
		}
	}	 

	// 2. Handle valid, post spawn logic
	PrintToChat(client, "Spawned");
	CreateTimer(0.1, timer_postSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
	
	SetGlow();
	UpdateZombieDamageScale();
	TankCanReplace(client);
	CheckStartWeapons();
	//HandleClientInventory(client);
			
	return Plugin_Continue; 
}

/*public Action OnPlayerInventory(Handle event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
		return Plugin_Continue;

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	return Plugin_Continue;
}*/

//
// Player Death Event
//
public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
		return Plugin_Continue;

	int killers[2];
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	killers[0] = GetClientOfUserId(GetEventInt(event, "attacker")); 
	killers[1] = GetClientOfUserId(GetEventInt(event, "assister"));  

	ClientCommand(victim, "r_screenoverlay\"\"");

	if(roundState()==RoundActive)
	{
		CreateTimer(0.1, Timer_CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	DropCarryingItem(victim);
	SetClientGlow(victim, -3600.0, 0.0);
	
	// handle bonuses
	if(validZom(killers[0]) && killers[0]!=victim)
	{
		g_iKillsThisLife[killers[0]]++;
		if(g_iKillsThisLife[killers[0]] <= 1)
			GiveBonus(killers[0], "zombie_kill");
		if(g_iKillsThisLife[killers[0]] == 2)
			GiveBonus(killers[0], "zombie_kill_2");
		if(g_iKillsThisLife[killers[0]] > 2)
			GiveBonus(killers[0], "zombie_kill_lot");
		if(g_bBackstabbed[victim])
			GiveBonus(killers[0], "zombie_stab_death");
	}
	if(validZom(killers[1]) && killers[1] != victim)
	{
		GiveBonus(killers[1], "zombie_assist");
	}
	
	if(g_iSpecialInfected[victim] == INFECTED_TANK)
	{
		g_iDamage[victim] = GetAverageDamage();
	}

	g_iSpecialInfected[victim] = INFECTED_NONE;
	g_bBackstabbed[victim] = false;
	
	// Handle zombie death logic, all round states.
	if(validZom(victim))
	{
		// Remove dropped ammopacks from zombies.
		int index = -1; 
		while((index = FindEntityByClassname(index, "tf_ammo_pack"))!=-1)
		{
			if(GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity") == victim)
				AcceptEntityInput(index, "Kill");
		}
		if(g_bZombieRage && roundState() == RoundActive)
			CreateTimer(0.1, RespawnPlayer, victim);
	} 

	if(roundState()!=RoundActive && roundState()!=RoundPost)
	{
		CreateTimer(0.1, RespawnPlayer, victim);
		return Plugin_Continue;
	}

	// Handle survivor death logic, active round only.
	if(validSur(victim))
	{
		if(validZom(killers[0]))
			zf_spawnSurvivorsKilledCounter--;

		// Transfer player to zombie team.
		CreateTimer(2.0, timer_zombify, victim, TIMER_FLAG_NO_MAPCHANGE);
		
		int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_DEAD]-1);
		char strPath[PLATFORM_MAX_PATH];
		MusicGetPath(MUSIC_DEAD, iRandom, strPath, sizeof(strPath));
		EmitSoundToClient(victim, strPath, _, SNDLEVEL_AIRCRAFT);
		EmitSoundToClient(victim, strPath, _, SNDLEVEL_AIRCRAFT);
		StartSoundSystem(victim, MUSIC_NONE);
	}

	// Handle zombie death logic, active round only.
	else if(validZom(victim))
	{
		if(validSur(killers[0]))
			zf_spawnZombiesKilledCounter--;
	}
	
	SetGlow();
	UpdateZombieDamageScale();
	CheckStartWeapons();
	 
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Periodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action timer_main(Handle timer) // 1Hz
{		 
	if(!Enabled)
		return Plugin_Continue;
	
	handle_zombieAbilities();	 
	if(g_bZombieRage)
	{
		setTeamRespawnTime(zomTeam(), 0.0);
	}
	else
	{
		float fDelay = 0.0;
		if(g_fZombieDamageScale < 1.0)
		{
			fDelay = 1.0 - g_fZombieDamageScale;
			// 0.90 = 0.1 * 15.0 = 1.5 seconds;
			fDelay *= 15.0;
		}
		setTeamRespawnTime(zomTeam(), 5.0 + fDelay);
	}
	
	MusicHandleAll();

	if(roundState() == RoundActive)
	{
		handle_winCondition();
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if(validLivingZom(i) && g_iSpecialInfected[i] == INFECTED_TANK)
			{
				int iHealth = GetClientHealth(i);
				if(iHealth > 1)
				{
					iHealth -= g_iSuperHealthSubtract[i];
					if(iHealth < 1)
						iHealth = 1;
					SetEntityHealth(i, iHealth);
				}
				else
				{
					ForcePlayerSuicide(i);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action timer_mainSlow(Handle timer) // 4 min
{ 
	if(!Enabled)
		return Plugin_Continue;	
	help_printZFInfoChat(0);
	
	return Plugin_Continue;
}

public Action timer_mainFast(Handle timer)
{ 
	if(!Enabled || roundState()!=RoundActive)
		return Plugin_Continue;	

	for(int client; client<=MaxClients; client++)
	{
		SetClientGlow(client, -0.2);
	}
	
	return Plugin_Continue;
}

public Action timer_hoarde(Handle timer) // 1/5th Hz
{	
	if(!Enabled)
		return Plugin_Continue;
	handle_hoardeBonus();
	
	return Plugin_Continue;	
}

public Action timer_datacollect(Handle timer) // 1/5th Hz
{	
	if(!Enabled)
		return Plugin_Continue;
	FastRespawnDataCollect();
	
	return Plugin_Continue;	
}

////////////////////////////////////////////////////////////
//
// Aperiodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action timer_graceStartPost(Handle timer)
{ 
	// Disable all resupply cabinets.
	int index = -1;
	while((index = FindEntityByClassname(index, "func_regenerate")) != -1)
		AcceptEntityInput(index, "Disable");
		
	// Remove all dropped ammopacks.
	index = -1;
	while((index = FindEntityByClassname(index, "tf_ammo_pack")) != -1)
			AcceptEntityInput(index, "Kill");
	
	// Remove all ragdolls.
	index = -1;
	while((index = FindEntityByClassname(index, "tf_ragdoll")) != -1)
			AcceptEntityInput(index, "Kill");

	// Disable all payload cart dispensers.
	index = -1;
	while((index = FindEntityByClassname(index, "mapobj_cart_dispenser")) != -1)
		SetEntProp(index, Prop_Send, "m_bDisabled", 1);	
	

	// Disable all respawn room visualizers (non-ZF maps only)
	if(!mapIsZF())
	{
		char strParent[255];
		index = -1;
		while((index = FindEntityByClassname(index, "func_respawnroomvisualizer")) != -1)
		{
			GetEntPropString(index, Prop_Data, "respawnroomname", strParent, sizeof(strParent));
			if(!StrEqual(strParent, "ZombieSpawn", false))
			{
				AcceptEntityInput(index, "Disable");
			}
		}
	}
	
	int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_PREPARE]-1);
	char strPath[PLATFORM_MAX_PATH];
	MusicGetPath(MUSIC_PREPARE, iRandom, strPath, sizeof(strPath));
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(client)==OtherTeam && ShouldHearEventSounds(i))
		{
			EmitSoundToClient(i, strPath);
		}
	}	
	
	return Plugin_Continue; 
}

public Action timer_graceEnd(Handle timer)
{
	EndGracePeriod();

	return Plugin_Continue;	
}

public Action timer_initialHelp(Handle timer, any client)
{		
	// Wait until client is in game before printing initial help text.
	if(IsClientInGame(client))
	{
		help_printZFInfoChat(client);
	}
	else
	{
		CreateTimer(10.0, timer_initialHelp, client, TIMER_FLAG_NO_MAPCHANGE);	
	}
	
	return Plugin_Continue; 
}

public Action timer_postSpawn(Handle timer, any client)
{
	if(validClient(client) && IsPlayerAlive(client))
	{
		if(GetClientTeam(client) == OtherTeam)
		{
			HandleClientInventory(client);
		}
		else if(GetClientTeam(client) == ZomTeam)
		{
			int entity=-1;
			while((entity=FindEntityByClassname2(entity, "tf_wear*"))!=-1)
			{
				if(GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == ZomTeam)
				{
					switch(GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex"))
					{
						case 493, 233, 234, 241, 280, 281, 282, 283, 284, 286, 288, 362, 364, 365, 536, 542, 577, 599, 673, 729, 791, 839, 5607:  //Action slot items
						{
							//NOOP
						}
						case 5617, 5618, 5619, 5620, 5621, 5622, 5623, 5624, 5625:  //Voodoo cosmetics
						{
							//NOOP
						}
						default:
							TF2_RemoveWearable(client, entity);
					}
				}
			}

			entity=-1;
			while((entity=FindEntityByClassname2(entity, "tf_powerup_bottle"))!=-1)
			{
				if(GetClientTeam((GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == ZomTeam)
					TF2_RemoveWearable(client, entity);
			}
		}
		CreateTimer(0.15, Timer_CheckItems, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue; 
}

public Action timer_zombify(Handle timer, any client)
{	 
	if(roundState() != RoundActive)
		return Plugin_Continue;
	if(validClient(client))
	{
		CPrintToChat(client, "{olive}[SZF]{default} %t", "Left 4 Dead");
		spawnClient(client, zomTeam());
	}
	
	return Plugin_Continue; 
}

////////////////////////////////////////////////////////////
//
// Handling Functionality
//
////////////////////////////////////////////////////////////
	
void handle_winCondition()
{	
	// 1. Check for any survivors that are still alive.
	bool anySurvivorAlive = false;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)==OtherTeam)
		{
			anySurvivorAlive = true;
			break;
		}
	}
	 
	// 2. If no survivors are alive and at least 1 zombie is playing,
	//		end round with zombie win.
	if(!anySurvivorAlive && (GetTeamClientCount(zomTeam()) > 0))
	{
		endRound(zomTeam());
	}
}

void handle_zombieAbilities()
{
	TFClassType clientClass;
	int curH, maxH, bonus;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)==ZomTeam && g_iSpecialInfected[i] != INFECTED_TANK)
		{	 
			/*clientClass = TF2_GetPlayerClass(i);
			curH = GetClientHealth(i);
			maxH = GetEntProp(i, Prop_Data, "m_iMaxHealth");
							
			// 1. Handle zombie regeneration.
			//		Zombies regenerate health based on class and number of nearby
			//		zombies (hoarde bonus). Zombies decay health when overhealed.
			bonus = 0;
			if(curH < maxH)
			{
				switch(clientClass)
				{
					case TFClass_Scout: bonus = 2 + (1 * zf_hoardeBonus[i]);
					case TFClass_Heavy: bonus = 4 + (3 * zf_hoardeBonus[i]);
					case TFClass_Spy: bonus = 2 + (1 * zf_hoardeBonus[i]);
				}				
				curH += bonus;
				curH = min(curH, maxH);
				SetEntityHealth(i, curH);
			}
			else if(curH > maxH)
			{
				switch(clientClass)
				{
					case TFClass_Scout: bonus = -3;
					case TFClass_Heavy: bonus = -7;
					case TFClass_Spy: bonus = -3;
				}					
				curH += bonus;
				curH = max(curH, maxH); 
				SetEntityHealth(i, curH);
			}

			// 2. Handle zombie crit rate bonus.
			//		Zombies receive crit bonus based on number of nearby zombies
			//		(hoarde bonus). Zombies only receive this bonus at full health
			//		or greater.
			bonus = 0;
			if(curH >= maxH)
			{
				switch(clientClass)
				{
					case TFClass_Scout: bonus = 5 + (1 * zf_hoardeBonus[i]);
					case TFClass_Heavy: bonus = 10 + (5 * zf_hoardeBonus[i]);
					case TFClass_Spy: bonus = 5 + (1 * zf_hoardeBonus[i]);
				}
			}	 
			szf_critBonus[i] = bonus;*/
			
			// 3. Handle zombie rage timer
			//		Rage recharges every 30s.
			if(zf_rageTimer[i] > 0)
			{
				if(zf_rageTimer[i] == 1)
				{
					PrintHintText(i, "Rage is ready!");
				}
				zf_rageTimer[i]--;
			}			
		} //if
	} //for
}

void handle_hoardeBonus()
{ 
	int playerCount;
	int player[MAXPLAYERS];
	int playerHoardeId[MAXPLAYERS];
	float playerPos[MAXPLAYERS][3];
	
	int hoardeSize[MAXPLAYERS];

	int curPlayer;
	int curHoarde;
	Handle hStack;
	
	// 1. Find all active zombie players.
	playerCount = 0;
	for(int i=1; i<=MaxClients; i++)
	{	
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)==ZomTeam)
		{							
			player[playerCount] = i;
			playerHoardeId[playerCount] = -1;
			GetClientAbsOrigin(i, playerPos[playerCount]);
			playerCount++; 
		}
	}
	
	// 2. Calculate hoarde groups.
	//		A hoarde is defined as a single, contiguous group of valid zombie
	//		players. Distance calculation between zombie players serves as
	//		primary decision criteria.
	curHoarde = 0;
	hStack = CreateStack();	
	for(int i = 0; i < playerCount; i++)
	{
		// 2a. Create new hoarde group.
		if(playerHoardeId[i] == -1)
		{
			PushStackCell(hStack, i);	 
			playerHoardeId[i] = curHoarde;
			hoardeSize[curHoarde] = 1;
		}
		
		// 2b. Build current hoarde created in step 2a.
		//		 Use a depth-first adjacency search.
		while(PopStackCell(hStack, curPlayer))
		{						
			for(int j = i+1; j < playerCount; j++)
			{
				if(playerHoardeId[j] == -1)
				{
					if(GetVectorDistance(playerPos[j], playerPos[curPlayer], true) <= 200000)
					{
						PushStackCell(hStack, j);
						playerHoardeId[j] = curHoarde;
						hoardeSize[curHoarde]++;
					}
				}
			} 
		}
		curHoarde++;
	}
	
	// 3. Set hoarde bonuses.
	for(int i = 1; i <= MaxClients; i++)
		zf_hoardeBonus[i] = 0;		
	for(int i = 0; i < playerCount; i++)
		zf_hoardeBonus[player[i]] = hoardeSize[playerHoardeId[i]] - 1;
		
	CloseHandle(hStack);		
}

////////////////////////////////////////////////////////////
//
// ZF Logic Functionality
//
////////////////////////////////////////////////////////////
void zfEnable()
{		 
	Enabled = true;
	zf_bNewRound = true;
	setRoundState(RoundInit2);
	
	zfSetTeams();
		
	for(int i = 0; i <= MAXPLAYERS; i++)
		resetClientState(i);
		
	// Adjust gameplay CVars.
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("mp_teams_unbalance_limit 0");
	// Engineer
	//ServerCommand("sm_cvar tf_obj_upgrade_per_hit 0"); // Locked
	//ServerCommand("sm_cvar tf_sentrygun_metal_per_shell 201"); // Locked
	// Medic
	//ServerCommand("sm_cvar weapon_medigun_charge_rate 30"); // Locked
	//ServerCommand("sm_cvar weapon_medigun_chargerelease_rate 6"); // Locked
	//ServerCommand("sm_cvar tf_max_health_boost 1.25"); // Locked
	//ServerCommand("sm_cvar tf_boost_drain_time 30"); // Locked
	// Spy
	ServerCommand("sm_cvar tf_spy_invis_time 0.5"); // Locked 
	ServerCommand("sm_cvar tf_spy_invis_unstealth_time 0.75"); // Locked 
	ServerCommand("sm_cvar tf_spy_cloak_no_attack_time 1.0"); // Locked 
		
	// [Re]Enable periodic timers.
	if(szf_tMain != INVALID_HANDLE)		
		CloseHandle(szf_tMain);
	szf_tMain = CreateTimer(1.0, timer_main, _, TIMER_REPEAT); 
	
	if(szf_tMainSlow != INVALID_HANDLE)
		CloseHandle(szf_tMainSlow);		
	szf_tMainSlow = CreateTimer(240.0, timer_mainSlow, _, TIMER_REPEAT);
	
	if(szf_tMainFast != INVALID_HANDLE)
		CloseHandle(szf_tMainFast);		
	szf_tMainFast = CreateTimer(0.2, timer_mainFast, _, TIMER_REPEAT);
	
	if(szf_tHoarde != INVALID_HANDLE)
		CloseHandle(szf_tHoarde);
	szf_tHoarde = CreateTimer(5.0, timer_hoarde, _, TIMER_REPEAT); 
	
	if(szf_tDataCollect != INVALID_HANDLE)
		CloseHandle(szf_tDataCollect);
	szf_tDataCollect = CreateTimer(2.0, timer_datacollect, _, TIMER_REPEAT);

	#if defined _steamtools_included
	if(steamtools)
	{
		char gameDesc[64];
		Format(gameDesc, sizeof(gameDesc), "Super Zombie Fortress (%s)", PLUGIN_VERSION);
		Steam_SetGameDescription(gameDesc);
	}
	#endif
}

void zfDisable()
{	
	Enabled = false;
	zf_bNewRound = true;
	setRoundState(RoundInit2);
	
	for(int i = 0; i <= MAXPLAYERS; i++)
		resetClientState(i);
		
	// Adjust gameplay CVars.
	ServerCommand("mp_autoteambalance 1");
	ServerCommand("mp_teams_unbalance_limit 1");
	// Engineer
	//ServerCommand("sm_cvar tf_obj_upgrade_per_hit 25"); // Locked
	//ServerCommand("sm_cvar tf_sentrygun_metal_per_shell 1"); // Locked
	// Medic
	//ServerCommand("sm_cvar weapon_medigun_charge_rate 40"); // Locked
	//ServerCommand("sm_cvar weapon_medigun_chargerelease_rate 8"); // Locked
	//ServerCommand("sm_cvar tf_max_health_boost 1.5"); // Locked
	//ServerCommand("sm_cvar tf_boost_drain_time 15"); // Locked 
	// Spy
	ServerCommand("sm_cvar tf_spy_invis_time 1.0"); // Locked 
	ServerCommand("sm_cvar tf_spy_invis_unstealth_time 2.0"); // Locked 
	ServerCommand("sm_cvar tf_spy_cloak_no_attack_time 2.0"); // Locked 
			
	// Disable periodic timers.
	if(szf_tMain != INVALID_HANDLE)
	{			
		CloseHandle(szf_tMain);
		szf_tMain = INVALID_HANDLE;
	}
	if(szf_tMainSlow != INVALID_HANDLE)
	{
		CloseHandle(szf_tMainSlow);
		szf_tMainSlow = INVALID_HANDLE;
	}
	if(szf_tHoarde != INVALID_HANDLE)
	{
		CloseHandle(szf_tHoarde);
		szf_tHoarde = INVALID_HANDLE;
	}
	
	if(szf_tDataCollect != INVALID_HANDLE)
	{
		CloseHandle(szf_tDataCollect);
		szf_tDataCollect = INVALID_HANDLE;
	}

	// Enable resupply lockers.
	int index = -1;
	while((index = FindEntityByClassname(index, "func_regenerate")) != -1)
		AcceptEntityInput(index, "Enable");

	#if defined _steamtools_included
	if(steamtools)
	{
		Steam_SetGameDescription("Team Fortress");
	}
	#endif
}

void zfSetTeams()
{
	//
	// Determine team roles.
	// + By default, survivors are RED and zombies are BLU.
	//
	int survivorTeam = view_as<int>(TFTeam_Red);
	int zombieTeam = view_as<int>(TFTeam_Blue);
	
	//
	// Determine whether to swap teams on payload maps.
	// + For "pl_" prefixed maps, swap teams if sm_zf_swaponpayload is set.
	//
	if(mapIsPL())
	{
		if(GetConVarBool(cvarSwapOnPayload)) 
		{			
			survivorTeam = view_as<int>(TFTeam_Blue);
			zombieTeam = view_as<int>(TFTeam_Red);
		}
	}
	
	//
	// Determine whether to swap teams on attack / defend maps.
	// + For "cp_" prefixed maps with all RED control points, swap teams if sm_zf_swaponattdef is set.
	//
	if(mapIsCP())
	{
		if(GetConVarBool(cvarSwapOnAttdef))
		{
			bool isAttdef = true;
			int index = -1;
			while((index = FindEntityByClassname(index, "team_control_point")) != -1)
			{
				if(GetEntProp(index, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Red))
				{
					isAttdef = false;
					break;
				}
			}
			
			if(isAttdef)
			{
				survivorTeam = view_as<int>(TFTeam_Blue);
				zombieTeam = view_as<int>(TFTeam_Red);
			}
		}
	}
	
	// Set team roles.
	setSurTeam(survivorTeam);
	setZomTeam(zombieTeam);
}

void zfSwapTeams()
{
	int survivorTeam = surTeam();
	int zombieTeam = zomTeam();
	
	// Swap team roles.
	setSurTeam(zombieTeam);
	setZomTeam(survivorTeam);
}

////////////////////////////////////////////////////////////
//
// Utility Functionality
//
////////////////////////////////////////////////////////////
public int Sort_Preference(int client1, int client2, const int[] array, Handle hndl)
{	
 // Used during round start to sort using client team preference.
	int prefCli1 = IsFakeClient(client1) ? ZF_TEAMPREF_NONE : prefGet(client1, TeamPref);
	int prefCli2 = IsFakeClient(client2) ? ZF_TEAMPREF_NONE : prefGet(client2, TeamPref);	
	return (prefCli1 < prefCli2) ? -1 : (prefCli1 > prefCli2) ? 1 : 0;
}

void resetClientState(int client)
{ 
	szf_critBonus[client] = 0;
	zf_hoardeBonus[client] = 0;
	zf_rageTimer[client] = 0;
}

////////////////////////////////////////////////////////////
//
// Help Functionality
//
////////////////////////////////////////////////////////////
public void help_printZFInfoChat(int client)
{
	if(client == 0)
	{
		CPrintToChatAll("{olive}[SZF]{default} %t", "Server Info", PLUGIN_VERSION);
		CPrintToChatAll("{olive}[SZF]{default} %t", "SZF Command");		
	}
	else
	{
		CPrintToChat(client, "{olive}[SZF]{default} %t", "Server Info", PLUGIN_VERSION);
		CPrintToChat(client, "{olive}[SZF]{default} %t", "SZF Command");
	}
}

////////////////////////////////////////////////////////////
//
// Main Menu Functionality
//
////////////////////////////////////////////////////////////
public void panel_PrintMain(int client)
{
	Handle panel = CreatePanel();
	char temp_string21[256];
	Format(temp_string21, sizeof(temp_string21),"%T", "SZF Main Menu", client);
	SetPanelTitle(panel, temp_string21);
	Format(temp_string21, sizeof(temp_string21),"%T", "Help", client);
	DrawPanelItem(panel, temp_string21);	
	if(GetConVarBool(cvarAllowTeamPref)) 
	{
		Format(temp_string21, sizeof(temp_string21),"%T", "Preferences", client);
		DrawPanelItem(panel, temp_string21);
	}
	Format(temp_string21, sizeof(temp_string21),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string21);
	SendPanelToClient(panel, client, panel_HandleMain, 10);
	CloseHandle(panel);
}

public int panel_HandleMain(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintHelp(param1);			 
			case 2: panel_PrintPrefs(param1);	 
			default: return;	 
		} 
	} 
}

//
// Main.Preferences Menus
//
public void panel_PrintPrefs(int client)
{
	Handle panel = CreatePanel();
	char temp_string1[256];
	Format(temp_string1, sizeof(temp_string1),"%T", "ZF Preferences", client);
	SetPanelTitle(panel, temp_string1);
	if(GetConVarBool(cvarAllowTeamPref)) 
	{
		Format(temp_string1, sizeof(temp_string1),"%T", "Team Preference", client);
		DrawPanelItem(panel, temp_string1);	
	}
	Format(temp_string1, sizeof(temp_string1),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string1);
	SendPanelToClient(panel, client, panel_HandlePrefs, 10);
	CloseHandle(panel);
}

public int panel_HandlePrefs(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintPrefs00(param1);
			default: return;
		}
	}
}

public void panel_PrintPrefs00(int client)
{
	Handle panel = CreatePanel();
	char temp_string2[512];
	Format(temp_string2, sizeof(temp_string2),"%T", "SZF Team Preference", client);
	SetPanelTitle(panel, temp_string2);
	
	if(prefGet(client, TeamPref) == ZF_TEAMPREF_NONE)
	{
		Format(temp_string2, sizeof(temp_string2),"%T%T", "Current", client, "None", client);
		DrawPanelItem(panel, temp_string2, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(temp_string2, sizeof(temp_string2),"%T", "None", client);
		DrawPanelItem(panel, temp_string2);
	}

	if(prefGet(client, TeamPref) == ZF_TEAMPREF_SUR)
	{
		Format(temp_string2, sizeof(temp_string2),"%T%T", "Current", client, "Survivors", client);
		DrawPanelItem(panel, temp_string2, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(temp_string2, sizeof(temp_string2),"%T", "Survivors", client);
		DrawPanelItem(panel, temp_string2);
	}
				
	if(prefGet(client, TeamPref) == ZF_TEAMPREF_ZOM)
	{
		Format(temp_string2, sizeof(temp_string2),"%T%T", "Current", client, "Zombies", client);
		DrawPanelItem(panel, temp_string2, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(temp_string2, sizeof(temp_string2),"%T", "Zombies", client);
		DrawPanelItem(panel, temp_string2);
	}
	Format(temp_string2, sizeof(temp_string2),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string2);
	SendPanelToClient(panel, client, panel_HandlePrefTeam, 30);
	CloseHandle(panel);
}

public int panel_HandlePrefTeam(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: prefSet(param1, TeamPref, ZF_TEAMPREF_NONE);
			case 2: prefSet(param1, TeamPref, ZF_TEAMPREF_SUR);
			case 3: prefSet(param1, TeamPref, ZF_TEAMPREF_ZOM);
			default: return;	 
		} 
	}
}

//
// Main.Help Menu
//
public void panel_PrintHelp(int client)
{
	Handle panel = CreatePanel();
	
	char temp_string3[1024];
	Format(temp_string3, sizeof(temp_string3),"%T", "SZF Help", client);
	SetPanelTitle(panel, temp_string3);
	Format(temp_string3, sizeof(temp_string3),"%T", "SZF Overview", client);
	DrawPanelItem(panel, temp_string3);
	Format(temp_string3, sizeof(temp_string3),"%T%T", "Team", client, "Survivors", client);
	DrawPanelItem(panel, temp_string3);
	Format(temp_string3, sizeof(temp_string3),"%T%T", "Team", client, "Zombies", client);
	DrawPanelItem(panel, temp_string3);
	Format(temp_string3, sizeof(temp_string3),"%T%T", "Classes", client, "Survivors", client);
	DrawPanelItem(panel, temp_string3);
	Format(temp_string3, sizeof(temp_string3),"%T%T", "Classes", client, "Zombies", client);
	DrawPanelItem(panel, temp_string3);
	Format(temp_string3, sizeof(temp_string3),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string3);
	SendPanelToClient(panel, client, panel_HandleHelp, 30);
	CloseHandle(panel);
}

public int panel_HandleHelp(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintOverview(param1);
			case 2: panel_PrintTeam(param1, view_as<int>(surTeam()));
			case 3: panel_PrintTeam(param1, view_as<int>(zomTeam()));
			case 4: panel_PrintSurClass(param1);
			case 5: panel_PrintZomClass(param1);
			default: return;	 
		} 
	} 
}
 
//
// Main.Help.Overview Menus
//
public void panel_PrintOverview(int client)
{
	Handle panel = CreatePanel();
	
	char temp_string4[1024];
	Format(temp_string4, sizeof(temp_string4),"%T", "SZF Overview", client);
	SetPanelTitle(panel, temp_string4);
	DrawPanelText(panel, "-------------------------------------------");
	Format(temp_string4, sizeof(temp_string4),"%T", "Human Help 1", client);
	DrawPanelText(panel, temp_string4);
	Format(temp_string4, sizeof(temp_string4),"%T", "Human Help 2", client);
	DrawPanelText(panel, temp_string4);
	Format(temp_string4, sizeof(temp_string4),"%T", "SZF Overview", client);
	DrawPanelText(panel, "-------------------------------------------");
	Format(temp_string4, sizeof(temp_string4),"%T", "Return to Help Menu", client);
	DrawPanelItem(panel, temp_string4); 
	Format(temp_string4, sizeof(temp_string4),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string4);
	SendPanelToClient(panel, client, panel_HandleOverview, 10);
	CloseHandle(panel);
}

public int panel_HandleOverview(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintHelp(param1);
			default: return;	 
		} 
	} 
}
 
//
// Main.Help.Team Menus
//
public void panel_PrintTeam(int client, int team)
{
	Handle panel = CreatePanel();
	if(team == view_as<int>(surTeam()))
	{
		char temp_string5[1024];
		Format(temp_string5, sizeof(temp_string5),"%T", "SZF Survivor Team", client);
		SetPanelTitle(panel, temp_string5);
		DrawPanelText(panel, "-------------------------------------------");
		Format(temp_string5, sizeof(temp_string5),"%T", "Human Help A", client);
		DrawPanelText(panel, temp_string5);
		Format(temp_string5, sizeof(temp_string5),"%T", "Human Help B", client);
		DrawPanelText(panel, temp_string5);
		Format(temp_string5, sizeof(temp_string5),"%T", "Human Help C", client);
		DrawPanelText(panel, temp_string5);
		Format(temp_string5, sizeof(temp_string5),"%T", "Human Help D", client);
		DrawPanelText(panel, temp_string5);
		Format(temp_string5, sizeof(temp_string5),"%T",  "Human Help E", client);
		DrawPanelText(panel, temp_string5);
		DrawPanelText(panel, "-------------------------------------------");
	}
	else if(team == view_as<int>(zomTeam()))
	{
		char temp_string6[2048];
		Format(temp_string6, sizeof(temp_string6),"%T", "SZF Zombie Team", client);
		SetPanelTitle(panel, temp_string6);
		DrawPanelText(panel, "-------------------------------------------");
		Format(temp_string6, sizeof(temp_string6),"%T", "Zombie Help A", client);
		DrawPanelText(panel, temp_string6);
		Format(temp_string6, sizeof(temp_string6),"%T", "Zombie Help B", client);
		DrawPanelText(panel, temp_string6);
		Format(temp_string6, sizeof(temp_string6),"%T", "Zombie Help C", client);
		DrawPanelText(panel, temp_string6);
		Format(temp_string6, sizeof(temp_string6),"%T", "Zombie Help D", client);
		DrawPanelText(panel, temp_string6);
		Format(temp_string6, sizeof(temp_string6),"%T", "Zombie Help E", client);
		DrawPanelText(panel, temp_string6);
		Format(temp_string6, sizeof(temp_string6),"%T", "Zombie Help F", client);
		DrawPanelText(panel, temp_string6);
		Format(temp_string6, sizeof(temp_string6),"%T", "Zombie Help G", client);
		DrawPanelText(panel, temp_string6);
		DrawPanelText(panel, "-------------------------------------------");
	}
	char temp_string7[512];
	Format(temp_string7, sizeof(temp_string7),"%T", "Return to Help Menu", client);
	DrawPanelItem(panel, temp_string7);
	Format(temp_string7, sizeof(temp_string7),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string7);
	SendPanelToClient(panel, client, panel_HandleTeam, 10);
	CloseHandle(panel);
}

public int panel_HandleTeam(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintHelp(param1);
			default: return;	 
		} 
	} 
}

//
// Main.Help.Class Menus
//
public void panel_PrintSurClass(int client)
{
	Handle panel = CreatePanel();
	
	char temp_string8[512];
	Format(temp_string8, sizeof(temp_string8),"%T", "SZF Survivor Classes", client);
	SetPanelTitle(panel, temp_string8);
	Format(temp_string8, sizeof(temp_string8),"%T", "Soldier", client);
	DrawPanelItem(panel, temp_string8);
	Format(temp_string8, sizeof(temp_string8),"%T", "Sniper", client);
	DrawPanelItem(panel, temp_string8);
	Format(temp_string8, sizeof(temp_string8),"%T", "Medic", client);
	DrawPanelItem(panel, temp_string8);
	Format(temp_string8, sizeof(temp_string8),"%T", "Demoman", client);
	DrawPanelItem(panel, temp_string8);
	Format(temp_string8, sizeof(temp_string8),"%T", "Pyro", client);
	DrawPanelItem(panel, temp_string8);
	Format(temp_string8, sizeof(temp_string8),"%T", "Engineer", client);
	DrawPanelItem(panel, temp_string8);
	Format(temp_string8, sizeof(temp_string8),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string8);
	SendPanelToClient(panel, client, panel_HandleSurClass, 10);
	CloseHandle(panel);
}

public int panel_HandleSurClass(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintClass(param1, TFClass_Soldier);
			case 2: panel_PrintClass(param1, TFClass_Sniper);
			case 3: panel_PrintClass(param1, TFClass_Medic);
			case 4: panel_PrintClass(param1, TFClass_DemoMan);
			case 5: panel_PrintClass(param1, TFClass_Pyro);
			case 6: panel_PrintClass(param1, TFClass_Engineer);
			default: return;	 
		}
	} 
}
			
public void panel_PrintZomClass(int client)
{
	Handle panel = CreatePanel();
	char temp_string9[512];
	Format(temp_string9, sizeof(temp_string9),"%T", "SZF Zombie Classes", client);
	SetPanelTitle(panel, temp_string9);
	Format(temp_string9, sizeof(temp_string9),"%T", "Scout", client);
	DrawPanelItem(panel, temp_string9);
	Format(temp_string9, sizeof(temp_string9),"%T", "Heavy", client);
	DrawPanelItem(panel, temp_string9);
	Format(temp_string9, sizeof(temp_string9),"%T", "Spy", client);
	DrawPanelItem(panel, temp_string9);
	Format(temp_string9, sizeof(temp_string9),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string9);
	SendPanelToClient(panel, client, panel_HandleZomClass, 10);
	CloseHandle(panel);
}

public int panel_HandleZomClass(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintClass(param1, TFClass_Scout);
			case 2: panel_PrintClass(param1, TFClass_Heavy);
			case 3: panel_PrintClass(param1, TFClass_Spy);
			default: return;	 
		} 
	} 
}

public void panel_PrintClass(int client, TFClassType class)
{
	Handle panel = CreatePanel();
	switch(class)
	{
		case TFClass_Soldier:
		{
			char temp_string10[1024];
			Format(temp_string10, sizeof(temp_string10),"%T", "Soldier Human 1", client);
			SetPanelTitle(panel, temp_string10);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string10, sizeof(temp_string10),"%T", "Soldier Human 2", client);
			DrawPanelText(panel, temp_string10);
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Pyro:
		{
			char temp_string11[512];
			Format(temp_string11, sizeof(temp_string11),"%T", "Pyro Human 1", client);
			SetPanelTitle(panel, temp_string11);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string11, sizeof(temp_string11),"%T", "Pyro Human 2", client);
			DrawPanelText(panel, temp_string11);
			Format(temp_string11, sizeof(temp_string11),"%T", "Pyro Human 3", client);
			DrawPanelText(panel, temp_string11);			
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_DemoMan:
		{
			char temp_string12[1024];
			Format(temp_string12, sizeof(temp_string12),"%T", "Demoman Human 1", client);
			SetPanelTitle(panel, temp_string12);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string12, sizeof(temp_string12),"%T", "Demoman Human 2", client);
			DrawPanelText(panel, temp_string12);		
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Engineer:
		{
			char temp_string13[2048];
			Format(temp_string13, sizeof(temp_string13),"%T", "Engineer Human 1", client);
			SetPanelTitle(panel, temp_string13);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string13, sizeof(temp_string13),"%T", "Engineer Human 2", client);
			DrawPanelText(panel, temp_string13);
			Format(temp_string13, sizeof(temp_string13),"%T", "Engineer Human 3", client);
			DrawPanelText(panel, temp_string13);
			Format(temp_string13, sizeof(temp_string13),"%T", "Engineer Human 4", client);
			DrawPanelText(panel, temp_string13);
			Format(temp_string13, sizeof(temp_string13),"%T", "Engineer Human 5", client);
			DrawPanelText(panel, temp_string13);
			Format(temp_string13, sizeof(temp_string13),"%T", "Engineer Human 6", client);
			DrawPanelText(panel, temp_string13);		
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Medic:
		{
			char temp_string14[2048];
			Format(temp_string14, sizeof(temp_string14),"%T", "Medic Human 1", client);
			SetPanelTitle(panel, temp_string14);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string14, sizeof(temp_string14),"%T", "Medic Human 2", client);
			DrawPanelText(panel, temp_string14);
			Format(temp_string14, sizeof(temp_string14),"%T", "Medic Human 3", client);
			DrawPanelText(panel, temp_string14);
			Format(temp_string14, sizeof(temp_string14),"%T", "Medic Human 4", client);
			DrawPanelText(panel, temp_string14);
			Format(temp_string14, sizeof(temp_string14),"%T", "Medic Human 5", client);
			DrawPanelText(panel, temp_string14);
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Sniper:
		{
			char temp_string15[1024];
			Format(temp_string15, sizeof(temp_string15),"%T", "Sniper Human 1", client);
			SetPanelTitle(panel, temp_string15);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string15, sizeof(temp_string15),"%T", "Sniper Human 2", client);
			DrawPanelText(panel, temp_string15);
			Format(temp_string15, sizeof(temp_string15),"%T", "Sniper Human 3", client);
			DrawPanelText(panel, temp_string15);	 
			DrawPanelText(panel, "-------------------------------------------");
		}	  
		case TFClass_Scout:
		{
			char temp_string16[1024];
			Format(temp_string16, sizeof(temp_string16),"%T", "Scout Zombie 1", client);
			SetPanelTitle(panel, temp_string16);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string16, sizeof(temp_string16),"%T", "Scout Zombie 2", client);
			DrawPanelText(panel, temp_string16);
			Format(temp_string16, sizeof(temp_string16),"%T", "Scout Zombie 3", client);
			DrawPanelText(panel, temp_string16);
			Format(temp_string16, sizeof(temp_string16),"%T", "Scout Zombie 4", client);
			DrawPanelText(panel, temp_string16);
			Format(temp_string16, sizeof(temp_string16),"%T", "Scout Zombie 5", client);
			DrawPanelText(panel, temp_string16);		
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Heavy:
		{
			char temp_string17[1024];
			Format(temp_string17, sizeof(temp_string17),"%T", "Heavy Zombie 1", client);
			SetPanelTitle(panel, temp_string17);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string17, sizeof(temp_string17),"%T", "Heavy Zombie 2", client);
			DrawPanelText(panel, temp_string17);
			Format(temp_string17, sizeof(temp_string17),"%T", "Heavy Zombie 3", client);
			DrawPanelText(panel, temp_string17);
			Format(temp_string17, sizeof(temp_string17),"%T", "Heavy Zombie 4", client);
			DrawPanelText(panel, temp_string17);
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Spy:
		{
			char temp_string18[1024];
			Format(temp_string18, sizeof(temp_string18),"%T", "Spy Zombie 1", client);
			SetPanelTitle(panel, temp_string18);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string18, sizeof(temp_string18),"%T", "Spy Zombie 2", client);
			DrawPanelText(panel, temp_string18);
			Format(temp_string18, sizeof(temp_string18),"%T", "Spy Zombie 3", client);
			DrawPanelText(panel, temp_string18);
			Format(temp_string18, sizeof(temp_string18),"%T", "Spy Zombie 4", client);
			DrawPanelText(panel, temp_string18);
			Format(temp_string18, sizeof(temp_string18),"%T", "Spy Zombie 5", client);
			DrawPanelText(panel, temp_string18);
			DrawPanelText(panel, "-------------------------------------------");
		}		
		default:
		{
			char temp_string19[1024];
			Format(temp_string19, sizeof(temp_string19),"%T", "Unassigned", client);
			SetPanelTitle(panel, temp_string19);
			DrawPanelText(panel, "-------------------------------------------"); 
			Format(temp_string19, sizeof(temp_string19),"%T", "Spectator", client);			
			DrawPanelText(panel, temp_string19);
			DrawPanelText(panel, "-------------------------------------------");
		}
	}
	char temp_string20[512];
	Format(temp_string20, sizeof(temp_string20),"%T", "Return to Help Menu", client);
	DrawPanelItem(panel, temp_string20);
	Format(temp_string20, sizeof(temp_string20),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string20);
	SendPanelToClient(panel, client, panel_HandleClass, 8);
	CloseHandle(panel);
}

public int panel_HandleClass(Handle menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintHelp(param1);
			default: return;	 
		} 
	} 
}

public int dummy_PanelHandler(Handle menu, MenuAction action, int param1, int param2)
{
	return;
}

void SetGlow()
{
	int iCount = GetSurvivorCount();
	int iGlow = 0;
	int iGlow2;
	
	if(iCount >= 1 && iCount <= 3)
		iGlow = 1;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			iGlow2 = iGlow;
			if(GetClientTeam(i) == ZomTeam && g_iSpecialInfected[i] == INFECTED_TANK)
				iGlow2 = 1;
			else if(GetClientTeam(i) == ZomTeam)
				iGlow2 = 0;
			SetEntProp(i, Prop_Send, "m_bGlowEnabled", iGlow2);
		}
	}
}

stock int GetPlayerCount()
{
	int playerCount = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && (GetClientTeam(i) > 1))
		{
			playerCount++;  
		}
	}
	return playerCount;
}

stock int GetSurvivorCount()
{
	int iCount = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validLivingSur(i))
		{
			iCount++;
		}
	}
	return iCount;
}

public void OnSlagChange(int iClient, int iFeature, bool bEnabled)	// ??? Damn private features
{
	if(!bEnabled)
		return;
	
	if(iFeature == 10)
	{
		if(validSur(iClient))
		{
			ForcePlayerSuicide(iClient);
		}
	}
}

void UpdateZombieDamageScale()
{
	g_fZombieDamageScale = 1.0;
	if(!Enabled || g_iStartSurvivors<=0 || roundState()!=RoundActive)
		return;	

	float fTime = 1.0 - GetTimePercentage();
	if(fTime <= 0.0)
		return;

	int iCurrentSurvivors = GetSurvivorCount();
	int iExpectedSurvivors = RoundFloat(float(g_iStartSurvivors) * (SquareRoot(fTime) + fTime)*0.5);
	int iSurvivorDifference = iCurrentSurvivors - iExpectedSurvivors;
	
	// Calculating from survivor difference
	g_fZombieDamageScale = (float(iSurvivorDifference) / float(g_iStartSurvivors)) + 1.0;
	if(g_fZombieDamageScale < 0.0)
		g_fZombieDamageScale = 0.0;
	
	// Calculating from control points
	if(g_bCapturingLastPoint && g_fZombieDamageScale < 1.1)
		g_fZombieDamageScale = 1.1;
	
	if(g_fZombieDamageScale < 1.0)
		g_fZombieDamageScale *= g_fZombieDamageScale;
	if(g_fZombieDamageScale < 0.1)
		g_fZombieDamageScale = 0.1;
	if(g_fZombieDamageScale > 4.0)
		g_fZombieDamageScale = 4.0;
	
	//char strInput[255];
	//Format(strInput, sizeof(strInput), "%d %d {3} {4} message_1", fTime, iExpectedSurvivors, iCurrentSurvivors, g_fZombieDamageScale*100.0);
	//if(g_bCapturingLastPoint) Format(strInput, sizeof(strInput), "{1} message_2", strInput);
	//ShowDebug(strInput);
	
	if(!g_bZombieRage && g_iZombieTank<=0 && !ZombiesHaveTank())
	{
		if(fTime<=GetConVarFloat(cvarTankOnce)*0.01 && !g_bTankOnce && g_fZombieDamageScale>=1.0)
		{
			ZombieTank();
		}
		else if(fTime<=0.05 && fTime>=0.04)
		{
			ZombieRage();
		}
		else if(g_fZombieDamageScale>=1.3 || (GetRandomInt(1, 100)<=GetConVarInt(cvarFrenzyChance) && g_fZombieDamageScale>=1.0))
		{
			if(GetRandomInt(0, 100) <= GetConVarInt(cvarFrenzyTankChance) && g_fZombieDamageScale > 1.0)
				ZombieTank();
			else
				ZombieRage();
		}
	}
}

public Action RespawnPlayer(Handle hTimer, any iClient)
{
	if(IsClientInGame(iClient) && !IsPlayerAlive(iClient))
	{
		TF2_RespawnPlayer(iClient);
		CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnTimeAdded(Handle event, const char[] name, bool dontBroadcast)
{
	int iAddedTime = GetEventInt(event, "seconds_added");
	g_AdditionalTime = g_AdditionalTime + iAddedTime;
}

stock int GetSecondsLeft()
{
	//Get round time that the round started with
	int ent = FindEntityByClassname(MaxClients+1, "team_round_timer");
	float RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	int iRoundStartLength = RoundToZero(RoundStartLength);
	int TimeBuffer = iRoundStartLength + g_AdditionalTime;

	if(g_StartTime <= 0)
		return TimeBuffer;
	
	int SecElapsed = GetTime() - g_StartTime;
	
	int iTimeLeft = TimeBuffer-SecElapsed;
	if(iTimeLeft < 0)
		iTimeLeft = 0;
	if(iTimeLeft > TimeBuffer)
		iTimeLeft = TimeBuffer;
	
	return iTimeLeft;
}  

stock float GetTimePercentage()
{
	//Alright B, play tiemz ovar
	if(g_StartTime <= 0)
		return 0.0;
	int SecElapsed = GetTime() - g_StartTime;
	//PrintToChatAll("%i Seconds have elapsed since the round started", SecElapsed)
	
	//Get round time that the round started with
	int ent = FindEntityByClassname(MaxClients+1, "team_round_timer");
	float RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	//PrintToChatAll("Float:RoundStartLength == %f", RoundStartLength)
	int iRoundStartLength = RoundToZero(RoundStartLength);
	
	
	//g_AdditionalTime = time added this round
	//PrintToChatAll("TimeAdded This Round: %i", g_AdditionalTime)
	
	int TimeBuffer = iRoundStartLength + g_AdditionalTime;
	//int TimeLeft = TimeBuffer - SecElapsed;
	
	float TimePercentage = float(SecElapsed) / float(TimeBuffer);
	//PrintToChatAll("TimeLeft Sec: %i", TimeLeft)
	
	if(TimePercentage < 0.0)
		TimePercentage = 0.0;
	if(TimePercentage > 1.0)
		TimePercentage = 1.0;

	return TimePercentage;
}

public Action OnBroadcast(Handle event, const char[] name, bool dontBroadcast)
{
	char sound[PLATFORM_MAX_PATH];
	GetEventString(event, "sound", sound, sizeof(sound));
	if(!StrContains(sound, "Game.Your", false) || StrEqual(sound, "Game.Stalemate", false))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void CreateZombieSkin(int iClient)
{   
	// Add a new model
	char strModel[PLATFORM_MAX_PATH];
	Format(strModel, sizeof(strModel), "");

	//if(TF2_GetPlayerClass(iClient) == TFClass_Heavy)
		//Format(strModel, sizeof(strModel), "models/player/zombies/heavy.mdl");
	//if(TF2_GetPlayerClass(iClient) == TFClass_Scout)
		//Format(strModel, sizeof(strModel), "models/player/zombies/scout.mdl");
	//if(g_iSpecialInfected[iClient] == INFECTED_TANK) 
		//Format(strModel, sizeof(strModel), "models/infected/hulk.mdl");
	
	if(IsClientInGame(iClient) && IsPlayerAlive(iClient))
	{
		SetVariantString(strModel);
		AcceptEntityInput(iClient, "SetCustomModel");
		if(!StrEqual(strModel, ""))
		{
			SetEntProp(iClient, Prop_Send, "m_bUseClassAnimations",1);
			SetEntProp(iClient, Prop_Send, "m_nBody", 0);
		}
	}
}

public void OnMapStart()
{
	PrecacheZombieModels();
	LoadSoundSystem();
	FastRespawnReset();
	DetermineControlPoints();
	
	//RemovePhysicObjects();
	
	PrecacheParticle("asplode_hoodoo_green");
	PrecacheSound2(SOUND_BONUS);
	
	for(int i = 0; i < sizeof(g_strSoundFleshHit); i++)
	{
		PrecacheSound2(g_strSoundFleshHit[i]);
	}
	
	for(int i = 0; i < sizeof(g_strSoundCritHit); i++)
	{
		PrecacheSound2(g_strSoundCritHit[i]);
	}
	
	for(int i = 0; i < sizeof(g_weaponModels); i++)
	{
		PrecacheModel(g_weaponModels[i]);
	}

	char name[64];
	int entity = -1;
	MapType = 0;
	while((entity = FindEntityByClassname2(entity, "info_target")) != -1)
	{
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
		if(!StrContains(name, "szf_mode_new", false))
		{
			MapType = 1;
		}
	}

	Handle hConvar = FindConVar("slag_map_has_music");

	if(hConvar != INVALID_HANDLE)
		SetConVarBool(hConvar, true);
}

void PrecacheZombieModels()
{
	if(FileExists("materials/left4fortress/goo.vmt", true))
	{
		AddFileToDownloadsTable("materials/left4fortress/goo.vmt");
	}
	
	PrecacheBonus("zombie_assist");
	PrecacheBonus("zombie_kill");
	PrecacheBonus("zombie_kill_2");
	PrecacheBonus("zombie_kill_lot");
	PrecacheBonus("zombie_stab_death");
	
	/*
	PrecacheModel("models/player/zombies/heavy.mdl", true);
	PrecacheModel("models/player/zombies/scout.mdl", true);
	
	AddFileToDownloadsTable("materials/models/player/zombies/skeleton.vmt");
	AddFileToDownloadsTable("materials/models/player/zombies/skeleton.vtf");
	AddFileToDownloadsTable("materials/models/player/zombies/skull.vmt");
	AddFileToDownloadsTable("materials/models/player/zombies/skull.vtf");
	
	AddFileToDownloadsTable("models/player/zombies/heavy.mdl");
	AddFileToDownloadsTable("models/player/zombies/heavy.vvd");
	AddFileToDownloadsTable("models/player/zombies/heavy.sw.vtx");
	AddFileToDownloadsTable("models/player/zombies/heavy.dx90.vtx");
	AddFileToDownloadsTable("models/player/zombies/heavy.dx80.vtx");
	AddFileToDownloadsTable("materials/models/player/zombies/heavy_gib.vmt");
	AddFileToDownloadsTable("materials/models/player/zombies/heavy_gib.vtf");
	
	AddFileToDownloadsTable("models/player/zombies/scout.mdl");
	AddFileToDownloadsTable("models/player/zombies/scout.vvd");
	AddFileToDownloadsTable("models/player/zombies/scout.sw.vtx");
	AddFileToDownloadsTable("models/player/zombies/scout.dx90.vtx");
	AddFileToDownloadsTable("models/player/zombies/scout.dx80.vtx");
	AddFileToDownloadsTable("materials/models/player/zombies/scout_gib.vmt");
	AddFileToDownloadsTable("materials/models/player/zombies/scout_gib.vtf");
	*/
}

/*void ShowDebug(char[] strInput)
{
	int iClient = GetMecha();
	if(iClient > 0)
	{
		SetHudTextParams(0.04, 0.3, 10.0, 50, 255, 50, 255);
		ShowHudText(iClient, 1, strInput);
	}
}*/

stock int GetMecha()	// VSH and SZF did it.. .w. I get you want debug mode but make it for server owners too
{
	return -1;
}

void LoadSoundSystem()
{
	if(g_hMusicArray != INVALID_HANDLE)
		CloseHandle(g_hMusicArray);
	g_hMusicArray = CreateArray();
	
	for(int iLoop = 0; iLoop < sizeof(g_iMusicCount); iLoop++)
	{
		g_iMusicCount[iLoop] = 0;
	}
	
	Handle hKeyvalue = CreateKeyValues("music");
	
	char strValue[PLATFORM_MAX_PATH];
	
	char strPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, strPath, sizeof(strPath), "data/superzombiefortress.txt");
	//LogMessage("Loading sound system: %s", strPath);
	FileToKeyValues(hKeyvalue, strPath);
	KvRewind(hKeyvalue);
	//KeyValuesToFile(hKeyvalue, "test.txt");
	KvGotoFirstSubKey(hKeyvalue);
	do
	{
		Handle hEntry = CreateArray(PLATFORM_MAX_PATH);
		KvGetString(hKeyvalue, "path", strValue, sizeof(strValue), "error");
		PushArrayString(hEntry, strValue);
		
		PrecacheSound2(strValue);
		
		//LogMessage("Found: %s", strValue);
		KvGetString(hKeyvalue, "category", strValue, sizeof(strValue), "error");
		PushArrayString(hEntry, strValue);
		
		int iCategory = MusicCategoryToNumber(strValue);
		//LogMessage("Category: %s (%d)", strValue, iCategory);
		if(iCategory < 0)
		{
			LogError("Invalid music category %d (%s)", iCategory, strValue);
		}
		else
		{
			g_iMusicCount[iCategory]++;
			
			KvGetString(hKeyvalue, "length", strValue, sizeof(strValue), "error");
			PushArrayString(hEntry, strValue);
			PushArrayCell(g_hMusicArray, hEntry);
		}
	}
	while (KvGotoNextKey(hKeyvalue));
	//LogMessage("Done with the sound system");
	
	CloseHandle(hKeyvalue);
}

int MusicCategoryToNumber(char[] strCategory)
{
	if(StrEqual(strCategory, "drums", false))
		return MUSIC_DRUMS;
	if(StrEqual(strCategory, "slayermild", false))
		return MUSIC_SLAYER_MILD;
	if(StrEqual(strCategory, "slayer", false))
		return MUSIC_SLAYER;
	if(StrEqual(strCategory, "trumpet", false))
		return MUSIC_TRUMPET;
	if(StrEqual(strCategory, "snare", false))
		return MUSIC_SNARE;
	if(StrEqual(strCategory, "banjo", false))
		return MUSIC_BANJO;
	if(StrEqual(strCategory, "heartslow", false))
		return MUSIC_HEART_SLOW;
	if(StrEqual(strCategory, "heartmedium", false))
		return MUSIC_HEART_MEDIUM;
	if(StrEqual(strCategory, "heartfast", false))
		return MUSIC_HEART_FAST;
	if(StrEqual(strCategory, "rabies", false))
		return MUSIC_RABIES;
	if(StrEqual(strCategory, "dead", false))
		return MUSIC_DEAD;
	if(StrEqual(strCategory, "incoming", false))
		return MUSIC_INCOMING;
	if(StrEqual(strCategory, "prepare", false))
		return MUSIC_PREPARE;
	if(StrEqual(strCategory, "drown", false))
		return MUSIC_DROWN;
	if(StrEqual(strCategory, "tank", false))
		return MUSIC_TANK;
	if(StrEqual(strCategory, "laststand", false))
		return MUSIC_LASTSTAND;
	if(StrEqual(strCategory, "neardeath", false))
		return MUSIC_NEARDEATH;
	if(StrEqual(strCategory, "neardeath2", false))
		return MUSIC_NEARDEATH2;
	if(StrEqual(strCategory, "award", false))
		return MUSIC_AWARD;
	if(StrEqual(strCategory, "last_ten_seconds", false))
		return MUSIC_LASTTENSECONDS;
	if(StrEqual(strCategory, "win", false))
		return MUSIC_ROUNDWIN;
	if(StrEqual(strCategory, "lose", false))
		return MUSIC_ROUNDLOSE;

	return -1;
}

int MusicChannel(int iMusic)
{
	switch(iMusic)
	{
		case MUSIC_DRUMS, MUSIC_SNARE:
			return CHANNEL_MUSIC_DRUMS;
		case MUSIC_SLAYER_MILD, MUSIC_SLAYER:
			return CHANNEL_MUSIC_SLAYER;
		case MUSIC_TRUMPET, MUSIC_BANJO, MUSIC_HEART_SLOW, MUSIC_HEART_MEDIUM, MUSIC_HEART_FAST, MUSIC_DROWN, MUSIC_TANK, MUSIC_LASTSTAND, MUSIC_LASTTENSECONDS, MUSIC_NEARDEATH:
			return CHANNEL_MUSIC_SINGLE;
		case MUSIC_RABIES, MUSIC_DEAD, MUSIC_INCOMING, MUSIC_PREPARE, MUSIC_NEARDEATH2, MUSIC_AWARD, MUSIC_ROUNDWIN, MUSIC_ROUNDLOSE:
			return CHANNEL_MUSIC_NONE;
	}
	return CHANNEL_MUSIC_DRUMS;
}

void MusicGetPath(int iCategory = MUSIC_DRUMS, int iNumber, char[] strInput, int iMaxSize)
{
	//PrintToChatAll("Attempting to get path for category %d (num %d)", iCategory, iNumber);
	int iCount = 0;
	int iEntryCategory;
	char strValue[PLATFORM_MAX_PATH];
	Handle hEntry;
	for(int i = 0; i < GetArraySize(g_hMusicArray); i++)
	{
		hEntry = GetArrayCell(g_hMusicArray, i);
		GetArrayString(hEntry, 1, strValue, sizeof(strValue));
		iEntryCategory = MusicCategoryToNumber(strValue);
		//PrintToChatAll("Entry category: %s (%d)", strValue, iEntryCategory);
		if(iEntryCategory == iCategory)
		{
			if(iCount == iNumber)
			{
				GetArrayString(hEntry, 0, strInput, iMaxSize);
				return;
			}
			iCount++;
		}
	}
	Format(strInput, iMaxSize, "error");
	return;
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i)) StopSoundSystem(i);
	}
}

void StopSoundSystem(int iClient, bool bLogic = true, bool bMusic = true, bool bConsiderFull = false, int iLevel = MUSIC_NONE)
{
	if(bMusic)
	{
		StopSound2(iClient, MUSIC_SLAYER_MILD);
		StopSound2(iClient, MUSIC_SLAYER);
		StopSound2(iClient, MUSIC_TRUMPET);
		StopSound2(iClient, MUSIC_HEART_MEDIUM);
		StopSound2(iClient, MUSIC_HEART_FAST);
		if((!bConsiderFull) || (g_iMusicFull[iClient] % 2 == 0))
		{
			StopSound2(iClient, MUSIC_DRUMS);
			StopSound2(iClient, MUSIC_SNARE);
			StopSound2(iClient, MUSIC_BANJO);
			StopSound2(iClient, MUSIC_HEART_SLOW);
		}
		if((!bConsiderFull) || (g_iMusicFull[iClient] % 4 == 0))
		{
			StopSound2(iClient, MUSIC_DROWN);
		}
		if(!bConsiderFull)
		{
			StopSound2(iClient, MUSIC_TANK);
			StopSound2(iClient, MUSIC_LASTSTAND);
			StopSound2(iClient, MUSIC_LASTTENSECONDS);
			StopSound2(iClient, MUSIC_NEARDEATH);
		}
	}
	if(bLogic)
	{
		//PrintToChatAll("Killed timer");
		Handle hTimer = g_hMusicTimer[iClient];
		g_hMusicTimer[iClient] = INVALID_HANDLE;
		g_iMusicLevel[iClient] = MUSIC_NONE;
		
		if(MusicCanReset(iLevel))
		{
			g_iMusicRandom[iClient][0] = -1;
			g_iMusicRandom[iClient][1] = -1;
		}
		
		g_iMusicFull[iClient] = 0;
		
		if(hTimer != INVALID_HANDLE)
			KillTimer(hTimer);
	}
}

void StopSound2(int iClient, int iMusic)
{
	if(StrEqual(g_strMusicLast[iClient][iMusic], ""))
		return;
	
	int iChannel = MusicChannel(iMusic);
	StopSound(iClient, iChannel, g_strMusicLast[iClient][iMusic]);
	
	Format(g_strMusicLast[iClient][iMusic], PLATFORM_MAX_PATH, "");
}

void StartSoundSystem(int iClient, int iLevel = -1)
{
	if(iLevel == -1)
		iLevel = g_iMusicLevel[iClient];
	
	StopSoundSystem(iClient, false, true, true, iLevel);
	
	//PrintToChatAll("Emitting");
	
	if(g_iMusicLevel[iClient] != iLevel)
	{
		StopSoundSystem(iClient, true, true, _, iLevel);
		g_iMusicLevel[iClient] = iLevel;
		if(iLevel != MUSIC_NONE)
		{
			g_hMusicTimer[iClient] = CreateTimer(2.8, SoundSystemRepeat, iClient, TIMER_REPEAT);
		}
	}
	
	if(iLevel == MUSIC_GOO)
	{
		StartSoundSystem2(iClient, MUSIC_DROWN);
	}
	if(iLevel == MUSIC_TANKMOOD)
	{
		StartSoundSystem2(iClient, MUSIC_TANK);
	}
	if(iLevel == MUSIC_LASTSTANDMOOD)
	{
		StartSoundSystem2(iClient, MUSIC_LASTSTAND);
	}
	if(iLevel == MUSIC_LASTTENSECONDSMOOD)
	{
		StartSoundSystem2(iClient, MUSIC_LASTTENSECONDS);
	}
	
	if(iLevel == MUSIC_PLAYERNEARDEATH)
	{
		StartSoundSystem2(iClient, MUSIC_NEARDEATH);
	}
	if(iLevel == MUSIC_INTENSE)
	{
		int iRandom = GetClientRandom(iClient, 0, 0, 1);
		StartSoundSystem2(iClient, MUSIC_SLAYER);
		if(iRandom == 0)
			StartSoundSystem2(iClient, MUSIC_BANJO);
		else
			StartSoundSystem2(iClient, MUSIC_DRUMS);
	}
	if(iLevel == MUSIC_MILD)
	{
		int iRandom = GetClientRandom(iClient, 0, 0, 1);
		int iRandom2 = GetClientRandom(iClient, 1, 0, 1);
		
		if(iRandom == 0)
			StartSoundSystem2(iClient, MUSIC_SLAYER_MILD);
		else
			StartSoundSystem2(iClient, MUSIC_TRUMPET);
		
		if(iRandom2 == 0)
			StartSoundSystem2(iClient, MUSIC_DRUMS);
		else
			StartSoundSystem2(iClient, MUSIC_SNARE);
	}
	if(iLevel == MUSIC_VERYMILD1)
	{
		StartSoundSystem2(iClient, MUSIC_HEART_SLOW);
	}
	if(iLevel == MUSIC_VERYMILD2)
	{
		StartSoundSystem2(iClient, MUSIC_HEART_MEDIUM);
	}
	if(iLevel == MUSIC_VERYMILD3)
	{
		StartSoundSystem2(iClient, MUSIC_HEART_FAST);
	}
	
	g_iMusicFull[iClient]++;
}

public Action SoundSystemRepeat(Handle hTimer, any iClient)
{
	if(!IsClientInGame(iClient))
	{
		g_hMusicTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	StartSoundSystem(iClient);
	return Plugin_Continue;
}

void StartSoundSystem2(int iClient, int iMusic)
{
	if(g_iMusicFull[iClient] % 2 != 0)
	{
		if(iMusic==MUSIC_DRUMS || iMusic==MUSIC_SNARE || iMusic==MUSIC_BANJO || iMusic==MUSIC_HEART_SLOW)
			return;
	}
	if(g_iMusicFull[iClient] % 4 != 0)
	{
		if(iMusic == MUSIC_DROWN)
			return;
	}
	if(g_iMusicFull[iClient] != 0)
	{
		if(iMusic==MUSIC_TANK || iMusic==MUSIC_LASTSTAND || iMusic==MUSIC_LASTTENSECONDS || iMusic==MUSIC_NEARDEATH)
			return;
	}
	
	int iRandom = GetRandomInt(0, g_iMusicCount[iMusic]-1);
	char strPath[PLATFORM_MAX_PATH];
	MusicGetPath(iMusic, iRandom, strPath, sizeof(strPath));
	//PrintToChatAll("Emitting: %s", strPath);
	int iChannel = MusicChannel(iMusic);
	EmitSoundToClient(iClient, strPath, _, iChannel, _, _, 1.0);
	Format(g_strMusicLast[iClient][iMusic], PLATFORM_MAX_PATH, "%s", strPath);
}

bool ShouldHearEventSounds(int iClient)
{
	if(g_iMusicLevel[iClient]==MUSIC_INTENSE || g_iMusicLevel[iClient]==MUSIC_MILD)
		return false;

	return true;
}

int GetClientRandom(int iClient, int iNumber, int iMin, int iMax)
{
	if(g_iMusicRandom[iClient][iNumber] >= 0)
		return g_iMusicRandom[iClient][iNumber];
	int iRandom = GetRandomInt(iMin, iMax);
	g_iMusicRandom[iClient][iNumber] = iRandom;
	return iRandom;
}

stock void PrecacheSound2(char[] strSound)
{
	char strPath[PLATFORM_MAX_PATH];
	Format(strPath, sizeof(strPath), "sound/%s", strSound);
	
	PrecacheSound(strSound, true);
	AddFileToDownloadsTable(strPath);
}

void ZombieRage(bool bBeginning = false)
{
	if(roundState() != RoundActive)
		return;
	if(g_bZombieRage)
		return;
	if(ZombiesHaveTank())
		return;
	
	g_bZombieRage = true;
	g_bZombieRageAllowRespawn = true;
	if(bBeginning) g_bZombieRageAllowRespawn = false;
	
	CreateTimer(20.0, StopZombieRage);
	
	//PrintToChatAll("Zombie rage");
	
	if(!bBeginning)
	{
		int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_INCOMING]-1);
		char strPath[PLATFORM_MAX_PATH];
		MusicGetPath(MUSIC_INCOMING, iRandom, strPath, sizeof(strPath));
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(ShouldHearEventSounds(i))
				{
					EmitSoundToClient(i, strPath, _, SNDLEVEL_AIRCRAFT);
				}
				if(GetClientTeam(i)==ZomTeam)
				{
					CPrintToChat(i, "{olive}[SZF]{default} %t", "Frenzy");
				}
				if(GetClientTeam(i)==ZomTeam && !IsPlayerAlive(i))
				{
					TF2_RespawnPlayer(i);
					CreateTimer(0.1, timer_postSpawn, i, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public Action StopZombieRage(Handle hTimer)
{
	g_bZombieRage = false;
	UpdateZombieDamageScale();
	
	if(roundState() == RoundActive)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i)==ZomTeam)
			{
				CPrintToChat(i, "{olive}[SZF]{default} %t", "Rest");
			}
		}
	}
}

public Action SpookySound(Handle hTimer)
{
	if(roundState() != RoundActive)
		return;
	
	int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_RABIES]-1);
	char strPath[PLATFORM_MAX_PATH];
	MusicGetPath(MUSIC_RABIES, iRandom, strPath, sizeof(strPath));
	
	int iTarget = -1;
	int iFail = 0;
	do
	{
		iTarget = GetRandomInt(1, MaxClients);
		iFail++;
	}
	while((!IsClientInGame(iTarget) || !IsPlayerAlive(iTarget) || !ShouldHearEventSounds(iTarget) || !validActivePlayer(iTarget)) && iFail < 100);
	
	if(IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && validActivePlayer(iTarget))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && ShouldHearEventSounds(i) && i != iTarget && GetClientTeam(client)==OtherTeam)
				EmitSoundToClient(i, strPath, iTarget);
		}
	}
}

stock void EmitSoundFromOrigin(const char[] sound, const float orig[3], int iLevel = SNDLEVEL_NORMAL)
{
	EmitSoundToAll(sound, SOUND_FROM_WORLD, SNDCHAN_AUTO, iLevel, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, orig, NULL_VECTOR, true, 0.0);
}

float GetZombieNumber(int iClient)
{
	float fPosClient[3];
	float fPosZombie[3];
	GetClientEyePosition(iClient, fPosClient);
	float fDistance;
	float fZombieNumber = 0.0;
	for(int z=1; z<=MaxClients; z++)
	{
		if(IsClientInGame(z) && IsPlayerAlive(z) && GetClientTeam(z)==ZomTeam)
		{
			GetClientEyePosition(z, fPosZombie);
			fDistance = GetVectorDistance(fPosClient, fPosZombie);
			fDistance /= 50.0;
			if(fDistance <= 20.0)
			{
				fDistance = 20.0 - fDistance;
				if(fDistance >= 15.0) 
					fDistance = 15.0;
				fZombieNumber += fDistance;
			}
		}
	}
	fZombieNumber *= 1.2;
	return fZombieNumber;
}

void MusicHandleAll()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		MusicHandleClient(iClient);
	}
}

void MusicHandleClient(int iClient)
{
	if(!validClient(iClient))
		return;
	
	if(GetClientTeam(iClient) == 1)
	{
		int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		if(validActivePlayer(iTarget))
		{
			StartSoundSystem(iClient, g_iMusicLevel[iTarget]);
		}
		else
		{
			StartSoundSystem(iClient, MUSIC_NONE);
		}
	}
	else
	{
		/*
			Scared need to involve the following:
			Client health
			number of zombies surrounding him
			Zombie Rage
			
			NONE			0
			VERYMILD1   >= 10
			VERYMILD2   >= 30
			VERYMILD3   >= 50
			MILD		>= 70
			INTENSE	 >= 100
			
			Zombie calculation
			Zombies within 10 meters are counted
			The total inverted distance of all the zombies. ie 10 for a zombie right up your face.
			
			Scared = ZombieNum * 3 / Health% + Rage*20
		*/
		int iCurrentHealth = GetClientHealth(iClient);
		int iMaxHealth = GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
		float fHealth = float(iCurrentHealth) / float(iMaxHealth);
		if(fHealth < 0.5)
			fHealth = 0.5;
		if(fHealth > 1.1)
			fHealth = 1.1;
		
		float fRage = 0.0;
		if(g_bZombieRage)
			fRage = 1.0;
		
		float fZombies = GetZombieNumber(iClient);
		
		float fScared = fZombies / fHealth + fRage * 20.0;
		
		/*
		if(IsMecha(iClient))
		{
			char strInput[255];
			Format(strInput, sizeof(strInput), "Zombies: %.1f\nHealth: %.1f\nScared: %.1f", fZombies, fHealth, fScared);
			SetHudTextParams(0.04, 0.5, 10.0, 50, 255, 50, 255);
			ShowHudText(iClient, 1, strInput);
		}
		*/
		
		int iMusic = MUSIC_NONE;
		if(GetClientTeam(iClient) == OtherTeam)
		{
			if(g_bRoundActive)
			{
				if(fScared >= 5.0)
					iMusic = MUSIC_VERYMILD1;
				if(fScared >= 30.0)
					iMusic = MUSIC_VERYMILD2;
				if(fScared >= 50.0)
					iMusic = MUSIC_VERYMILD3;
				if(fScared >= 70.0)
					iMusic = MUSIC_MILD;
			}
			
			if(g_bGooified[iClient])
				iMusic = MUSIC_GOO;
			
			if(g_bRoundActive)
			{
				if(fScared >= 100.0)
					iMusic = MUSIC_INTENSE;
			}
		}
		
		// Applies for all
		if(g_bRoundActive)
		{
			if(ZombiesHaveTank() && iMusic!=MUSIC_GOO)
				iMusic = MUSIC_TANKMOOD;
			if(GetSurvivorCount()==1 || g_bCapturingLastPoint)
				iMusic = MUSIC_LASTSTANDMOOD;
		}
		if(g_bBackstabbed[iClient])
		{
			iMusic = MUSIC_PLAYERNEARDEATH;
		}
		if(g_bRoundActive)
		{
			if(GetSecondsLeft() <= 9)
				iMusic = MUSIC_LASTTENSECONDSMOOD;
		}
		
		StartSoundSystem(iClient, iMusic);
	}
}

public Action command_rabies(int client, int args)
{
	if(!Enabled)
		return Plugin_Continue;

	CreateTimer(0.0, SpookySound);
	PrintToConsole(client, "Called rabies");
			
	return Plugin_Continue;
}

public Action command_goo(int client, int args)
{
	if(!Enabled)
		return Plugin_Continue;

	SpitterGoo(client);
			
	return Plugin_Continue;
}

void FastRespawnReset()
{
	if(g_hFastRespawnArray != INVALID_HANDLE)
		CloseHandle(g_hFastRespawnArray);
	g_hFastRespawnArray = CreateArray(3);
}

int FastRespawnNearby(int iClient, float fDistance, bool bMustBeInvisible = true)
{
	if(g_hFastRespawnArray == INVALID_HANDLE)
		return -1;
	
	Handle hTombola = CreateArray();
	
	float fPosClient[3];
	float fPosEntry[3];
	float fPosEntry2[3];
	float fEntryDistance;
	GetClientAbsOrigin(iClient, fPosClient);
	for(int i = 0; i < GetArraySize(g_hFastRespawnArray); i++)
	{
		GetArrayArray(g_hFastRespawnArray, i, fPosEntry);
		fPosEntry2[0] = fPosEntry[0];
		fPosEntry2[1] = fPosEntry[1];
		fPosEntry2[2] = fPosEntry[2] += 90.0;
		
		bool bAllow = true;
		
		fEntryDistance = GetVectorDistance(fPosClient, fPosEntry);
		fEntryDistance /= 50.0;
		if(fEntryDistance > fDistance) bAllow = false;
		
		// check if survivors can see it
		if(bMustBeInvisible && bAllow)
		{
			for(int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
			{
				if(validLivingSur(iSurvivor))
				{
					if(PointsAtTarget(fPosEntry, iSurvivor) || PointsAtTarget(fPosEntry2, iSurvivor))
						bAllow = false;
				}
			}
		}
		
		if(bAllow)
		{
			PushArrayCell(hTombola, i);
		}
	}
	
	if(GetArraySize(hTombola) > 0)
	{
		int iRandom = GetRandomInt(0, GetArraySize(hTombola)-1);
		int iResult = GetArrayCell(hTombola, iRandom);
		CloseHandle(hTombola);
		return iResult;
	}
	else
	{
		CloseHandle(hTombola);
	}
	return -1;
}

bool PerformFastRespawn(int iClient)
{
	if(!g_bZombieRage || !g_bZombieRageAllowRespawn)
		return false;
	
	return PerformFastRespawn2(iClient);
}

bool PerformFastRespawn2(int iClient)
{	
	// first let's find a target
	Handle hTombola = CreateArray();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validLivingSur(i))
			PushArrayCell(hTombola, i);
	}
	
	if(GetArraySize(hTombola) <= 0)
	{
		CloseHandle(hTombola);
		return false;
	}
	
	int iTarget = GetArrayCell(hTombola, GetRandomInt(0, GetArraySize(hTombola)-1));
	CloseHandle(hTombola);
	
	int iResult = FastRespawnNearby(iTarget, 7.0);
	if(iResult < 0)
		return false;
	
	float fPosSpawn[3], fPosTarget[3], fAngle[3];
	GetArrayArray(g_hFastRespawnArray, iResult, fPosSpawn);
	GetClientAbsOrigin(iTarget, fPosTarget);
	VectorTowards(fPosSpawn, fPosTarget, fAngle);
	
	TeleportEntity(iClient, fPosSpawn, fAngle, NULL_VECTOR);
	return true;
}

void FastRespawnDataCollect()
{
	if(g_hFastRespawnArray == INVALID_HANDLE) FastRespawnReset();
	
	float fPos[3];
	for(int iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient) && validActivePlayer(iClient) && FastRespawnNearby(iClient, 1.0, false)<0 && !(GetEntityFlags(iClient) & FL_DUCKING == FL_DUCKING) && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND))
		{
			GetClientAbsOrigin(iClient, fPos);
			PushArrayArray(g_hFastRespawnArray, fPos);
		}
	}
}

stock void VectorTowards(float vOrigin[3], float vTarget[3], float vAngle[3])
{
	float vResults[3];
	
	MakeVectorFromPoints(vOrigin, vTarget, vResults);
	GetVectorAngles(vResults, vAngle);
}

stock bool PointsAtTarget(float fBeginPos[3], any iTarget)
{
	float fTargetPos[3];
	GetClientEyePosition(iTarget, fTargetPos);
	
	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(fBeginPos, fTargetPos, MASK_VISIBLE, RayType_EndPoint, TraceDontHitOtherEntities, iTarget);
	
	int iHit = -1;
	if(TR_DidHit(hTrace))
		iHit = TR_GetEntityIndex(hTrace);
	
	CloseHandle(hTrace);
	return (iHit == iTarget);
}

public bool TraceDontHitOtherEntities(int iEntity, int iMask, any iData)
{
	if(iEntity == iData)
		return true;
	if(iEntity > 0)
		return false;

	return true;
}

public bool TraceDontHitEntity(int iEntity, int iMask, any iData)
{
	if(iEntity == iData)
		return false;

	return true;
}

stock bool CanRecieveDamage(int iClient)
{
	if(iClient<=0 || !IsClientInGame(iClient))
		return true;

	if(isUbered(iClient) || isBonked(iClient))
		return false;

	return true;
}

stock int GetClientPointVisible(int iClient)
{
	float vOrigin[3], vAngles[3], vEndOrigin[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);
	
	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceDontHitEntity, iClient);
	TR_GetEndPosition(vEndOrigin, hTrace);
	
	int iReturn = -1;
	int iHit = TR_GetEntityIndex(hTrace);
	
	if(TR_DidHit(hTrace) && iHit!=iClient && (GetVectorDistance(vOrigin, vEndOrigin)/50.0)<=2.0)
	{
		iReturn = iHit;
	}
	CloseHandle(hTrace);
	
	return iReturn;
}

stock bool ObstancleBetweenEntities(int iEntity1, int iEntity2)
{
	float vOrigin1[3], vOrigin2[3];
	
	if(validClient(iEntity1))
	{
		GetClientEyePosition(iEntity1, vOrigin1);
	}
	else
	{
		GetEntPropVector(iEntity1, Prop_Send, "m_vecOrigin", vOrigin1);
	}
	GetEntPropVector(iEntity2, Prop_Send, "m_vecOrigin", vOrigin2);
	
	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin1, vOrigin2, MASK_ALL, RayType_EndPoint, TraceDontHitEntity, iEntity1);
	
	bool bHit = TR_DidHit(hTrace);
	int iHit = TR_GetEntityIndex(hTrace);
	CloseHandle(hTrace);
	
	if(!bHit || iHit!=iEntity2)
		return true;
	
	return false;
}

void HandleClientInventory(int iClient)
{
	if(iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_iMode == GAMEMODE_NEW)
	{
		TF2_RemoveWeaponSlot(iClient, 0);
		TF2_RemoveWeaponSlot(iClient, 1);
		RemoveSecondaryWearable(iClient);
	}
	
	CheckStartWeapons();
}

void SpitterGoo(int iClient, int iAttacker = 0)
{
	if(roundState() != RoundActive)
		return;

	//PrintToChatAll("Spitter goo at %N!", iClient);
	
	if(g_hGoo == INVALID_HANDLE)
		g_hGoo = CreateArray(5);
	
	float fClientPos[3], fClientEye[3];
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyeAngles(iClient, fClientEye);
	
	g_iGooId++;	
	int iEntry[5];
	iEntry[0] = RoundFloat(fClientPos[0]);
	iEntry[1] = RoundFloat(fClientPos[1]);
	iEntry[2] = RoundFloat(fClientPos[2]);
	iEntry[3] = iAttacker;
	iEntry[4] = g_iGooId;
	PushArrayArray(g_hGoo, iEntry);
	
	//ShowParticle("asplode_hoodoo_dust", TIME_GOO, fClientPos, fClientEye);
	ShowParticle("asplode_hoodoo_green", TIME_GOO, fClientPos, fClientEye);
	//ShowParticle("cinefx_goldrush_smoke", TIME_GOO, fClientPos, fClientEye);
	//fClientEye[1] *= -1.0;
	//ShowParticle("cinefx_goldrush_smoke", TIME_GOO, fClientPos);
	
	CreateTimer(TIME_GOO, GooExpire, g_iGooId);
	CreateTimer(1.0, GooEffect, g_iGooId, TIMER_REPEAT);
}

void GooDamageCheck()
{
	float fPosGoo[3];
	int iEntry[5];
	float fPosClient[3]; 
	float fDistance;
	int iAttacker;
	
	bool bWasGooified[MAXPLAYERS+1];
	
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		bWasGooified[iClient] = g_bGooified[iClient];
		g_bGooified[iClient] = false;
	}
	
	if(g_hGoo != INVALID_HANDLE)
	{
		for(int i = 0; i < GetArraySize(g_hGoo); i++)
		{
			GetArrayArray(g_hGoo, i, iEntry);
			fPosGoo[0] = float(iEntry[0]);
			fPosGoo[1] = float(iEntry[1]);
			fPosGoo[2] = float(iEntry[2]);
			iAttacker = iEntry[3];
			
			for(int iClient = 1; iClient <= MaxClients; iClient++)
			{
				if(validLivingSur(iClient) && !g_bGooified[iClient] && CanRecieveDamage(iClient) && !g_bBackstabbed[iClient])
				{
					GetClientEyePosition(iClient, fPosClient);
					fDistance = GetVectorDistance(fPosGoo, fPosClient) / 50.0;
					if(fDistance <= DISTANCE_GOO)
					{
						// deal damage
						g_iGooMultiplier[iClient] += GOO_INCREASE_RATE;
						float fPercentageDistance = (DISTANCE_GOO-fDistance) / DISTANCE_GOO;
						if(fPercentageDistance < 0.5)
							fPercentageDistance = 0.5;
						float fDamage = view_as<float>(g_iGooMultiplier[iClient]/GOO_INCREASE_RATE * fPercentageDistance);
						if(fDamage < 1.0)
							fDamage = 1.0;
						int iDamage = RoundFloat(fDamage);
						DealDamage(iClient, iDamage, iAttacker, _, "projectile_stun_ball");
						g_bGooified[iClient] = true;
						
						int random;
						if(fDamage >= 7.0)
						{
							random = GetRandomInt(0, sizeof(g_strSoundCritHit)-1);
							EmitSoundToClient(iClient, g_strSoundCritHit[random], _, SNDLEVEL_AIRCRAFT);
						}
						else
						{
							random = GetRandomInt(0, sizeof(g_strSoundFleshHit)-1);
							EmitSoundToClient(iClient, g_strSoundFleshHit[random], _, SNDLEVEL_AIRCRAFT);
						}
					}
				}
			}  
		}
	}
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			if(validActivePlayer(iClient) && !g_bGooified[iClient] && g_iGooMultiplier[iClient] > 0)
			{
				g_iGooMultiplier[iClient]--;
			}
			
			//ScreenFade(client, red, green, blue, alpha, delay, type)
			if(!bWasGooified[iClient] && g_bGooified[iClient] && IsPlayerAlive(iClient))
			{
				// fade screen slightly green
				ClientCommand(iClient, "r_screenoverlay\"left4fortress/goo\"");
				MusicHandleClient(iClient);
				//PrintToChat(iClient, "You got goo'd!");
			}
			if(bWasGooified[iClient] && !g_bGooified[iClient])
			{
				// fade screen slightly green
				ClientCommand(iClient, "r_screenoverlay\"\"");
				MusicHandleClient(iClient);
				//PrintToChat(iClient, "You are no longer goo'd!");
			}
		}
	}
}

public Action GooExpire(Handle hTimer, any iGoo)
{
	if(g_hGoo == INVALID_HANDLE)
		return;
	
	int iEntry[5];
	int iEntryId;
	for(int i = 0; i < GetArraySize(g_hGoo); i++)
	{
		GetArrayArray(g_hGoo, i, iEntry);
		iEntryId = iEntry[4];
		if(iEntryId == iGoo)
		{
			RemoveFromArray(g_hGoo, i);
		}
		return;
	}
}

void RemoveAllGoo()
{
	if(g_hGoo == INVALID_HANDLE)
		return;
	
	ClearArray(g_hGoo);
}

public Action GooEffect(Handle hTimer, any iGoo)
{
	if(g_hGoo == INVALID_HANDLE)
		return Plugin_Stop;
	
	int iEntry[5];
	float fPos[3];
	int iEntryId;
	for(int i = 0; i < GetArraySize(g_hGoo); i++)
	{
		GetArrayArray(g_hGoo, i, iEntry);
		iEntryId = iEntry[4];
		fPos[0] = float(iEntry[0]);
		fPos[1] = float(iEntry[1]);
		fPos[2] = float(iEntry[2]);
		if(iEntryId == iGoo)
		{
			ShowParticle("asplode_hoodoo_green", TIME_GOO, fPos);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public void OnEntityCreated(int iEntity, const char[] strClassname)
{
	if(StrEqual(strClassname, "tf_projectile_stun_ball", false))
	{
		SDKHook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKHook(iEntity, SDKHook_Touch, BallTouch);
	}
}

public Action BallStartTouch(int iEntity, int iOther)
{
	if(!Enabled || !IsClassname(iEntity, "tf_projectile_stun_ball"))
		return Plugin_Continue;
	
	if(iOther > 0 && iOther <= MaxClients && IsClientInGame(iOther) && IsPlayerAlive(iOther) && GetClientTeam(iOther)==OtherTeam)
	{
		int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		if(!(GetEntityFlags(iEntity) & FL_ONGROUND))
		{
			SpitterGoo(iOther, iOwner);
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action BallTouch(int iEntity, int iOther)
{
	if(!Enabled || !IsClassname(iEntity, "tf_projectile_stun_ball"))
		return Plugin_Continue;
	
	if(iOther > 0 && iOther <= MaxClients && IsClientInGame(iOther) && IsPlayerAlive(iOther) && GetClientTeam(iOther)==OtherTeam)
	{
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKUnhook(iEntity, SDKHook_Touch, BallTouch);
		AcceptEntityInput(iEntity, "kill");
	}
	
	return Plugin_Stop;
}

stock int ShowParticle(char[] particlename, float time, float pos[3], float ang[3]=NULL_VECTOR)
{
	int particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
		return -1;
	}
	return particle;
}

stock void PrecacheParticle(char[] strName)
{
	if(IsValidEntity(0))
	{
		int iParticle = CreateEntityByName("info_particle_system");
		if(IsValidEdict(iParticle))
		{
			char tName[32];
			GetEntPropString(0, Prop_Data, "m_iName", tName, sizeof(tName));
			DispatchKeyValue(iParticle, "targetname", "tf2particle");
			DispatchKeyValue(iParticle, "parentname", tName);
			DispatchKeyValue(iParticle, "effect_name", strName);
			DispatchSpawn(iParticle);
			SetVariantString(tName);
			AcceptEntityInput(iParticle, "SetParent", 0, iParticle, 0);
			ActivateEntity(iParticle);
			AcceptEntityInput(iParticle, "start");
			CreateTimer(0.01, RemoveParticle, iParticle);
		}
	}
}

public Action RemoveParticle(Handle timer, any particle)
{
	if(particle >= 0 && IsValidEntity(particle))
	{
		char classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if(StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "Kill");
			particle = -1;
		}
	}
}

stock void DealDamage(int iVictim, int iDamage, int iAttacker=0, int iDmgType=DMG_GENERIC, char[] strWeapon="")
{
	if(!validClient(iAttacker))
		iAttacker = 0;

	if(validClient(iVictim) && iDamage > 0)
	{
		char strDamage[16];
		IntToString(iDamage, strDamage, 16);
		char strDamageType[32];
		IntToString(iDmgType, strDamageType, 32);
		int iHurt = CreateEntityByName("point_hurt");
		if(iHurt > 0 && IsValidEdict(iHurt))
		{
			DispatchKeyValue(iVictim,"targetname","infectious_hurtme");
			DispatchKeyValue(iHurt,"DamageTarget","infectious_hurtme");
			DispatchKeyValue(iHurt,"Damage",strDamage);
			DispatchKeyValue(iHurt,"DamageType",strDamageType);
			if(!StrEqual(strWeapon, ""))
			{
				DispatchKeyValue(iHurt,"classname", strWeapon);
			}
			DispatchSpawn(iHurt);
			AcceptEntityInput(iHurt,"Hurt", iAttacker);
			DispatchKeyValue(iHurt,"classname","point_hurt");
			DispatchKeyValue(iVictim,"targetname","infectious_donthurtme");
			RemoveEdict(iHurt);
		}
	}
}

int GetMostDamageZom()
{
	Handle hArray = CreateArray();
	int iHighest = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validZom(i))
		{
			if(g_iDamage[i] > iHighest) iHighest = g_iDamage[i];
		}
	}
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validZom(i) && g_iDamage[i] >= iHighest)
		{
			PushArrayCell(hArray, i);
		}
	}
	
	if(GetArraySize(hArray) <= 0)
	{
		CloseHandle(hArray);
		return 0;
	}
	
	int iClient = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray)-1));
	CloseHandle(hArray);
	return iClient;
}

bool ZombiesHaveTank()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validLivingZom(i) && g_iSpecialInfected[i] == INFECTED_TANK)
			return true;
	}
	return false;
}

void ZombieTank(int iCaller = 0)
{
	if(!Enabled || roundState()!=RoundActive) 
		return;
	
	if(ZombiesHaveTank())
	{
		if(validClient(iCaller))
			CPrintToChat(iCaller, "{olive}[SZF]{default} %t", "Tank Deny Active");
		return;
	}
	if(g_iZombieTank > 0)
	{   
		if(validClient(iCaller))
			CPrintToChat(iCaller, "{olive}[SZF]{default} %t","Tank Deny Ready");
		return;
	}
	if(g_bZombieRage)
	{
		if(validClient(iCaller))
			CPrintToChat(iCaller, "{olive}[SZF]{default} %t","Tank Deny Frenzy");
		return;
	}
	
	g_iZombieTank = GetMostDamageZom();
	if(g_iZombieTank <= 0)
		return;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validZom(i))
		{
			CPrintToChat(i, "{olive}[SZF]{default} %t", "Tank Choosen", g_iZombieTank);
		}
	}
	if(validClient(iCaller))
	{
		CPrintToChat(iCaller, "{olive}[SZF]{default} %t", "Called tank");
	}
	
	g_bTankOnce = true;
}

public Action command_tank(int client, int args)
{
	if(!Enabled)
		return Plugin_Handled;
	if(ZombiesHaveTank())
		return Plugin_Handled;
	if(g_iZombieTank > 0)
		return Plugin_Handled;
	if(g_bZombieRage)
		return Plugin_Handled;

	g_iZombieTank = client;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validZom(i))
		{
			CPrintToChat(i, "%t", "{olive}[SZF]{default} %t", "Tank Choosen", g_iZombieTank);
		}
	}
			
	return Plugin_Handled;
}

bool TankCanReplace(int iClient)
{
	if(g_iZombieTank <= 0)
		return false;
	if(g_iZombieTank == iClient)
		return false;
	if(g_iSpecialInfected[iClient] != INFECTED_NONE)
		return false;
	if(TF2_GetPlayerClass(iClient) != TF2_GetPlayerClass(g_iZombieTank))
		return false;
	
	int iHealth = GetClientHealth(g_iZombieTank);
	float fPos[3];
	float fAng[3];
	float fVel[3];
	
	GetClientAbsOrigin(g_iZombieTank, fPos);
	GetClientAbsAngles(g_iZombieTank, fVel);
	GetEntPropVector(g_iZombieTank, Prop_Data, "m_vecVelocity", fVel);
	SetEntityHealth(iClient, iHealth);
	TeleportEntity(iClient, fPos, fAng, fVel);
	
	TF2_RespawnPlayer(g_iZombieTank);
	CreateTimer(0.1, timer_postSpawn, g_iZombieTank, TIMER_FLAG_NO_MAPCHANGE);
	
	return true;
}

public Action command_tank_random(int client, int args)
{
	if(!Enabled)
		return Plugin_Handled;
	ZombieTank(client);
			
	return Plugin_Handled;
}

public void CacheWeapons()
{
	char config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", DataPath, WeaponCFG);
	
	if(!FileExists(config))
	{
		LogError("[SZF] Can not find '%s'!", WeaponCFG);
		return;
	}
	
	kvWeaponMods = CreateKeyValues("Weapons");
	if(!FileToKeyValues(kvWeaponMods, config))
	{
		LogError("[SZF] '%s' is improperly formatted!", WeaponCFG);
		return;
	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &item)
{
	if(GetClientTeam(client) == ZomTeam)
	{
		#if defined _tf2idb_included
		if(TF2IDB_GetItemSlot(iItemDefinitionIndex) == 6)
		{
			switch(TF2_GetPlayerClass(client))
			{
				case TFClass_Scout:
					iItemDefinitionIndex = 5617;

				case TFClass_Soldier:
					iItemDefinitionIndex = 5618;

				case TFClass_Pyro:
					iItemDefinitionIndex = 5624;

				case TFClass_DemoMan:
					iItemDefinitionIndex = 5620;

				case TFClass_Heavy:
					iItemDefinitionIndex = 5619;

				case TFClass_Engineer:
					iItemDefinitionIndex = 5621;

				case TFClass_Medic:
					iItemDefinitionIndex = 5622;

				case TFClass_Sniper:
					iItemDefinitionIndex = 5625;

				case TFClass_Spy:
					iItemDefinitionIndex = 5625;

				default:
					return Plugin_Continue;
			}

			Handle itemOverride = PrepareItemHandle(item, _, iItemDefinitionIndex, "448 ; 1 ; 450 ; 1");
			if(itemOverride != INVALID_HANDLE)
			{
				item = itemOverride;
				return Plugin_Changed;
			}
		}
		#endif
	}
	else if(kvWeaponMods != null)
	{
		char weapon[64], wepIndexStr[768], attributes[768];
		for(int i=1; ; i++)
		{
			KvRewind(kvWeaponMods);
			Format(weapon, 10, "weapon%i", i);
			if(KvJumpToKey(kvWeaponMods, weapon))
			{
				int isOverride=KvGetNum(kvWeaponMods, "mode");
				KvGetString(kvWeaponMods, "classname", weapon, sizeof(weapon));
				KvGetString(kvWeaponMods, "index", wepIndexStr, sizeof(wepIndexStr));
				KvGetString(kvWeaponMods, "attributes", attributes, sizeof(attributes));
				if(isOverride)
				{
					if(StrContains(wepIndexStr, "-2")!=-1 && StrContains(classname, weapon, false)!=-1 || StrContains(wepIndexStr, "-1")!=-1 && StrEqual(classname, weapon, false))
					{
						if(isOverride!=3)
						{
							Handle itemOverride=PrepareItemHandle(item, _, _, attributes, isOverride==1 ? false : true);
							if(itemOverride!=null)
							{
								item=itemOverride;
								return Plugin_Changed;
							}
						}
						else
						{
							return Plugin_Stop;
						}
					}
					if(StrContains(wepIndexStr, "-1")==-1 && StrContains(wepIndexStr, "-2")==-1)
					{
						int wepIndex;
						char wepIndexes[768][32];
						int weaponIdxcount = ExplodeString(wepIndexStr, " ; ", wepIndexes, sizeof(wepIndexes), 32);
						for(int wepIdx = 0; wepIdx<=weaponIdxcount ; wepIdx++)
						{
							if(strlen(wepIndexes[wepIdx])>0)
							{
								wepIndex = StringToInt(wepIndexes[wepIdx]);
								if(wepIndex == iItemDefinitionIndex)
								{
									switch(isOverride)
									{
										case 3:
										{
											return Plugin_Stop;
										}					
										case 2,1:
										{
											Handle itemOverride=PrepareItemHandle(item, _, _, attributes, isOverride==1 ? false : true);
											if(itemOverride!=null)
											{
												item=itemOverride;
												return Plugin_Changed;
											}
										}
									}
								}
							}
						}
					}
				}	
			}
			else
			{
				break;
			}
		}
		KvGoBack(kvWeaponMods);
	}
	else
	{
		switch(iItemDefinitionIndex)
		{
			case 36:	// Blutsauger
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "16 ; 1");
				// 16: On Hit: Gain up to +1 health
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 129, 1001:	// Buff Banner
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "319 ; 0.6");
				// 319:	-40% buff duration
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 132, 266, 482, 1082:	// Eyelander, Horseless Headless Horsemann's Headtaker, Nessie's Nine Iron, Festive Eyelander
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "54 ; 0.75");
				// 54:	-25% slower move speed on wearer
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 133:	// Gunboats
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5 ; 135 ; 0.7");
				// 58:	+50% self damage force
				// 135:	-30% blast damage from rocket jumps
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 142:	// Gunslinger
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "26 ; 0");
				// 26:	+0 max health on wearer
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 155:	// Southern Hospitality
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "61 ; 1 ; 412 ; 1.1");
				// 61: 0% fire damage vulnerability on wearer
				// 412: 10% damage vulnerability on wearer
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 224:	// L'Etranger
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "166 ; 5 ; 224 ; 0.8");
				// 166:	+5% cloak on hit
				// 224:	+20% cloak duration
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 226:	// Battalion's Backup
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "26 ; 0 ; 140 ; 10 ; 319 ; 0.6");
				// 26:	+0 max health on wearer
				// 140:	+10 max health on wearer
				// 319:	-40% buff duration
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 228:	// Black Box
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "741 ; 5");
				// 741:	On Hit: Gain up to +5 health per attack
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 237:	// Rocket Jumper
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "59 ; 0.65 ; 77 ; 0.75 ; 135 ; 0.5");
				// 58:	+30% self damage force
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 265:	// Sticky Jumper
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "59 ; 0.65 ; 79 ; 0.75 ; 135 ; 0.5");
				// 58:	+30% self damage force
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 304:	// Amputator
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "57 ; 2");
				// 57:	+2 health regenerated per second on wearer
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 354:	// Concheror
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "57 ; 2 ; 319 ; 0.6");
				// 57:	+2 health regenerated per second on wearer
				// 319:	-40% buff duration
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 404:	// Persian Persuader
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "778 ; 1.15");
				// 58:	Melee hits refill 15% of your charge meter
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 405, 608:	// Ali Baba's Wee Booties & Bootlegger
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "26 ; 0 ; 140 ; 20");
				// 26:	+0 max health on wearer
				// 140:	+20 max health on wearer
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 444:	// Mantreads
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5 ; 135 ; 1.3");
				// 58:	+50% self damage force
				// 135:	+30% blast damage from rocket jumps
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 525:	// Diamondback
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "869 ; 1");
				// 869:	Minicrits whenever it would normally crit
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
			case 642:	// Cozy Camper
			{
				Handle itemOverride=PrepareItemHandle(item, _, _, "57 ; 2");
				if(itemOverride!=INVALID_HANDLE)
				{
					item=itemOverride;
					return Plugin_Changed;
				}
			}
		}

		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:
			{
				if(!StrContains(classname, "tf_weapon_jar_milk") || !StrContains(classname, "tf_weapon_cleaver") || !StrContains(classname, "tf_weapon_lunchbox_drink"))	// Bonk! Atomic Punch, Crit-a-Cola, Mad Milk, Festive Bonk!
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.4");
					// 249:	-60% increase in charge recharge rate
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_bat_wood"))	// Sandman
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "278 ; 2.0");
					// 278:	-100% increase in recharge rate
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_bat_giftwrap"))	// Wrap Assassin
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "278 ; 1.5");
					// 278:	-50% increase in recharge rate
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_Soldier:
			{
				if(!StrContains(classname, "tf_weapon_rocketlauncher"))	// Soldier Rocket Launchers
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "59 ; 0.5 ; 77 ; 0.75 ; 135 ; 0.5");
					// 59:	-50% self damage force
					// 77:	-25% max primary ammo on wearer
					// 135:	-50% blast damage from rocket jumps
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_particle_cannon"))	// Cow Mangler 5000
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "5 ; 1.35 ; 59 ; 0.5 ; 72 ; 0.5 ; 77 ; 0.75 ; 96 ; 1.5 ; 135 ; 0.5");
					// 5:	-35% slower fire rate
					// 59:	-50% self damage force
					// 72:	-50% afterburn damage penalty
					// 77:	-25% max primary ammo on wearer
					// 96:	+50% slower reload time
					// 135:	-50% blast damage from rocket jumps
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_raygun"))	// Righteous Bison
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "5 ; 1.25 ; 96 ; 1.35");
					// 5:	-25% slower fire rate
					// 96:	+35% slower reload time
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_parachute"))	// B.A.S.E. Jumper
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5 ; 135 ; 1.3");
					// 58:	+50% self damage force
					// 135:	+30% blast damage from rocket jumps
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_katana"))	// Half-Zatoichi
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "220 ; 15");
					// 220:	Gain 15% of base health on kill
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_Pyro:
			{
				if(!StrContains(classname, "tf_weapon_flamethrower") || !StrContains(classname, "tf_weapon_rocketlauncher_fireball"))	// Flamethrowers
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "77 ; 0.5 ; 869 ; 1");
					// 77:	-50% max primary ammo on wearer
					// 869:	Minicrits whenever it would normally crit
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_jar_gas"))	// Gas Passer
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "2059 ; 3000");
					// 2059:
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_DemoMan:
			{
				if(!StrContains(classname, "tf_weapon_grenadelauncher") || !StrContains(classname, "tf_weapon_cannon"))	// Grenade Launchers & Loose Cannon
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "77 ; 0.75");
					// 77:	-25% max primary ammo on wearer
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_pipebomblauncher"))	// Stickybomb Launchers
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "59 ; 0.25 ; 79 ; 0.75 ; 135 ; 0.5");
					// 59:	-75% self damage force
					// 79:	-25% max secondary ammo on wearer
					// 135:	-50% blast damage from rocket jumps
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_wearable_demoshield"))	// Chargin' Targe, Splendid Screen, Tide Turner, Festive Targe
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.5");
					// 249:	-50% increase in charge recharge rate
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_wearable_stickbomb"))	// Ullapool Caber
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "2 ; 1.05", true);
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_parachute"))	// B.A.S.E. Jumper
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5 ; 135 ; 1.3");
					// 58:	+50% self damage force
					// 135:	+30% blast damage from rocket jumps
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_katana"))	// Half-Zatoichi
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "220 ; 15");
					// 220:	Gain 15% of base health on kill
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_Heavy:
			{
				if(!StrContains(classname, "tf_weapon_minigun"))	// Miniguns
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "77 ; 0.5 ; 869 ; 1");
					// 77:	-50% max primary ammo on wearer
					// 869:	Minicrits whenever it would normally crit
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_lunchbox"))	// Sandvich, Dalokohs Bar, Fishcake, Robo-Sandvich, Festive Sandvich
				{
					if(iItemDefinitionIndex == 331)	// Buffalo Steak Sandvich
					{
						Handle itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.67");
						// 249:	-33% increase in charge recharge rate
						if(itemOverride!=INVALID_HANDLE)
						{
							item=itemOverride;
							return Plugin_Changed;
						}
					}

					if(iItemDefinitionIndex == 1190)	// Second Banana
					{
						Handle itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.75 ; 876 ; 0.34");
						// 249:	-25% increase in charge recharge rate
						// 876:	-66% healing effect
						if(itemOverride!=INVALID_HANDLE)
						{
							item=itemOverride;
							return Plugin_Changed;
						}
					}
	
					Handle itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.5 ; 876 ; 0.5");
					// 249:	-50% increase in charge recharge rate
					// 876:	-50% healing effect
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_Engineer:
			{
				if(!StrContains(classname, "tf_weapon_shotgun_revenge"))	// Frontier Justice
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "869 ; 1");
					// 869:	Minicrits whenever it would normally crit
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_drg_pomson"))	// Pomson 6000
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "5 ; 1.2 ; 96 ; 1.35");
					// 5:	-20% slower fire rate
					// 96:	+35% slower reload time
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_shotgun_building_rescue"))	// Rescue Ranger
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "77 ; 0.75");
					// 77:	-25% max primary ammo on wearer
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_pistol"))	// Engineer Pistols
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "79 ; 0.24");
					// 79:	-76% max secondary ammo on wearer
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_mechanical_arm"))	// Short Circuit
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "20 ; 1 ; 408 ; 1");
					// 20:	100% critical hit vs burning players
					// 408:	100% critical hit vs non-burning players
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_pda_engineer_build"))	// Engineer Build PDAs
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "286 ; 0.5 ; 287 ; 0.65 ; 464 ; 0.5 ; 465 ; 0.5 ; 790 ; 10");
					// 286:	-50% max building health
					// 287:	-35% Sentry Gun damage bonus
					// 464: Sentry build speed increased by -50%
					// 465: Increases teleporter build speed by -50%
					// 790: +900% metal cost when constructing or upgrading teleporters
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_Medic:
			{
				if(!StrContains(classname, "tf_weapon_crossbow"))	// Crusader's Crossbow
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "2 ; 3 ; 77 ; 0.2 ; 138 ; 0.333 ; 775 ; 0.333");
					// 2:	+200% damage bonus
					// 77:	-80% max primary ammo on wearer
					// 138:	-67% damage vs players
					// 775:	-67% damage penalty vs buildings
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
				if(!StrContains(classname, "tf_weapon_medigun"))	// Medi Guns
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "9 ; 0.2");
					// 9:	-80% ÜberCharge rate
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_Sniper:
			{
				if(!StrContains(classname, "tf_weapon_jar"))	// Jarate
				{
					Handle itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.4");
					// 249:	-60% increase in charge recharge rate
					if(itemOverride!=INVALID_HANDLE)
					{
						item=itemOverride;
						return Plugin_Changed;
					}
				}
			}
			case TFClass_Spy:
			{
				if(!StrContains(classname, "tf_weapon_builder") || !StrContains(classname, "tf_weapon_sapper"))	// Sappers
					return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_CheckItems(Handle timer, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	SetEntityRenderColor(client, 255, 255, 255, 255);
	int index = -1;
	int[] civilianCheck = new int[MaxClients+1];
	int weapon = -1;
	TFClassType class = TF2_GetPlayerClass(client);
	char classname[64];

	if(validZom(client) && g_iSpecialInfected[client] == INFECTED_NONE)
	{
		int SetHealth=125;

		float FireRate = 1.0,	// 5 / 6	Any
		Jump = 1.0,		// 443		Any
		Bleed = 0.0,		// 149		Any
		Damage = 1.0,		// 1 / 2	Any
		Speed = 1.0,		// 442		Any
		SlowBy40 = 0.0,		// 182		Any
		DamageVsPlayers = 1.0,	// 138		Any
		DamageVsBurning = 1.0,	// 795		Any
		SlowChance = 0.0,	// 32		Any
		RandomCrits = 1.0,	// 15 / 28	Any
		Health = 0.0,		// 125 / 26	Any
		HealthOnKill = 0.0,	// 220		Any
		HealthOnHit = 0.0,	// 16		Any
		AfterburnDamage = 0.5,	// 71 / 72	Any
		CloakOnHit = 0.0,	// 166		Spy
		CloakOnKill = 100.0,	// 158		Spy
		SubDamage = 1.0,	// Custom	Spy
		MaxMetal = 0.0,		// 81 / 80	Engineer
		MetalRegen = 0.0;	// 113		Engineer

		bool Knockback = false,	// 216		Any
		CritsAreMini = false,	// 869		Any
		CritsOnBack = false,	// 362		Any
		Ignite = false,		// 208		Any
		JarateBackstab = true,	// 341		Any
		NoDisguises = true,	// 155		Spy
		NoCloak = false,	// Custom	Spy
		SilentCloak = false;	// 160		Spy

		Handle panel = CreatePanel();
		char string[256];
		SetGlobalTransTarget(client);
		Format(string, sizeof(string), "%t\n", "Left 4 Dead");
		SetPanelTitle(panel, string);
		weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		if(IsValidEntity(weapon))
		{
			index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
			switch(index)
			{
				// Scout
				case 45, 1078:  // Force-A-Nature
				{
					Knockback = true;
					SlowBy40 = 1.0;
					FireRate = 1.2;
				}
				case 220:  // Shortstop
				{
					SpawnWeapon(client, "tf_weapon_handgun_scout_primary", 220, 101, 13, "3 ; 0 ; 37 ; 0 ; 476 ; 0 ; 535 ; 1.4 ; 536 ; 1 ; 818 ; 1");
					Format(string, sizeof(string), "Gained a Passive Shortstop!\n");
					DrawPanelText(panel, string);
				}
				case 448:  // Soda Popper
				{
					SpawnWeapon(client, "tf_weapon_soda_popper", 448, 101, 13, "3 ; 0 ; 37 ; 0 ; 476 ; 0 ; 818 ; 1");
					Format(string, sizeof(string), "Gained a Passive Soda Popper!\n");
					DrawPanelText(panel, string);
					SetEntPropFloat(client, Prop_Send, "m_flHypeMeter", 100.0);
				}
				case 772:  // Baby Face's Blaster
				{
					Speed *= 0.9;
					SpawnWeapon(client, "tf_weapon_pep_brawler_blaster", 772, 101, 13, "3 ; 0 ; 37 ; 0 ; 418 ; 0.25 ; 419 ; 20 ; 476 ; 0 ; 733 ; 1");
					Format(string, sizeof(string), "Gained a Passive Baby Face's Blaster!\n");
					DrawPanelText(panel, string);
					SetEntPropFloat(client, Prop_Send, "m_flHypeMeter", 50.0);
				}
				case 1103:  // Back Scatter
				{
					FireRate = 1.1;
					CritsOnBack = true;
					CritsAreMini = true;
					RandomCrits = 0.0;
				}
				// Soldier
				case 127:  // Direct Hit
				{
					FireRate = 1.3;
					Damage = 1.25;
				}
				case 228, 1085:  // Black Box
				{
					HealthOnHit = 20;
					FireRate = 1.2;
				}
				case 237:  // Rocket Jumper
				{
					Speed = 1.35;
					Damage = 0.5;
				}
				case 414:  // Liberty Launcher
				{
					Speed = 1.15;
					Damage = 0.75;
					FireRate = 0.85;
				}
				case 441:  // Cow Mangler 5000
				{
					strcopy(classname, sizeof(classname), "tf_weapon_fireaxe");	// Work around to Ignition
					DamageVsPlayers = 0.75;
					FireRate = 1.25;
					Ignite = true;
				}
				case 730:  // Beggar's Bazooka
				{
					Speed = 0.9;
					Damage = 1.2;
				}
				case 1104:  // Air Strike
				{
					Speed = 1.05;
					Damage = 0.4;
					FireRate = 0.35;
				}
				// Pyro
				case 40, 1146:  // Backburner
				{
					FireRate = 1.25;
					CritsOnBack = true;
				}
				case 215:  // Degreaser
				{
					DamageVsPlayers = 0.5;
					FireRate = 0.65;
					Speed = 1.1;
				}
				case 594:  // Phlogistinator
				{
					FireRate = 2.0;
					TF2_AddCondition(client, TFCond_HalloweenCritCandy, TFCondDuration_Infinite);
					TF2_StunPlayer(client, 3.0, 0.0, TF_STUNFLAGS_NORMALBONK|TF_STUNFLAG_NOSOUNDOREFFECT, client);
				}
				case 741:  // Rainblower
				{
					PyroLand = true;
				}
				case 1178:  // Dragon's Fury
				{
					DamageVsPlayers = 0.75;
					FireRate = 0.85;
				}
				// Demoman
				case 308:  // Loch-n-Load
				{
					FireRate = 1.25;
					Speed = 1.1;
				}
				case 405, 608:  // Ali Baba's Wee Booties, Bootlegger
				{
					Damage = 0.7;
					Health = 25.0;
					Speed = 1.1;
				}
				case 996:  // Loose Cannon
				{
					Knockback = true;
					SlowBy40 = 1.0;
					FireRate = 1.3;
				}
				case 1151:  // Iron Bomber
				{
					Speed = 1.1;
					Jump = 1.1;
					FireRate = 1.3;
				}
				// Heavy
				case 41:  // Natascha
				{
					FireRate = 1.25;
					DamageVsPlayers = 0.75;
					Health = 30.0;
					SlowBy40 = 5.0;
				}
				case 312:  // Brass Beast
				{
					FireRate = 1.3;
					Damage = 1.25;
					Health = 30.0;
					Speed = 0.85;
				}
				case 424:  // Tomislav
				{
					FireRate = 1.1;
					Speed = 1.05;
				}
				case 811, 832:  // Huo-Long Heater
				{
					strcopy(classname, sizeof(classname), "tf_weapon_fireaxe");
					DamageVsBurning = 1.2;
					DamageVsPlayers = 0.75;
					Ignite = true;
				}
				// Engineer
				case 141, 1004:  // Frontier Justice
				{
					FireRate = 1.5;
					RandomCrits = 2.25;
				}
				case 527:  // The Widowmaker
				{
					MaxMetal = -70;
					MetalRegen = 10.0;
				}
				case 588:  // Pomson 6000
				{
					SpawnWeapon(client, "tf_weapon_drg_pomson", 588, 101, 13, "1 ; 0.28 ; 28 ; 0.25 ; 281 ; 1 ; 284 ; 1 ; 285 ; 1 ; 337 ; 5 ; 338 ; 10 ; 396 ; 1001 ; 818 ; 1");
					Format(string, sizeof(string), "Gained a Passive Pomson 6000!\n");
					DrawPanelText(panel, string);
					WeaponOnly = 1;
				}
				case 997:  // Rescue Ranger
				{
					SpawnWeapon(client, "tf_weapon_shotgun_building_rescue", 220, 101, 13, "1 ; 0.28 ; 3 ; 0.66 ; 28 ; 0.25 ; 77 ; 0.5 ; 396 ; 1001 ; 469 ; 100 ; 472 ; 1 ; 474 ; 60 ; 818 ; 1 ; 880 ; 4");
					Format(string, sizeof(string), "Gained a Passive Rescue Ranger!\n");
					DrawPanelText(panel, string);
					WeaponOnly = 1;
				}
				// Medic
				case 36:  // Blutsauger
				{
					HealthRegen = 1.5;
					HealthOnHit = 30.0;
				}
				case 305:  // Crusader's Crossbow
				{
					SpawnWeapon(client, "tf_weapon_crossbow", 305, 101, 13, "1 ; 0.28 ; 28 ; 0.35 ; 42 ; 1 ; 112 ; 0.1 ; 396 ; 1001 ; 818 ; 1");
					Format(string, sizeof(string), "Gained a Passive Crusader's Crossbow!\n");
					DrawPanelText(panel, string);
					WeaponOnly = 1;
				}
				case 412:  // Overdose
				{
					Damage = 0.8;
					Speed = 1.1;
				}
				case 1079:  // Festive Crusader's Crossbow
				{
					SpawnWeapon(client, "tf_weapon_crossbow", 1079, 101, 13, "1 ; 0.28 ; 28 ; 0.35 ; 42 ; 1 ; 112 ; 0.1 ; 396 ; 1001 ; 818 ; 1 ; 280 ; 23");
					Format(string, sizeof(string), "Gained a Passive Crusader's Crossbow!\n");
					DrawPanelText(panel, string);
					WeaponOnly = 1;
				}
				// Sniper
				case 56, 1092:  // Huntsman, Fortified Compound
				{
					SpawnWeapon(client, "tf_weapon_compound_bow", index, 101, 13, "1 ; 0.31 ; 112 ; 0.04 ; 396 ; 1001 ; 818 ; 1");
					Format(string, sizeof(string), "Gained a Passive Crusader's Crossbow!\n");
					DrawPanelText(panel, string);
					WeaponOnly = 1;
				}
				case 230:  // Sydney Sleeper
				{
					JarateBackstab = true;
					FireRate = 0.9;
					Damage = 0.8;
				}
				case 402:  // Bazaar Bargain
				{
					Speed = 0.85;
					Damage = 1.2;
				}
				case 526, 30665:  // Machina, Shooting Star
				{
					FireRate = 0.8;
					Damage = 1.2;
				}
				case 752:  // Hitman's Heatmaker
				{
					FireRate = 0.9;
					Damage = 0.9;
				}
				case 1005:  // Festive Huntsman
				{
					SpawnWeapon(client, "tf_weapon_compound_bow", 1005, 101, 13, "1 ; 0.31 ; 112 ; 0.04 ; 396 ; 1001 ; 818 ; 1 ; 280 ; 19");
					Format(string, sizeof(string), "Gained a Passive Crusader's Crossbow!\n");
					DrawPanelText(panel, string);
					WeaponOnly = 1;
				}
				case 1098:  // Classic
				{
					Speed = 1.1;
					Damage = 0.85;
				}
				// Spy
				case 61, 1006:  // Ambassador
				{
					FireRate = 1.2;
					Damage = 0.85;
					DamageVsPlayers = 1.25;
				}
				case 224:  // L'Etranger
				{
					CloakOnHit = 30.0;
					DamageVsPlayers = 0.9;
				}
				case 460:  // Enforcer
				{
					NoDisguises = false;
					NoCloak = true;
				}
				case 525:  // Diamondback
				{
					Damage = 0.85;
					DamageVsPlayers = 1.2;
				}
			}
		}
		weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		if(IsValidEntity(weapon))
		{
			index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
			if(OnlyWeapons)
			{
				switch(index)
				{
					// Scout
					case 46, 1145:  // Bonk! Atomic Punch
					{
						Health -= 100.0;
						TF2_AddCondition(client, TFCond_DodgeChance, TFCondDuration_Infinite);
					}
					case 163:  // Crit-a-Cola
					{
						TF2_AddCondition(client, TFCond_Buffed, TFCondDuration_Infinite);
						TF2_AddCondition(client, TFCond_MarkedForDeathSilent, TFCondDuration_Infinite);
					}
					case 222, 1121:  // Mad Milk
					{
						//DamageVsPlayers -= 0.5;
					}
					case 449:  // Winger
					{
						FireRate *= 0.9;
						Jump *= 1.15;
					}
					case 773:  // Pretty Boy's Pocket Pistol
					{
						FireRate *= 1.1;
						HealthOnHit += 6.0;
					}
					case 812, 833:  // Flying Guillotine
					{
						FireRate *= 1.2;
						Bleed += 1.0;
					}
					// Soldier
					case 129, 1001:  // Buff Banner
					{
						Damage *= 0.85;
						DamageVsPlayers *= 0.65;
						SpawnWeapon(client, "tf_weapon_buff_item", index, 101, 13, "129 ; 1 ; 357 ; 20 ; 773 ; 8");
						SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
						Format(string, sizeof(string), "Gained a Passive Buff Banner!\n");
						DrawPanelText(panel, string);
					}
					case 133:  // Gunboats
					{
						ExplosiveResist *= 0.6;
						Health -= 50.0;
					}
					case 226:  // Battalion's Backup
					{
						Health -= 90.0;
						SpawnWeapon(client, "tf_weapon_buff_item", 226, 101, 13, "129 ; 2 ; 357 ; 20 ; 773 ; 8");
						SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
						Format(string, sizeof(string), "Gained a Passive Battalion's Backup!\n");
						DrawPanelText(panel, string);
					}
					case 354:  // Concheror
					{
						Speed *= 0.6;
						Health -= 50.0;
						SpawnWeapon(client, "tf_weapon_buff_item", 354, 101, 13, "129 ; 3 ; 357 ; 20 ; 773 ; 8");
						SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
						Format(string, sizeof(string), "Gained a Passive Concheror!\n");
						DrawPanelText(panel, string);
					}
					case 442:  // Righteous Bison
					{
						SpawnWeapon(client, "tf_weapon_handgun_raygun", 442, 101, 13, "281 ; 1 ; 283 ; 1 ; 284 ; 1 ; 285 ; 1 ; 396 ; 1001 ; 394 ; %.2f ; 476 ; %.2f ; 818 ; 1", FireRate, Damage);
						Format(string, sizeof(string), "Gained a Passive Righteous Bison!\n");
						DrawPanelText(panel, string);
						OnlyWeapons = 2;
					}
					case 444:  // Mantreads
					{
						KnockbackResist *= 0.25;
						Speed *= 0.9;
					}
					case 1101:  // B.A.S.E. Jumper
					{
						Parachute = true;
						Speed *= 0.95;
					}
					// Pyro
					case 39, 1081:  // Flaregun
					{
						DamageVsBurning *= 2.0;
						AfterburnDamage *= 0.25;
					}
					case 351:  // Detonator
					{
						DamageVsBurning *= 2.0;
						AfterburnDamage *= 0.25;
						Jump *= 1.25;
						Health -= 25.0;
					}
					case 415:  // Reserve Shooter
					{
						Jump *= 1.25;
						Health -= 25.0;
					}
					case 595:  // Manmelter
					{
						CritsAreMini = true;
						SpawnWeapon(client, "tf_weapon_flaregun_revenge", 595, 101, 13, "281 ; 1 ; 348 ; 1.2 ; 350 ; 1 ; 367 ; 1 ; 396 ; 1001 ; 394 ; %.2f ; 476 ; %.2f ; 818 ; 1", FireRate, Damage);
						Format(string, sizeof(string), "Gained a Passive Manmelter!\n");
						DrawPanelText(panel, string);
						OnlyWeapons = 2;
					}
					case 740:  // Scorch Shot
					{
						CritsAreMini = true;
						CritsVsBurning = true;
						AfterburnDamage *= 0.19;
					}
					// Heavy
					case 42, 863, 1002:  // Sandvich
					{
						Health += 150.0;
						Speed *= 0.8;
					}
					case 159, 433:  // Dalokohs Bar
					{
						Health += 50.0;
						Speed *= 0.95;
					}
					case 311:  // Buffalo Steak Sandvich
					{
						Speed *= 1.2;
						TF2_AddCondition(client, TFCond_Buffed, TFCondDuration_Infinite);
						TF2_AddCondition(client, TFCond_MarkedForDeathSilent, TFCondDuration_Infinite);
					}
					case 425:  // Family Business
					{
						FireRate *= 0.85;
						Speed *= 0.9;
					}
					case 1153:  // Panic Attack
					{
						Health -= 100;
						Speed *= 1.5;
						Jump *= 1.15;
						DamageVsPlayers *= 0.9;
						FireRate *= 1.1;
					}
					case 1190:  // Second Banana
					{
						Health += 100.0;
						Speed *= 0.875;
					}
					// Spy
					case 810, 831:  // Red-Tape Recorder
					{
						FireRate *= 1.35;
						Speed *= 1.25;
						DamageVsPlayers *= 0.65;
					}
				}
			}
		}
		char attributes[64];
		index = 5; // Fail safe
		weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if(IsValidEntity(weapon))
		{
			if(!strlen(classname))
				GetEntityClassname(weapon, classname, sizeof(classname));

			index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
			if(OnlyWeapons)
			{
				switch(index)
				{
					// Scout
					case 44:  // Sandman
					{
						Health -= 15.0;
						Format(attributes, sizeof(attributes), "38 ; 1 ; 278 ; 99");
					}
					case 317:  // Candy Cane
					{
						Health -= 25.0;
						HealthOnHit += 20.0;
					}
					case 325, 452:  // Boston Basher, Three-Rune Blade
					{
						Bleed += 2.0;
						Format(attributes, sizeof(attributes), "204 ; 1 ; 207 ; 1.75");
					}
					case 648:  // Wrap Assassin
					{
						Damage *= 0.35;
						Format(attributes, sizeof(attributes), "278 ; 99 ; 346 ; 1");
					}
					// Soldier
					case 128:  // Equalizer
					{
						Format(attributes, sizeof(attributes), "115 ; 1 ; 129 ; -3");
					}
					case 357:  // Half-Zatoichi
					{
						FireRate *= 1.25;
						RandomCrits = 0.0;
						Format(attributes, sizeof(attributes), "219 ; 1 ; 220 ; 50 ; 781 ; 72");
					}
					case 416:  // Market Gardener
					{
						FireRate *= 1.2;
						RandomCrits = 0.0;
						Format(attributes, sizeof(attributes), "366 ; 2");
					}
					case 447:  // Disciplinary Action
					{
						Damage *= 0.75;
						Format(attributes, sizeof(attributes), "251 ; 1");	// No extra melee range btw
					}
					case 775:  // Escape Plan
					{
						Health -= 50.0;
						Format(attributes, sizeof(attributes), "235 ; 2 ; 129 ; -3");
					}
					// Heavy
					case 43:  // Killing Gloves of Boxing
					{
						FireRate *= 1.2;
						Format(attributes, sizeof(attributes), "613 ; 5");
					}
					case 239, 1084, 1100:  // Gloves of Running Urgently
					{
						Health -= 100.0;
						Speed *= 1.3;
					}
					case 426:  // Eviction Notice
					{
						Health -= 50.0;
						Speed *= 1.15;
						Damage *= 0.4;
						Speed *= 0.45;
					}
					// Spy
					case 225, 574:  // Your Eternal Reward
					{
						SilentCloak = true;
						Format(attributes, sizeof(attributes), "34 ; 1.33");
					}
					case 356:  // Conniver's Kunai
					{
						Health -= 70.0;
						HealthOnHit += 70;
					}
					case 461:  // Conniver's Kunai
					{
						Health -= 25.0;
						CloakOnHit += 30.0;
						Format(attributes, sizeof(attributes), "737 ; 1.5");
					}
					// Multi-Class
					case 154:  // Pain Train
					{
					}
					case 169, 423, 1071:  // Golden-based Weapons
					{
						Format(attributes, sizeof(attributes), "150 ; 1");
					}
				}
			}
		}

		if(!WeaponOnly)
		{
			if(!strlen(classname))	// Fail Safe
				strcopy(classname, sizeof(classname), "tf_weapon_shovel");

			weapon = SpawnWeapon(client, classname, index, 101, 13, attributes);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		}

		switch(WeaponOnly)
		{
			case 1:
			{
				switch(class)
				{
					case TFClass_Engineer:
					{
						Damage = 0.28;
						RandomCrits = 0.25;
					}
					case TFClass_Medic:
					{
						Damage = 0.28;
						RandomCrits = 0.35;
					}
					case TFClass_Sniper:
					{
						Damage = 0.31;
						RandomCrits = 0.0;
					}
				}
			}
			case 2:
			{
				switch(class)
				{
					case TFClass_Engineer:
					{
						Damage = 0.28;
						RandomCrits = 0.25;
					}
					case TFClass_Medic:
					{
						Damage = 0.28;
						RandomCrits = 0.35;
					}
					case TFClass_Sniper:
					{
						Damage = 0.31;
						RandomCrits = 0.0;
					}
				}
			}
			default:
			{
				switch(class)
				{
					case TFClass_Scout:
					{
						SetHealth = 125;
						Damage *= 0.29;	// 10
						RandomCrits *= 0.35;
					}
					case TFClass_Soldier:
					{
						SetHealth = 200;
						Damage *= 0.46;	// 30
						RandomCrits *= 0.25;
					}
					case TFClass_Pyro:
					{
						SetHealth = 175;
						Damage *= 0.34;	// 22
						RandomCrits *= 0.3;
					}
					case TFClass_DemoMan:
					{
						SetHealth = 175;
						Damage *= 0.38;	// 25
						RandomCrits *= 0.3;
					}
					case TFClass_Heavy:
					{
						SetHealth = 300;
						Damage *= 0.54;	// 35
						RandomCrits *= 0.35;
					}
					case TFClass_Engineer:
					{
						SetHealth = 125;
						Damage *= 0.28;	// 18
						RandomCrits *= 0.25;
					}
					case TFClass_Medic:
					{
						SetHealth = 150;
						Damage *= 0.28;	// 18
						RandomCrits*=0.35;
					}
					case TFClass_Sniper:
					{
						SetHealth = 125;
						Damage *= 0.31;	// 20
						RandomCrits *= 0.4;
					}
					case TFClass_Spy:
					{
						SetHealth = 125;
						Damage *= 2.5;
						DamageVsPlayers *= 0.12;
						SubDamage = Damage*DamageVsPlayers;	// 12
					}
					default:
					{
						SetHealth = 150;
						Damage *= 0.31;	// 20
						RandomCrits *= 0.3;
					}
				}
				SetEntityHealth(client, RoundFloat(SetHealth+Health));
				HealthOnHit *= FireRate; // Balancing

				if(Damage > 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 2, Damage);
					if(class!=TFClass_Spy)
					{
						Format(string, sizeof(string), "+%i%% damage bonus", RoundToFloor((Damage-1.0)*100.0));
						DrawPanelText(panel, string);
					}
				}
				if(class==TFClass_Spy)
				{
					if(SubDamage > 1)
					{
						Format(string, sizeof(string), "+%i%% damage bonus", RoundToFloor((SubDamage-1.0)*100.0));
						DrawPanelText(panel, string);
					}
				}
				if(FireRate < 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 6, FireRate);
					Format(string, sizeof(string), "+%i%% faster firing speed", RoundToFloor((1.0-FireRate)*100.0));
					DrawPanelText(panel, string);
				}
				if(Health > 0)
				{
					TF2Attrib_SetByDefIndex(weapon, 26, Health);
					Format(string, sizeof(string), "+%i max health on wearer", RoundToFloor(Health));
					DrawPanelText(panel, string);
				}
				if(RandomCrits > 1 && class!=TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 28, RandomCrits);
					Format(string, sizeof(string), "+%i%% random critical hit chance", RoundToFloor((RandomCrits-1.0)*100.0));
					DrawPanelText(panel, string);
				}
				if(SlowChance > 0)
				{
					TF2Attrib_SetByDefIndex(weapon, 32, SlowChance);
					Format(string, sizeof(string), "On Hit: %i%% chance to slow target", RoundToFloor((SlowChance-1.0)*100.0));
					DrawPanelText(panel, string);
				}
				if(Speed > 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 107, Speed);
					Format(string, sizeof(string), "+%i%% faster move speed on wearer", RoundToFloor((Speed-1.0)*100.0));
					DrawPanelText(panel, string);
				}
				if(Bleed > 0)
				{
					TF2Attrib_SetByDefIndex(weapon, 149, Bleed);
					Format(string, sizeof(string), "On Hit: Bleed for %i%% seconds", RoundToFloor(Bleed));
					DrawPanelText(panel, string);
				}
				if(CloakOnKill > 0 && class==TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 158, CloakOnHit);
					Format(string, sizeof(string), "+%i%% cloak on kill", RoundToFloor(CloakOnKill));
					DrawPanelText(panel, string);
				}
				if(SilentCloak && class==TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 160, 1.0);
					Format(string, sizeof(string), "Reduced decloak sound volume");
					DrawPanelText(panel, string);
				}
				if(CloakOnHit > 0 && class==TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 166, CloakOnHit);
					Format(string, sizeof(string), "+%i%% cloak on hit", RoundToFloor(CloakOnHit));
					DrawPanelText(panel, string);
				}
				if(SlowBy40 > 0)
				{
					TF2Attrib_SetByDefIndex(weapon, 182, SlowBy40);
					Format(string, sizeof(string), "On Hit: Slow target movement by 40% for %is", RoundToFloor(SlowBy40));
					DrawPanelText(panel, string);
				}
				if(Knockback)
				{
					TF2Attrib_SetByDefIndex(weapon, 216, 1.0);
					Format(string, sizeof(string), "Attrib_Knockback");
					DrawPanelText(panel, string);
				}
				if(HealthOnKill > 0)
				{
					TF2Attrib_SetByDefIndex(weapon, 220, HealthOnKill);
					Format(string, sizeof(string), "Gain %i%% of base health on kill", RoundToFloor(HealthOnKill));
					DrawPanelText(panel, string);
				}
				if(CritsOnBack && class!=TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 362, 1.0);
					Format(string, sizeof(string), "Always critical hit from behind");
					DrawPanelText(panel, string);
				}
				if(DamageVsBurning != 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 795, DamageVsBurning);
					Format(string, sizeof(string), "%i%% damage bonus vs burning players", RoundToFloor((DamageVsBurning-1.0)*100.0));
					DrawPanelText(panel, string);
				}

				Format(string, sizeof(string), " ");
				DrawPanelText(panel, string);

				// Bad Stuff

				if(Damage < 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 1, Damage);
					if(class!=TFClass_Spy)
					{
						Format(string, sizeof(string), "-%i%% damage penalty", RoundToFloor((1.0-Damage)*100.0));
						DrawPanelText(panel, string);
					}
				}
				if(class==TFClass_Spy)
				{
					if(SubDamage < 1)
					{
						Format(string, sizeof(string), "-%i%% damage penalty", RoundToFloor((1.0-SubDamage)*100.0));
						DrawPanelText(panel, string);
					}
				}
				if(FireRate > 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 5, FireRate);
					Format(string, sizeof(string), "%i%% slower firing speed", RoundToFloor((FireRate-1.0)*100.0));
					DrawPanelText(panel, string);
				}
				if(RandomCrits <= 0 && class!=TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 15, 0.0);
					Format(string, sizeof(string), "No random critical hits");
					DrawPanelText(panel, string);
				}
				else if(RandomCrits < 1 && class!=TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 28, RandomCrits);
					Format(string, sizeof(string), "-%i%% random critical hit chance", RoundToFloor((1.0-RandomCrits)*100.0));
					DrawPanelText(panel, string);
				}
				if(Speed < 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 54, Speed);
					Format(string, sizeof(string), "%i%% slower move speed on wearer", RoundToFloor((1.0-Speed)*100.0));
					DrawPanelText(panel, string);
				}
				int vuln = GetRandomInt(1, 99);
				float total = (vuln/100.0)+1.0;
				TF2Attrib_SetByDefIndex(weapon, 61, total);
				Format(string, sizeof(string), "%i%% fire damage vulnerability on wearer", vuln);
				DrawPanelText(panel, string);
				if(Health < 0)
				{
					TF2Attrib_SetByDefIndex(weapon, 125, Health);
					Format(string, sizeof(string), "%i max health on wearer", RoundToFloor(Health));
					DrawPanelText(panel, string);
				}
				if(DamageVsPlayers < 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 138, DamageVsPlayers);
					if(class==TFClass_Spy)
					{
						Format(string, sizeof(string), "-%i%% backstab damage", RoundToFloor((1.0-DamageVsPlayers)*100.0));
					}
					else
					{
						Format(string, sizeof(string), "-%i%% damage vs players", RoundToFloor((1.0-DamageVsPlayers)*100.0));
					}
					DrawPanelText(panel, string);
				}
				if(NoDisguises && class==TFClass_Spy)
				{
					TF2Attrib_SetByDefIndex(weapon, 155, 1.0);
					TF2_RemovePlayerDisguise(client);
					Format(string, sizeof(string), "Wearer cannot disguise");
					DrawPanelText(panel, string);
				}
				if(NoCloak && class==TFClass_Spy)
				{
					TF2_RemoveWeaponSlot(client, 4);
					TF2_RemoveCondition(client, TFCond_RestrictToMelee);
					Format(string, sizeof(string), "Wearer cannot cloak");
					DrawPanelText(panel, string);
				}
				total = ((100-vuln)/100.0)+1.0;
				TF2Attrib_SetByDefIndex(weapon, 206, total);
				Format(string, sizeof(string), "+%i%% damage from melee sources", 100-vuln);
				DrawPanelText(panel, string);
				if(Jump < 1)
				{
					TF2Attrib_SetByDefIndex(weapon, 443, Jump);
					Format(string, sizeof(string), "%i%% smaller jump height", RoundToFloor((1.0-Jump)*100.0));
					DrawPanelText(panel, string);
				}
				if(CritsAreMini)
				{
					TF2Attrib_SetByDefIndex(weapon, 869, 1.0);
					Format(string, sizeof(string), "Minicrits whenever it would normally crit");
					DrawPanelText(panel, string);
				}
			}
		}

		Format(string, sizeof(string), " ");
		DrawPanelText(panel, string);
		Format(string, sizeof(string), "%t", "SZF Help");
		DrawPanelItem(panel, string);
		Format(string, sizeof(string), "%t", "Exit");
		DrawPanelItem(panel, string);
		SendPanelToClient(panel, client, panel_HandleClass, 20);
		CloseHandle(panel);
		TF2Attrib_SetByDefIndex(weapon, 1006, 1.0);
		TF2Attrib_SetByDefIndex(weapon, 448, 1.0);
		TF2Attrib_SetByDefIndex(weapon, 450, 1.0);
	}
	else
	{
		weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		if(IsValidEntity(weapon))
		{
			index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			switch(index)
			{
				case 527:  // Windowmaker
				{
					TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
					SpawnWeapon(client, "tf_weapon_shotgun_primary", 9, 1, 0, "");
				}
			}
		}
		else
		{
			civilianCheck[client]++;
		}

		weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		if(IsValidEntity(weapon))
		{
			GetEntityClassname(weapon, classname, sizeof(classname));
			index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			switch(index)
			{
				case 998:	// Vaccinator
				{
					TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
					SpawnWeapon(client, "tf_weapon_medigun", 29, 1, 0, "");
				}
			}

			if(!StrContains(classname, "tf_weapon_medigun"))
			{
				TF2Attrib_SetByDefIndex(weapon, 9, 0.2);
			}
		}
		else
		{
			civilianCheck[client]++;
		}

		weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if(IsValidEntity(weapon))
		{
			index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			switch(index)
			{
				case 589:	// Eureka Effect
				{
					TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
					SpawnWeapon(client, "tf_weapon_wrench", 7, 1, 0, "");
				}
			}
			if(class==TFClass_Medic)
			{
				TF2Attrib_SetByDefIndex(weapon, 28, 0.5);
				TF2Attrib_SetByDefIndex(weapon, 69, 0.15);
				TF2Attrib_SetByDefIndex(weapon, 129, -2.0);
			}
			else	
			{
				TF2Attrib_SetByDefIndex(weapon, 28, 0.5);
				TF2Attrib_SetByDefIndex(weapon, 69, 0.1);
			}
		}
		else
		{
			civilianCheck[client]++;
		}

		if(civilianCheck[client]==3)
		{
			civilianCheck[client]=0;
			TF2_RespawnPlayer(client);
		}
	}
	civilianCheck[client]=0;
	return Plugin_Continue;
}

stock Handle PrepareItemHandle(Handle item, char[] name="", int index=-1, const char[] att="", bool dontPreserve=false)
{
	static Handle weapon;
	int addattribs;

	char weaponAttribsArray[32][32];
	int attribCount=ExplodeString(att, ";", weaponAttribsArray, 32, 32);

	if(attribCount % 2)
	{
		--attribCount;
	}

	int flags=OVERRIDE_ATTRIBUTES;
	if(!dontPreserve)
	{
		flags|=PRESERVE_ATTRIBUTES;
	}

	if(weapon==INVALID_HANDLE)
	{
		weapon=TF2Items_CreateItem(flags);
	}
	else
	{
		TF2Items_SetFlags(weapon, flags);
	}

	if(item!=INVALID_HANDLE)
	{
		addattribs=TF2Items_GetNumAttributes(item);
		if(addattribs>0)
		{
			for(int i; i<2*addattribs; i+=2)
			{
				bool dontAdd=false;
				int attribIndex=TF2Items_GetAttributeId(item, i);
				for(int z; z<attribCount+i; z+=2)
				{
					if(StringToInt(weaponAttribsArray[z])==attribIndex)
					{
						dontAdd=true;
						break;
					}
				}

				if(!dontAdd)
				{
					IntToString(attribIndex, weaponAttribsArray[i+attribCount], 32);
					FloatToString(TF2Items_GetAttributeValue(item, i), weaponAttribsArray[i+1+attribCount], 32);
				}
			}
			attribCount+=2*addattribs;
		}

		if(weapon!=item)  //FlaminSarge: Item might be equal to weapon, so closing item's handle would also close weapon's
		{
			CloseHandle(item);  //probably returns false but whatever (rswallen-apparently not)
		}
	}

	if(name[0]!='\0')
	{
		flags|=OVERRIDE_CLASSNAME;
		TF2Items_SetClassname(weapon, name);
	}

	if(index!=-1)
	{
		flags|=OVERRIDE_ITEM_DEF;
		TF2Items_SetItemIndex(weapon, index);
	}

	if(attribCount>0)
	{
		TF2Items_SetNumAttributes(weapon, attribCount/2);
		int i2;
		for(int i; i<attribCount && i2<16; i+=2)
		{
			int attrib=StringToInt(weaponAttribsArray[i]);
			if(!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", weaponAttribsArray[i], weaponAttribsArray[i+1]);
				CloseHandle(weapon);
				return INVALID_HANDLE;
			}
			TF2Items_SetAttribute(weapon, i2, StringToInt(weaponAttribsArray[i]), StringToFloat(weaponAttribsArray[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}
	TF2Items_SetFlags(weapon, flags);
	return weapon;
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, char[] att)
{
	Handle hWeapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if(hWeapon==INVALID_HANDLE)
	{
		return -1;
	}

	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);

	char atts[32][32];
	int count=ExplodeString(att, ";", atts, 32, 32);

	if(count % 2)
	{
		--count;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2;
		for(int i; i<count; i+=2)
		{
			int attrib=StringToInt(atts[i]);
			if(!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", atts[i], atts[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}

			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(hWeapon, 0);
	}

	int entity=TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock int GetIndexOfWeaponSlot(int client, int slot)
{
	int weapon=GetPlayerWeaponSlot(client, slot);
	return (weapon>MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}
public Action DelayZombify(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if(!IsValidClient(client))
		return;

	int index;
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:
			index=5617;

		case TFClass_Soldier:
			index=5618;

		case TFClass_Pyro:
			index=5624;

		case TFClass_DemoMan:
			index=5620;

		case TFClass_Heavy:
			index=5619;

		case TFClass_Engineer:
			index=5621;

		case TFClass_Medic:
			index=5622;

		case TFClass_Sniper:
			index=5625;

		default:
			index=5623;
	}
	CreateVoodoo(client, index);
}

bool CreateVoodoo(int client, int index)
{
	int voodoo = CreateEntityByName("tf_wearable");

	if(!IsValidEntity(voodoo))
		return false;

	char entclass[64];
	GetEntityNetClass(voodoo, entclass, sizeof(entclass));
	SetEntData(voodoo, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), index);
	SetEntData(voodoo, FindSendPropInfo(entclass, "m_bInitialized"), 1);
	SetEntData(voodoo, FindSendPropInfo(entclass, "m_iEntityQuality"), 13);
	SetEntData(voodoo, FindSendPropInfo(entclass, "m_iEntityLevel"), 1);

	DispatchSpawn(voodoo);
	SDKCall(g_hWearableEquip, client, voodoo);

	return true;
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if(client <= 0 || client > MaxClients)
	{
		return false;
	}
	
	if(!IsClientInGame(client))
	{
		return false;
	}
	
	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}
	
	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while(startEnt > -1 && !IsValidEntity(startEnt))
		startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

stock bool HasRazorback(int iClient)
{
	int iEntity = -1;
	while((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_razorback")) != -1)
	{
		if(IsClassname(iEntity, "tf_wearable_razorback") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 57) return true;
	}
	return false;
}

stock bool RemoveSecondaryWearable(int iClient)
{
	int iEntity = -1;
	while((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_demoshield")) != -1)
	{
		if(IsClassname(iEntity, "tf_wearable_demoshield") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			RemoveEdict(iEntity);
			return true;
		}
	}
	return false;
}

public Action RemoveBackstab(Handle hTimer, any iClient)
{
	if(!validClient(iClient))
		return;
	if(!IsPlayerAlive(iClient))
		return;
	g_bBackstabbed[iClient] = false;
}

bool MusicCanReset(int iMusic)
{
	if(iMusic == MUSIC_INTENSE)
		return false;
	if(iMusic == MUSIC_MILD)
		return false;
	if(iMusic == MUSIC_VERYMILD3)
		return false;
	return true;
}

stock bool IsClassname(int iEntity, char[] strClassname)
{
	if(iEntity <= 0)
		return false;
	if(!IsValidEdict(iEntity))
		return false;
	
	char strClassname2[32];
	GetEdictClassname(iEntity, strClassname2, sizeof(strClassname2));
	if(StrEqual(strClassname, strClassname2, false))
		return true;
	return false;
}

void GiveBonus(int iClient, char[] strBonus)
{
	if(iClient <= 0)
		return;
	if(!IsClientInGame(iClient))
		return;
	if(IsFakeClient(iClient))
		return;

	if(g_hBonus[iClient] == INVALID_HANDLE)
	{
		g_iBonusCombo[iClient] = 0;
		g_bBonusAlt[iClient] = false;
		g_hBonus[iClient] = CreateArray(255);
	}

	PushArrayString(g_hBonus[iClient], strBonus);

	if(g_hBonusTimers[iClient] == INVALID_HANDLE)
		g_hBonusTimers[iClient] = CreateTimer(1.0, ShowBonus, iClient);
}

public Action ShowBonus(Handle hTimer, any iClient)
{
	g_hBonusTimers[iClient] = INVALID_HANDLE;
	
	if(iClient <= 0)
		return Plugin_Handled;
	if(!IsClientInGame(iClient))
		return Plugin_Handled;
	
	
	if(GetArraySize(g_hBonus[iClient]) <= 0)
	{
		ClientCommand(iClient, "r_screenoverlay \"\"");
		CloseHandle(g_hBonus[iClient]);
		g_hBonus[iClient] = INVALID_HANDLE;
		return Plugin_Handled;
	}
	
	if(!g_bBonusAlt[iClient])
	{
		char strEntry[255];
		char strPath[PLATFORM_MAX_PATH];
		GetArrayString(g_hBonus[iClient], 0, strEntry, sizeof(strEntry));
		Format(strPath, sizeof(strPath), "r_screenoverlay\"left4fortress/%s\"", strEntry);
		ClientCommand(iClient, strPath);
		
		int iPitch = g_iBonusCombo[iClient] * 30 + 100;
		if(iPitch > 250)
			iPitch = 250;
		
		int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_AWARD]-1);
		MusicGetPath(MUSIC_AWARD, iRandom, strPath, sizeof(strPath));
		
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		EmitSoundToClient(iClient, strPath, _, _, _, SND_CHANGEPITCH, _, iPitch);
		
		g_iBonusCombo[iClient]++;
		
		if(g_hBonusTimers[iClient] == INVALID_HANDLE) g_hBonusTimers[iClient] = CreateTimer(1.9, ShowBonus, iClient);
	}
	else
	{
		ClientCommand(iClient, "r_screenoverlay \"\"");
		RemoveFromArray(g_hBonus[iClient], 0);
		if(g_hBonusTimers[iClient] == INVALID_HANDLE)
			g_hBonusTimers[iClient] = CreateTimer(0.1, ShowBonus, iClient);
	}
	
	Handle event=CreateEvent("player_escort_score", true);
	SetEventInt(event, "player", iClient);
	SetEventInt(event, "points", 1);
	FireEvent(event);
	
	g_bBonusAlt[iClient] = !g_bBonusAlt[iClient];
	
	return Plugin_Handled;
}

int GetAverageDamage()
{
	int iTotalDamage = 0;
	int iCount = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			iTotalDamage += g_iDamage[i];
			iCount++;
		}
	}
	return RoundFloat(float(iTotalDamage) / float(iCount));
}

void PrecacheBonus(char[] strPath)
{
	char strPath2[PLATFORM_MAX_PATH];
	Format(strPath2, sizeof(strPath2), "materials/left4fortress/%s.vmt", strPath);
	AddFileToDownloadsTable(strPath2);
	Format(strPath2, sizeof(strPath2), "materials/left4fortress/%s.vtf", strPath);
	AddFileToDownloadsTable(strPath2);
}

int GetActivePlayerCount()
{
	int i = 0;
	for(int j = 1; j <= MaxClients; j++)
	{
		if(validActivePlayer(j))
			i++;
	}
	return i;
}

void DetermineControlPoints()
{
	g_bCapturingLastPoint = false;
	g_iControlPoints = 0;
	
	for(int i = 0; i < sizeof(g_iControlPointsInfo); i++)
	{
		g_iControlPointsInfo[i][0] = -1;
	}
	
	//LogMessage("SZF: Calculating cps...");
	
	int iMaster = -1;

	int iEntity = -1;
	while((iEntity = FindEntityByClassname2(iEntity, "team_control_point_master")) != -1)
	{
		if(IsClassname(iEntity, "team_control_point_master"))
		{
			iMaster = iEntity;
		}
	}
	
	if(iMaster <= 0)
	{
		//LogMessage("No master found");
		return;
	}
	
	iEntity = -1;
	while((iEntity = FindEntityByClassname2(iEntity, "team_control_point")) != -1)
	{
		if(IsClassname(iEntity, "team_control_point") && g_iControlPoints < sizeof(g_iControlPointsInfo))
		{
			int iIndex = GetEntProp(iEntity, Prop_Data, "m_iPointIndex");			
			g_iControlPointsInfo[g_iControlPoints][0] = iIndex;
			g_iControlPointsInfo[g_iControlPoints][1] = 0;
			g_iControlPoints++;
			
			//LogMessage("Found CP with index %d", iIndex);
		}
	}
	
	//LogMessage("Found a total of %d cps", g_iControlPoints);
	
	CheckRemainingCP();
}

public Action OnCPCapture(Handle hEvent, const char[] strName, bool bHide)
{
	if(g_iControlPoints <= 0)
		return;
	
	//LogMessage("Captured CP");

	int iCaptureIndex = GetEventInt(hEvent, "cp");
	if(iCaptureIndex < 0)
		return;
	if(iCaptureIndex >= g_iControlPoints)
		return;
	
	for(int i = 0; i < g_iControlPoints; i++)
	{
		if(g_iControlPointsInfo[i][0] == iCaptureIndex)
		{
			g_iControlPointsInfo[i][1] = 2;
		}
	}
	
	CheckRemainingCP();
}

public Action OnCPCaptureStart(Handle hEvent, const char[] strName, bool bHide)
{
	if(g_iControlPoints <= 0)
		return;

	int iCaptureIndex = GetEventInt(hEvent, "cp");
	//LogMessage("Began capturing CP #%d / (total %d)", iCaptureIndex, g_iControlPoints);
	if(iCaptureIndex < 0)
		return;
	if(iCaptureIndex >= g_iControlPoints)
		return;
	
	for(int i = 0; i < g_iControlPoints; i++)
	{
		if(g_iControlPointsInfo[i][0] == iCaptureIndex)
		{
			g_iControlPointsInfo[i][1] = 1;
			//LogMessage("Set capture status on %d to 1", i);
		}
	}
	
	//LogMessage("Done with capturing CP event");
	
	CheckRemainingCP();
}

void CheckRemainingCP()
{
	g_bCapturingLastPoint = false;
	if(g_iControlPoints <= 0)
		return;
	
	//LogMessage("Checking remaining CP");

	int iCaptureCount = 0;
	int iCapturing = 0;
	for(int i = 0; i < g_iControlPoints; i++)
	{
		if(g_iControlPointsInfo[i][1] >= 2)
			iCaptureCount++;
		if(g_iControlPointsInfo[i][1] == 1)
			iCapturing++;
	}
	
	//LogMessage("Capture count: %d, Max CPs: %d, Capturing: %d", iCaptureCount, g_iControlPoints, iCapturing);
	
	if(iCaptureCount == g_iControlPoints-1 && iCapturing > 0)
	{
		g_bCapturingLastPoint = true;
		if(g_fZombieDamageScale < 1.0 && !g_bTankOnce)
			ZombieTank();
	}
}

TFClassWeapon GetWeaponInfoFromModel(char[] strModel, int &iSlot, int &iSwitchSlot, Handle &hWeapon, bool &bWearable, char[] strName, int iMaxSize)
{
	TFClassWeapon iClass = TFClassWeapon_Unknown;
	
	if(StrEqual(strModel, "models/weapons/c_models/c_lochnload/c_lochnload.mdl"))
	{
		hWeapon = hWeaponLochNLoad;
		iSlot = 0;
		iClass = TFClassWeapon_DemoMan;
		strcopy(strName, iMaxSize, "Loch'n'Load");
	}
	else if(StrEqual(strModel, "models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl"))
	{
		hWeapon = hWeaponFlareGun;
		iSlot = 1;
		iClass = TFClassWeapon_Pyro;
		strcopy(strName, iMaxSize, "Flaregun");
	}
	else if(StrEqual(strModel, "models/weapons/w_models/w_shotgun.mdl"))
	{
		hWeapon = hWeaponShotgunPyro;
		iSlot = 1;
		iClass = TFClassWeapon_Group_Shotgun;
		strcopy(strName, iMaxSize, "Shotgun");
	}
	else if(StrEqual(strModel, "models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl"))
	{
		hWeapon = hWeaponBison;
		iSlot = 1;
		iClass = TFClassWeapon_Soldier;
		strcopy(strName, iMaxSize, "Righteous Bison");
	}
	else if(StrEqual(strModel, "models/weapons/c_models/c_targe/c_targe.mdl"))
	{
		hWeapon = hWeaponTarge;
		iSlot = 1;
		iSwitchSlot = 2;
		bWearable = true;
		strcopy(strName, iMaxSize, "Chargin' Targe");
	}
	if(iSwitchSlot < 0)
		iSwitchSlot = iSlot;
	
	return iClass;
}

bool AttemptGrabItem(int iClient)
{
	int iTarget = GetClientPointVisible(iClient);
	bool isWeapon;

	#if debugmode
	char strClassname[255];
	GetEdictClassname(iTarget, strClassname, sizeof(strClassname));
	PrintToChat(iClient, "%s", strClassname);
	#else
	if(!IsClassname(iTarget, "prop_dynamic"))
		return false;
	#endif

	/*char name[64];
	GetEntPropString(iTarget, Prop_Data, "m_iName", name, sizeof(name));
	if(!StrContains(name, "szf_weapon", false))
	{
		isWeapon = true;
	}
	#if debugmode
	PrintToChat(iClient, "iTarget: %i | Weapon: %i | Solid: %i (%i)", iTarget, isWeapon ? 1 : 0, GetEntProp(iTarget, Prop_Send, "m_nSolidType"), GetEntProp(iTarget, Prop_Send, "m_usSolidFlags"));
	#else
	if((iTarget<=0 || !isWeapon))
	{
		return false;
	}
	#endif*/

	char strModel[255];
	GetEntityModel(iTarget, strModel, sizeof(strModel));
	PrintToChat(iClient, "%s", strModel);

	if(TF2_GetPlayerClass(iClient) == TFClass_Soldier) // Soldier Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_shotgun.mdl") || StrEqual(strModel, "models/weapons/c_models/c_shotgun/c_shotgun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun_soldier", 10, 1, "", 0, 38, 0);
		}
		else if((StrEqual(strModel, "models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl") || StrEqual(strModel, "models/weapons/w_models/w_frontierjustice.mdl")) && cvarExtraClass)
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun_soldier", 141, 0, "869 ; 1", 0, 35, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_rocketlauncher/c_rocketlauncher.mdl") || StrEqual(strModel, "models/weapons/w_models/w_rocketlauncher.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_rocketlauncher", 18, 1, "59 ; 0.5 ; 77 ; 0.75 ; 135 ; 0.5", 0, 19, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_blackbox/c_blackbox.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_rocketlauncher", 228, 0, "59 ; 0.5 ; 77 ; 0.75 ; 135 ; 0.5", 0, 18, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_directhit/c_directhit.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_rocketlauncher_directhit", 127, 0, "59 ; 0.5 ; 77 ; 0.75 ; 135 ; 0.5", 0, 19, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bet_rocketlauncher/c_bet_rocketlauncher.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_rocketlauncher", 513, 0, "59 ; 0.5 ; 77 ; 0.75 ; 135 ; 0.5", 0, 19, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun_soldier", 415, 0, "", 0, 36, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_raygun", 442, 0, "5 ; 1.25 ; 96 ; 1.35", 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_liberty_launcher/c_liberty_launcher.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_rocketlauncher", 414, 0, "59 ; 0.5 ; 77 ; 0.75 ; 135 ; 0.5", 0, 20, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_particle_cannon", 441, 0, "5 ; 1.35 ; 59 ; 0.5 ; 72 ; 0.5 ; 77 ; 0.75 ; 96 ; 1.5 ; 135 ; 0.5", 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_shogun_warhorn/c_shogun_warhorn.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_buff_item", 354, 0, "57 ; 0 ; 190 ; 1 ; 319 ; 0.6", 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bugle/c_bugle.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_buff_item", 129, 0, "319 ; 0.6", 0);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Pyro) // Pyro Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_shotgun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun_pyro", 12, 1, "", 0, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_shotgun/c_shotgun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun_pyro", 12, 1, "", 0, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_frontierjustice.mdl") && cvarExtraClass)
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun_pyro", 141, 0, "869 ; 1", 0, 35, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl") && cvarExtraClass)
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun_pyro", 141, 0, "869 ; 1", 0, 35, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_flaregun", 39, 0, "", 0, 16);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_detonator/c_detonator.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_flaregun", 351, 0, "", 0, 16);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_shotgun", 415, 0, "", 0, 36, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_degreaser/c_degreaser.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_flamethrower", 215, 0, "77 ; 0.5 ; 869 ; 1", 0, 100);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_phlogistinator/c_drg_phlogistinator.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_flamethrower", 594, 0, "77 ; 0.5 ; 869 ; 1", 0, 100);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_flamethrower/c_flamethrower.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_flamethrower", 21, 1, "77 ; 0.5 ; 869 ; 1", 0, 100);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_manmelter/c_drg_manmelter.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_flaregun_revenge", 595, 0, "", 0);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_DemoMan) // Demoman Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_grenadelauncher.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_grenadelauncher", 19, 1, "77 ; 0.75", 0, 15, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_scottish_resistance.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_pipebomblauncher", 130, 0, "59 ; 0.25 ; 78 ; 1 ; 135 ; 0.5", 0, 32, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_lochnload/c_lochnload.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_grenadelauncher", 308, 0, "77 ; 0.75", 0, 15, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_stickybomb_launcher.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_pipebomblauncher", 20, 1, "59 ; 0.25 ; 79 ; 0.75 ; 135 ; 0.5", 0, 24, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_sticky_jumper/c_sticky_jumper.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_pipebomblauncher", 265, 0, "59 ; 0.35 ; 79 ; 0.75 ; 135 ; 0.5", 0, 48, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_targe/c_targe.mdl"))
		{
			
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_persian_shield/c_persian_shield.mdl"))
		{
			
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Engineer) // Engineer Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_shotgun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_shotgun_primary", 9, 1, "", 0, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_shotgun/c_shotgun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_shotgun_primary", 9, 1, "", 0, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_dex_shotgun/c_dex_shotgun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_shotgun_primary", 9, 1, "", 0, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl") && cvarExtraClass)
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_shotgun_primary", 415, 0, "", 0, 36, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_ttg_max_gun/c_ttg_max_gun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_pistol", 160, 0, "79 ; 0.24", 0, 60, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_frontierjustice.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_sentry_revenge", 141, 0, "869 ; 1", 0, 35, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_sentry_revenge", 141, 0, "869 ; 1", 0, 35, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_wrangler.mdl") || StrEqual(strModel, "models/weapons/w_models/w_wrangler.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_laser_pointer", 140, 0, "", 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_pistol/c_pistol.mdl") || StrEqual(strModel, "models/weapons/w_models/w_pistol.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_pistol", 22, 1, "79 ; 0.24", 0, 60, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_drg_pomson", 588, 0, "5 ; 1.2 ; 96 ; 1.35", 0);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Medic) // Medic Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/c_models/c_medigun/c_medigun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_medigun", 29, 1, "9 ; 0.2", 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_proto_medigun/c_proto_medigun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_medigun", 411, 0, "9 ; 0.2", 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_syringegun/c_syringegun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_syringegun_medic", 17, 1, "", 0, 190, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_syringegun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_syringegun_medic", 17, 1, "", 0, 190, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_proto_syringegun/c_proto_syringegun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_syringegun_medic", 412, 0, "", 0, 190, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_crusaders_crossbow/c_crusaders_crossbow.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_crossbow", 305, 0, "2 ; 3 ; 77 ; 0.2 ; 138 ; 0.333 ; 775 ; 0.333", 0, 31, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_leechgun/c_leechgun.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_syringegun_medic", 36, 0, "16 ; 1 ; 129 ; 0 ; 191 ; -2", 0, 190, 0);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Sniper) // Sniper Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_sniperrifle.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_sniperrife", 14, 1, "", 0, 25);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_smg.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_smg", 16, 1, "", 0, 100, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bazaar_sniper/c_bazaar_sniper.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_sniperrifle", 402, 0, "", 0, 25);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_dex_sniperrifle/c_dex_sniperrifle.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_sniperrifle", 526, 0, "", 0, 25);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/urinejar.mdl"))
		{
			CreateWeapon(iClient, iTarget, 1, "tf_weapon_jar", 58, 0, "249 ; 0.4", 0, 1);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bow/c_bow.mdl"))
		{
			CreateWeapon(iClient, iTarget, 0, "tf_weapon_compound_bow", 56, 0, "", 0, 13, 0); 
		}
	}
	return true;
}

stock int CreateWeapon(int client, int target, int slot, char[] name, int index, int type, char[] att, int override=0, int ammo=-1, int clip=-1)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
	if(hWeapon == INVALID_HANDLE)
	{
		return -1;
	}
	
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	if(type>1)
	{
		TF2Items_SetLevel(hWeapon, GetRandomInt(1, 100));
		TF2Items_SetQuality(hWeapon, 6);
	}
	else if(type>0)
	{
		TF2Items_SetLevel(hWeapon, 1);
		TF2Items_SetQuality(hWeapon, 0);
	}
	else
	{
		TF2Items_SetLevel(hWeapon, 5);
		TF2Items_SetQuality(hWeapon, 6);
	}
	if(override<1)
	{
		TF2Items_SetFlags(hWeapon, PRESERVE_ATTRIBUTES);
	}
	char atts[32][32];
	int count = ExplodeString(att, ";", atts, 32, 32);
	
	if(count % 2)
	{
		--count;
	}
	
	if(count>0)
	{
		TF2Items_SetNumAttributes(hWeapon, count / 2);
		int i2;
		for(int i; i<count; i+=2)
		{
			int attrib = StringToInt(atts[i]);
			if (!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", atts[i], atts[i + 1]);
				CloseHandle(hWeapon);
				return -1;
			}
			
			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(atts[i + 1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(hWeapon, 0);
	}

	TF2_RemoveWeaponSlot(client, slot);
	
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);

	EquipPlayerWeapon(client, entity);

	SetAmmo(client, entity, ammo, clip);

	ClientCommand(client, "playgamesound ui/item_heavy_gun_drop.wav");
	ClientCommand(client, "playgamesound ui/item_heavy_gun_pickup.wav");

	if(cvarRemoveWeapon && roundState()==RoundActive)
	{
		AcceptEntityInput(target, "Kill");
	}

	return entity;
}

stock void SetAmmo(int client, int weapon, int ammo=-1, int clip=-1)
{
	if(IsValidEntity(weapon))
	{
		if(clip>-1)
		{
			SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
		}

		int ammoType=(ammo>-1 ? GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") : -1);
		if(ammoType!=-1)
		{
			SetEntProp(client, Prop_Data, "m_iAmmo", ammo, _, ammoType);
		}
		else if(ammo>-1)  //Only complain if we're trying to set ammo
		{
			char classname[64];
			GetEdictClassname(weapon, classname, sizeof(classname));
			LogError("[SZF] Cannot give ammo to weapon %s!", classname);
		}
	}
}

void GetModelPath(int iIndex, char[] strModel, int iMaxSize)
{
	int iTable = FindStringTable("modelprecache");
	ReadStringTable(iTable, iIndex, strModel, iMaxSize);
}

void GetEntityModel(int iEntity, char[] strModel, int iMaxSize, char[] strPropName = "m_nModelIndex")
{
	//m_iWorldModelIndex
	int iIndex = GetEntProp(iEntity, Prop_Send, strPropName);
	GetModelPath(iIndex, strModel, iMaxSize);
}

void CheckStartWeapons()
{
	/*int iClassesWithoutWeapons[10] = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(validLivingSur(i) && !DoesPlayerHaveRealWeapon(i))
		{
			TFClassType iClass = TF2_GetPlayerClass(i);
			iClassesWithoutWeapons[iClass]++;
			//PrintToChat(i, "You do not have a real weapon");
		}
	}
	
	char strModel[PLATFORM_MAX_PATH];

	int iEntity = -1;
	while((iEntity = FindEntityByClassname2(iEntity, "prop_dynamic")) != -1)
	{
		if(IsClassname(iEntity, "prop_dynamic") && GetWeaponType(iEntity) == 1)
		{
			GetEntityModel(iEntity, strModel, sizeof(strModel));
			TFClassWeapon iClass = GetWeaponClass(strModel);
			
			Handle hArray = CreateArray();
			if(iClass == TFClassWeapon_Group_Shotgun)
			{
				PushArrayCell(hArray, TFClassWeapon_Soldier);
				PushArrayCell(hArray, TFClassWeapon_Heavy);
				PushArrayCell(hArray, TFClassWeapon_Pyro);
				PushArrayCell(hArray, TFClassWeapon_Engineer);
			}
			else
			{
				PushArrayCell(hArray, iClass);
			}
			
			
			bool bEnable = false;
			for(int i = 0; i < GetArraySize(hArray); i++)
			{
				int iClass2 = GetArrayCell(hArray, i);
				//PrintToServer("Class: %d", iClass2);
				if(iClassesWithoutWeapons[iClass2] > 0)
				{
					bEnable = true;
					iClassesWithoutWeapons[iClass2]--;
					//PrintToChatAll("Enabling weapon %s", strModel);
				}
			}
			
			if(bEnable)
			{
				AcceptEntityInput(iEntity, "TurnOn");
				AcceptEntityInput(iEntity, "EnableCollision");
			}
			else
			{
				AcceptEntityInput(iEntity, "TurnOff");
				AcceptEntityInput(iEntity, "DisableCollision");
			}
		}
	}*/
}

int GetWeaponType(int iEntity)
{
	char strName[255];
	GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));
	if(StrEqual(strName, "szf_weapons_spawn", false))
		return 1;
	
	return 0;
}

TFClassWeapon GetWeaponClass(char[] strModel)
{	
	Handle hWeapon = INVALID_HANDLE;
	int iSlot = -1;
	int iSwitchSlot = -1;
	bool bWearable = false;
	char strName[255];
	
	TFClassWeapon iWeaponClass = GetWeaponInfoFromModel(strModel, iSlot, iSwitchSlot, hWeapon, bWearable, strName, sizeof(strName));
	
	return iWeaponClass;
}

bool DoesPlayerHaveRealWeapon(int iClient)
{
	int iEntity = GetPlayerWeaponSlot(iClient, 0);
	if(iEntity > 0 && IsValidEdict(iEntity))
		return true;
	iEntity = GetPlayerWeaponSlot(iClient, 1);
	if(iEntity > 0 && IsValidEdict(iEntity))
		return true;
	
	return false;
}

bool AttemptCarryItem(int iClient)
{
	if(DropCarryingItem(iClient))
		return true;

	int iTarget = GetClientPointVisible(iClient);
	
	char strClassname[255];
	if(iTarget > 0)
		GetEdictClassname(iTarget, strClassname, sizeof(strClassname));
	if(iTarget <= 0 || !IsClassname(iTarget, "prop_physics"))
		return false;

	char strName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", strName, sizeof(strName));
	if(!StrEqual(strName, "gascan", false))
		return false;
	
	g_iCarryingItem[iClient] = iTarget;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 0);
	//PrintToChat(iClient, "Picked up gas can %d", iTarget);
	AcceptEntityInput(iTarget, "DisableMotion");
	//PrintToChat(iClient, "m_usSolidFlags: %d", GetEntProp(iTarget, Prop_Send, "m_usSolidFlags"));
	//SetEntProp(iTarget, Prop_Send, "m_nSolidType", 0);
	
	ClientCommand(iClient, "playgamesound ui/item_paint_can_pickup.wav");
	ClientCommand(iClient, "playgamesound ui/item_paint_can_pickup.wav");
	
	return true;
}

void UpdateClientCarrying(int iClient)
{
	int iTarget = g_iCarryingItem[iClient];
	
	//PrintCenterText(iClient, "Teleporting gas can (%d)", iTarget);
	
	if(iTarget <= 0)
		return;
	if(!IsClassname(iTarget, "prop_physics"))
	{
		DropCarryingItem(iClient);
		return;
	}
	
	//PrintCenterText(iClient, "Teleporting gas can 1");
	
	char strName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", strName, sizeof(strName));
	if(!StrEqual(strName, "gascan", false))
		return;
	
	float vOrigin[3], vAngles[3], vDistance[3];
	float vEmpty[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);
	vAngles[0] = 5.0;
	
	vOrigin[2] -= 20.0;
	
	vAngles[2] += 35.0;
	AnglesToVelocity(vAngles, vDistance, 60.0);
	AddVectors(vOrigin, vDistance, vOrigin);
	TeleportEntity(iTarget, vOrigin, vAngles, vEmpty);
	
	//PrintCenterText(iClient, "Teleporting gas can");
}

bool DropCarryingItem(int iClient, bool bDrop = true)
{
	int iTarget = g_iCarryingItem[iClient];
	if(iTarget <= 0)
		return false;
	
	g_iCarryingItem[iClient] = -1;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 1);
	
	if(!IsClassname(iTarget, "prop_physics"))
		return true;
	
	//PrintToChat(iClient, "Dropped gas can");
	//SetEntProp(iTarget, Prop_Send, "m_nSolidType", 6);
	AcceptEntityInput(iTarget, "EnableMotion");
   
	if(bDrop && (IsEntityStuck(iTarget) || ObstancleBetweenEntities(iClient, iTarget)))
	{
		float vOrigin[3];
		GetClientEyePosition(iClient, vOrigin);
		TeleportEntity(iTarget, vOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	return true;
}

stock void AnglesToVelocity(float fAngle[3], float fVelocity[3], float fSpeed = 1.0)
{
	fVelocity[0] = Cosine(DegToRad(fAngle[1]));
	fVelocity[1] = Sine(DegToRad(fAngle[1]));
	fVelocity[2] = Sine(DegToRad(fAngle[0])) * -1.0;
	
	NormalizeVector(fVelocity, fVelocity);
	
	ScaleVector(fVelocity, fSpeed);
}

stock bool IsEntityStuck(int iEntity)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceDontHitEntity, iEntity);
	return (TR_DidHit());
}

void ForceTeamWin(int team)
{
	int entity = FindEntityByClassname2(-1, "team_control_point_master");
	if(!IsValidEntity(entity))
	{
		entity = CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}
	SetVariantInt(team);
	AcceptEntityInput(entity, "SetWinner");
}

public void OnItemSpawned(int entity)
{
	SDKHook(entity, SDKHook_StartTouch, OnPickup);
	SDKHook(entity, SDKHook_Touch, OnPickup);
}

public Action OnPickup(int entity, int client)  //Thanks friagram!
{
	if(GetClientTeam(client)==ZomTeam && Enabled)
	{
		char classname[32];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(!StrContains(classname, "item_healthkit") || !StrContains(classname, "item_ammopack") || StrEqual(classname, "tf_ammo_pack"))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void SetClientGlow(int client, float time1, float time2=-1.0)
{
	if(IsValidClient(client))
	{
		GlowTimer[client]+=time1;
		if(time2>=0)
		{
			GlowTimer[client]=time2;
		}

		if(GlowTimer[client]<=0.0)
		{
			GlowTimer[client]=0.0;
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
		}
	}
}

#file "Super Zombie Fortress"
