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
#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>
#define REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#tryinclude <tf2attributes>
#define REQUIRE_PLUGIN

#include "szf_util_base.inc"
#include "szf_util_pref.inc"

//
// Plugin Information
//
#define MAJOR_REVISION "2"
#define MINOR_REVISION "0"
#define STABLE_REVISION "0"
#define DEV_REVISION "Build-3"
#if !defined DEV_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION..." "...DEV_REVISION
#endif

#if defined _steamtools_included
new bool:steamtools = false;
#endif

#if defined _tf2attributes_included
new bool:tf2attributes = false;
#endif

#if !defined DEV_REVISION
new bool:debugmode = false;
#else
new bool:debugmode = true;
#endif

Handle g_hWeaponEquip;
Handle g_hWWeaponEquip;
Handle g_hGameConfig;

public Plugin:myinfo = 
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

//
// State
//

// Global State
new zf_bEnabled;
new zf_bNewRound;
new zf_spawnSurvivorsKilledCounter;
new zf_spawnZombiesKilledCounter;
// Client State
new szf_critBonus[MAXPLAYERS+1];
new zf_hoardeBonus[MAXPLAYERS+1];
new zf_rageTimer[MAXPLAYERS+1];

// Global Timer Handles
new Handle:szf_tMain;
new Handle:szf_tMainFast;
new Handle:szf_tMainSlow;
new Handle:szf_tHoarde;
new Handle:szf_tDataCollect;

// Cvar Handles
new Handle:szf_cvForceOn;
new Handle:szf_cvRatio;
new Handle:szf_cvAllowTeamPref;
new Handle:szf_cvSwapOnPayload;
new Handle:szf_cvSwapOnAttdef;
new Handle:szf_cvTankHealth;
new Handle:szf_cvTankHealthMin;
new Handle:szf_cvTankHealthMax;
new Handle:szf_cvTankTime;
new Handle:szf_cvFrenzyChance;
new Handle:szf_cvFrenzyTankChance;
new Handle:szf_cvRemoveWeapon;
new Handle:szf_cvTankOnce;

new Float:g_fZombieDamageScale = 1.0;

new g_StartTime = 0;
new g_AdditionalTime = 0;

// Sound system
new Handle:g_hMusicArray = INVALID_HANDLE;
new Handle:g_hFastRespawnArray = INVALID_HANDLE;

new Handle:hConfiguration = INVALID_HANDLE;
new Handle:hEquipWearable = INVALID_HANDLE;

new Handle:hWeaponSandman = INVALID_HANDLE;
new Handle:hWeaponWatch = INVALID_HANDLE;
new Handle:hWeaponStickyLauncher = INVALID_HANDLE;
new Handle:hWeaponRocketLauncher = INVALID_HANDLE;
new Handle:hWeaponSword = INVALID_HANDLE;
new Handle:hWeaponShovel = INVALID_HANDLE;
new Handle:hWeaponFists = INVALID_HANDLE;
new Handle:hWeaponSteelFists = INVALID_HANDLE;
new Handle:hWeaponSyringe = INVALID_HANDLE;
new Handle:hWeaponBonesaw = INVALID_HANDLE;
new Handle:hWeaponLochNLoad = INVALID_HANDLE;
new Handle:hWeaponFlareGun = INVALID_HANDLE;
new Handle:hWeaponShotgunPyro = INVALID_HANDLE;
new Handle:hWeaponShotgunSoldier = INVALID_HANDLE;
new Handle:hWeaponBison = INVALID_HANDLE;
new Handle:hWeaponTarge = INVALID_HANDLE;

new bool:g_bBackstabbed[MAXPLAYERS+1] = false;
new Handle:g_hBonus[MAXPLAYERS+1] = INVALID_HANDLE;
new Handle:g_hBonusTimers[MAXPLAYERS+1] = INVALID_HANDLE;
new g_iBonusCombo[MAXPLAYERS+1] = 0;
new g_iHitBonusCombo[MAXPLAYERS+1] = 0;
new bool:g_bBonusAlt[MAXPLAYERS+1] = false;
new Float:g_fDamageTakenLife[MAXPLAYERS+1] = 0.0;
new Float:g_fDamageDealtLife[MAXPLAYERS+1] = 0.0;
new bool:g_bRoundActive = false;

new g_iControlPointsInfo[20][2];
new g_iControlPoints = 0;
new bool:g_bCapturingLastPoint = false;
new g_iCarryingItem[MAXPLAYERS+1] = -1;

#define GAMEMODE_DEFAULT	0
#define GAMEMODE_NEW		1
new g_iMode = GAMEMODE_DEFAULT;

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
#define MUSIC_MAX		20

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
#define INFECTED_TANK	1

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


new g_iMusicCount[MUSIC_MAX] = 0;
new String:g_strMusicLast[MAXPLAYERS+1][MUSIC_MAX][PLATFORM_MAX_PATH];
new g_iMusicLevel[MAXPLAYERS+1] = 0;
new Handle:g_hMusicTimer[MAXPLAYERS+1] = INVALID_HANDLE;
new g_iMusicRandom[MAXPLAYERS+1][2];
new g_iMusicFull[MAXPLAYERS+1] = 0;
new Handle:g_hGoo = INVALID_HANDLE;

new bool:g_bZombieRage = false;
new g_iZombieTank = 0;
new bool:g_bZombieRageAllowRespawn = false;
new g_iGooId = 0;
new g_iGooMultiplier[MAXPLAYERS+1] = 0;
new bool:g_bGooified[MAXPLAYERS+1] = false;
new bool:g_bHitOnce[MAXPLAYERS+1] = false;

new g_iSpecialInfected[MAXPLAYERS+1] = 0;
new g_iDamage[MAXPLAYERS+1] = 0;
new g_iKillsThisLife[MAXPLAYERS+1] = 0;
new g_iSuperHealth[MAXPLAYERS+1] = 0;
new g_iSuperHealthSubtract[MAXPLAYERS+1] = 0;
new g_iStartSurvivors = 0;

new bool:g_bTankOnce = false;

new String:g_strSoundFleshHit[][128] =
{
	"physics/flesh/flesh_impact_bullet1.wav",
	"physics/flesh/flesh_impact_bullet2.wav",
	"physics/flesh/flesh_impact_bullet3.wav",
	"physics/flesh/flesh_impact_bullet4.wav",
	"physics/flesh/flesh_impact_bullet5.wav"
};

new String:g_strSoundCritHit[][128] =
{
	"player/crit_received1.wav",
	"player/crit_received2.wav",
	"player/crit_received3.wav"
};

////////////////////////////////////////////////////////////
//
// Sourcemod Callbacks
//
////////////////////////////////////////////////////////////
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	#if defined _steamtools_included
	MarkNativeAsOptional("Steam_SetGameDescription");
	#endif
	
	#if defined _tf2attributes_included
	MarkNativeAsOptional("TF2Attrib_SetByDefIndex");
	MarkNativeAsOptional("TF2Attrib_RemoveByDefIndex");
	#endif
	return APLRes_Success;

}
public OnPluginStart()
{
	// Check for necessary extensions
	if(GetExtensionFileStatus("sdkhooks.ext") < 1)
		SetFailState("SDK Hooks is not loaded.");
	LoadTranslations("super_zombie_fortress.phrases");
	// Add server tag.
	AddServerTag("zf");
	AddServerTag("szf");	

	// Initialize global state
	zf_bEnabled = false;
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
	szf_cvForceOn = CreateConVar("szf_force_on", "1", "<0/1> Activate ZF for non-ZF maps.", _, true, 0.0, true, 1.0);
	szf_cvRatio = CreateConVar("szf_ratio", "0.8", "<0.01-1.00> Percentage of players that start as survivors.", _, true, 0.01, true, 1.0);
	szf_cvAllowTeamPref = CreateConVar("szf_allowteampref", "0", "<0/1> Allow use of team preference criteria.", _, true, 0.0, true, 1.0);
	szf_cvSwapOnPayload = CreateConVar("szf_swaponpayload", "1", "<0/1> Swap teams on non-ZF payload maps.", _, true, 0.0, true, 1.0);
	szf_cvSwapOnAttdef = CreateConVar("szf_swaponattdef", "1", "<0/1> Swap teams on non-ZF attack/defend maps.", _, true, 0.0, true, 1.0);
	szf_cvTankHealth = CreateConVar("sszf_tank_health", "400", "Amount of health the Tank gets per alive survivor", _, true, 10.0);
	szf_cvTankHealthMin = CreateConVar("sszf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with", _, true, 0.0);
	szf_cvTankHealthMax = CreateConVar("sszf_tank_health_max", "8000", "Maximum amount of health the Tank can spawn with", _, true, 0.0);
	szf_cvTankTime = CreateConVar("szf_tank_time", "50.0", "Adjusts the damage the Tank takes per second. If the value is 70.0, the Tank will take damage that will make him die (if unhurt by survivors) after 70 seconds. 0 to disable.", _, true, 0.0);
	szf_cvFrenzyChance = CreateConVar("szf_frenzy_chance", "5.0", "% Chance of a random frenzy", _, true, 0.0);
	szf_cvFrenzyTankChance = CreateConVar("szf_frenzy_tank", "25.0", "% Chance of a Tank appearing instead of a frenzy", _, true, 0.0);
	szf_cvRemoveWeapon = CreateConVar("szf_pickup_remove", "1.0", "0-Leave weapon, 1-Remove weapon once picked up", _, true, 0.0, true, 1.0);
	szf_cvTankOnce = CreateConVar("szf_tank_once", "60.0", "Every round there is at least one Tank. If no Tank has appeared, a Tank will be manually created when there is sm_szf_tank_once time left. Ie. if the value is 60, the Tank will be spawned when there's 60% of the time left.", _, true, 0.0);

	// Hook events
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_setup_finished", OnSetupEnd);
	HookEvent("teamplay_round_win", OnRoundEnd);
	HookEvent("teamplay_timer_time_added", OnTimeAdded);
	HookEvent("player_spawn", OnPlayerSpawn);	
	HookEvent("player_death", OnPlayerDeath);
	
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
	AddCommandListener(OnJoinClass, "joinclass");
	AddCommandListener(OnCallMedic, "voicemenu"); 
	// Hook Client Console Commands	
	//AddCommandListener(CommandTeamPref, "szf_teampref");
	// Hook Client Chat / Console Commands
	RegConsoleCmd("szf", CommandMenu);
	RegConsoleCmd("szf_menu", CommandMenu);
	RegConsoleCmd("szf_pref", CommandTeamPref);
	
	g_hGameConfig = LoadGameConfigFile("szf_gamedata");
	
	if(!g_hGameConfig)
	{
		SetFailState("Failed to find szf_gamedata.txt gamedata! Can't continue.");
	}	
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "WeaponEquip");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWeaponEquip = EndPrepSDKCall();
	
	if(!g_hWeaponEquip)
	{
		SetFailState("Failed to prepare the SDKCall for giving weapons. Try updating gamedata or restarting your server.");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWWeaponEquip = EndPrepSDKCall();
	
	if(!g_hWWeaponEquip)
	{
		SetFailState("Failed to prepare the SDKCall for giving weapons. Try updating gamedata or restarting your server.");
	}
	
	CreateTimer(10.0, SpookySound, 0, TIMER_REPEAT);
	
	SetupSDK();
	SetupWeapons();
	CheckStartWeapons();

	#if defined _steamtools_included
	steamtools = LibraryExists("SteamTools");
	#endif
	
	#if defined _tf2attributes_included
	tf2attributes = LibraryExists("tf2attributes");
	#endif
}

public OnLibraryAdded(const String:name[])
{
	#if defined _steamtools_included
	if(!strcmp(name, "SteamTools", false))
	{
		steamtools = true;
	}
	#endif
	
	#if defined _tf2attributes_included
	if(!strcmp(name, "tf2attributes", false))
	{
		tf2attributes = true;
	}
	#endif
}

public OnLibraryRemoved(const String:name[])
{
	#if defined _steamtools_included
	if(!strcmp(name, "SteamTools", false))
	{
		steamtools = false;
	}
	#endif
	
	#if defined _tf2attributes_included
	if(!strcmp(name, "tf2attributes", false))
	{
		tf2attributes = false;
	}
	#endif
}

public OnConfigsExecuted()
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
		GetConVarBool(szf_cvForceOn) ? zfEnable() : zfDisable();
	} 

	setRoundState(RoundInit1);
}	

public OnMapEnd()
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
	
public OnClientPostAdminCheck(client)
{
	if(!zf_bEnabled)
		return;
	
	CreateTimer(10.0, timer_initialHelp, client, TIMER_FLAG_NO_MAPCHANGE);
	
	SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	g_iDamage[client] = GetAverageDamage();
	
	pref_OnClientConnect(client);
}

public OnClientDisconnect(client)
{
	if(!zf_bEnabled)
		return;
	pref_OnClientDisconnect(client);
	StopSoundSystem(client);
	DropCarryingItem(client);
	if(client == g_iZombieTank)
		g_iZombieTank = 0;
}

public OnGameFrame()
{
	if(!zf_bEnabled)
		return;	
	handle_gameFrameLogic();
}

////////////////////////////////////////////////////////////
//
// SDKHooks Callbacks
//
////////////////////////////////////////////////////////////
public OnPreThinkPost(client)
{	
	if(!zf_bEnabled)
		return;
	
	//
	// Handle speed bonuses.
	//
	if(validLivingClient(client) && !isSlowed(client) && !isDazed(client) && !isCharging(client))
	{
		new Float:speed = clientBaseSpeed(client) + clientBonusSpeed(client);
		if(g_iSpecialInfected[client] == INFECTED_TANK && g_fDamageDealtLife[client] <= 0.0 && g_fDamageTakenLife[client] <= 0.0)
		{
			speed = 450.0;
		}
		setClientSpeed(client, speed);
	}
	
	UpdateClientCarrying(client);
}

#define DMGTYPE_MELEE					 134221952
#define DMGTYPE_MELEE_CRIT				135270528

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflicter, &Float:fDamage, &iDamagetype, &iWeapon, Float:fForce[3], Float:fForcePos[3])
{  
	if(!zf_bEnabled)
		return Plugin_Continue;
	if(!CanRecieveDamage(iVictim))
		return Plugin_Continue;
	
	new bool:bChanged = false;
	if(validClient(iVictim) && validClient(iAttacker))
	{
		g_bHitOnce[iVictim] = true;
		g_bHitOnce[iAttacker] = true;
		if(GetClientTeam(iVictim) != GetClientTeam(iAttacker))
		{
			EndGracePeriod();
		}
	}

	if(validClient(iVictim) && g_iSuperHealth[iVictim] > 0)
	{
		g_iSuperHealth[iVictim] -= RoundFloat(fDamage);
		if(g_iSuperHealth[iVictim] < 0)
			g_iSuperHealth[iVictim] = 0;
		bChanged = true;
		
		new iMaxHealth = RoundFloat(float(GetEntProp(iVictim, Prop_Data, "m_iMaxHealth"))*1.5);
		SetEntityHealth(iVictim, iMaxHealth);
	}
	if(iVictim != iAttacker)
	{
		if(validLivingClient(iAttacker) && fDamage < 300.0)
		{ 
			if(validZom(iAttacker))
				fDamage = fDamage * g_fZombieDamageScale * 0.7;
			if(validSur(iAttacker))
				fDamage = fDamage / g_fZombieDamageScale * 1.1;
			if(fDamage > 200.0)
				fDamage = 200.0;
			bChanged = true;
		}
		if(validSur(iVictim) && validZom(iAttacker))
		{
			if((TF2_GetPlayerClass(iAttacker) == TFClass_Spy && !HasRazorback(iVictim) && iDamagetype== DMGTYPE_MELEE_CRIT) || fDamage >= 200.0)
			{
				if(!g_bBackstabbed[iVictim])
				{
					fDamage = 1.0;
					SetEntityHealth(iVictim, 10);
					TF2_StunPlayer(iVictim, 7.0, 1.0, TF_STUNFLAGS_BIGBONK|TF_STUNFLAG_NOSOUNDOREFFECT, iAttacker);
					g_bBackstabbed[iVictim] = true;
					CreateTimer(7.0, RemoveBackstab, iVictim);
					MusicHandleClient(iVictim);
					bChanged = true;
					
					new iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_NEARDEATH2]-1);
					decl String:strPath[PLATFORM_MAX_PATH];
					MusicGetPath(MUSIC_NEARDEATH2, iRandom, strPath, sizeof(strPath));
					for(new i=1; i<=MaxClients; i++)
					{
						if(validClient(i) && ShouldHearEventSounds(i) && i != iVictim)
						{
							EmitSoundToClient(i, strPath, iVictim, SNDLEVEL_AIRCRAFT);
						}
					}
				}
				else
				{
					fDamage = 0.0;
					bChanged = true;
				}
			}
		}
		if(validZom(iVictim) && TF2_GetPlayerClass(iVictim) == TFClass_Heavy)
		{
			fForce[0] = 0.0;
			fForce[1] = 0.0;
			fForce[2] = 0.0;
			fDamage *= 0.7;
			if(fDamage > 100.0)
				fDamage = 100.0;
			bChanged = true; 
		}
		if(validZom(iAttacker) && validSur(iVictim) && fDamage > 0.0)
		{
			new iDamage = RoundFloat(fDamage);
			if(iDamage > 300)
				iDamage = 300;
			g_iDamage[iAttacker] += iDamage;
			new iPitch = g_iHitBonusCombo[iAttacker] * 10 + 50;
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
	if(bChanged) return Plugin_Changed;
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Admin Console Command Handlers
//
////////////////////////////////////////////////////////////
public Action:command_zfEnable(client, args)
{
	ServerCommand("mp_restartgame 6");
	CPrintToChatAll("{olive}[SZF]{default} %t", "SZF Enabled");

	if(!zf_bEnabled)
		zfEnable();

	return Plugin_Continue;
}

public Action:command_zfDisable (client, args)
{
	if(!zf_bEnabled)
		return Plugin_Continue;

	ServerCommand("mp_restartgame 6");
	CPrintToChatAll("{olive}[SZF]{default} %t", "SZF Disabled");
	zfDisable();

	return Plugin_Continue;
}

public Action:command_zfSwapTeams(client, args)
{
	if(!zf_bEnabled)
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
public Action:OnJoinTeam(client, const String:command[], argc)
{	
	decl String:cmd1[32];
	decl String:sSurTeam[16];	
	decl String:sZomTeam[16];
	decl String:sZomVgui[16];
	
	if(!zf_bEnabled)
		return Plugin_Continue;	
	if(argc < 1)
		return Plugin_Handled;
	 
	GetCmdArg(1, cmd1, sizeof(cmd1));
	
	if(roundState() >= RoundGrace)
	{
		// Assign team-specific strings
		if(zomTeam() == _:TFTeam_Blue)
		{
			sSurTeam = "red";
			sZomTeam = "blue";
			sZomVgui = "class_blue";
		}
		else
		{
			sSurTeam = "blue";
			sZomTeam = "red";
			sZomVgui = "class_red";			
		}
			
		// If client tries to join the survivor team or a random team
		// during grace period or active round, place them on the zombie
		// team and present them with the zombie class select screen.
		if(StrEqual(cmd1, sSurTeam, false) || StrEqual(cmd1, "auto", false))
		{
			ChangeClientTeam(client, zomTeam());
			ShowVGUIPanel(client, sZomVgui);
			return Plugin_Handled;
		}
		// If client tries to join the zombie team or spectator
		// during grace period or active round, let them do so.
		else if(StrEqual(cmd1, sZomTeam, false) || StrEqual(cmd1, "spectate", false))
		{
			return Plugin_Continue;
		}
		// Prevent joining any other team.
		else
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action:OnJoinClass(client, const String:command[], argc)
{
	decl String:cmd1[32];
	
	if(!zf_bEnabled)
		return Plugin_Continue;
	if(argc < 1)
		return Plugin_Handled;

	GetCmdArg(1, cmd1, sizeof(cmd1));
	
	if(isZom(client))	 
	{
		// If an invalid zombie class is selected, print a message and
		// accept joinclass command. ZF spawn logic will correct this
		// issue when the player spawns.
		if(!(StrEqual(cmd1, "scout", false) || StrEqual(cmd1, "spy", false) || StrEqual(cmd1, "heavyweapons", false)))
		{
			CPrintToChat(client, "{olive}[SZF]{default} %t", "Zombies Classes");
		}
	}

	else if(isSur(client))
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
			  StrEqual(cmd1, "sniper", false)))
		{
			CPrintToChat(client, "{olive}[SZF]{default} %t", "Survivor Classes");
		}			 
	}
		
	return Plugin_Continue;
}

public Action:OnCallMedic(client, const String:command[], argc)
{
	decl String:cmd1[32], String:cmd2[32];
	
	if(!zf_bEnabled)
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
		if(isZom(client) && g_iSpecialInfected[client] == INFECTED_NONE)
		{		
			new curH = GetClientHealth(client);
			new maxH = GetEntProp(client, Prop_Data, "m_iMaxHealth");			 
	
			if((zf_rageTimer[client] == 0) && (curH >= maxH))
			{
				zf_rageTimer[client] = 30;
				
				SetEntityHealth(client, RoundToCeil(maxH * 1.5));
									
				ClientCommand(client, "voicemenu 2 1");
				PrintHintText(client, "%t", "Rage Activated!");	
			}
			else
			{
				ClientCommand(client, "voicemenu 2 5");
				PrintHintText(client, "%t", "Can't Activate Rage!"); 
			}
					
			return Plugin_Handled;
		}
		else if(isSur(client))
		{
			if(AttemptCarryItem(client))
				return Plugin_Handled;
			else if(AttemptGrabItem(client))
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:CommandTeamPref(client, args)
{
	decl String:cmd[32];
	
	if(!zf_bEnabled)
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

public Action:CommandMenu(client, args)
{
	if(!zf_bEnabled)
		return Plugin_Continue; 
	panel_PrintMain(client);
	
	return Plugin_Handled;		
}

////////////////////////////////////////////////////////////
//
// TF2 Gameplay Event Handlers
//
////////////////////////////////////////////////////////////
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{	
	if(!zf_bEnabled)
		return Plugin_Continue;
				
	// Handle special cases.
	// + Being kritzed overrides other crit calculations.
	if(isKritzed(client))
		return Plugin_Continue;

	// Handle crit bonuses.
	// + Survivors: Crit result is combination of bonus and standard crit calulations.
	// + Zombies: Crit result is based solely on bonus calculation. 
	if(isSur(client))
	{
		if(GetRandomInt(0, 1))
		{
			result = false;
			return Plugin_Changed;
		}
	}
	else
	{
		result = (szf_critBonus[client] > GetRandomInt(0, 99));
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

//
// Round Start Event
//
public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!zf_bEnabled)
		return Plugin_Continue; 
	
	RemovePhysicObjects();
	DetermineControlPoints();
	
	new players[MAXPLAYERS+1] = -1;
	decl playerCount;
	decl surCount;
 
	g_StartTime = GetTime();
	g_AdditionalTime = 0;
	
	new i;
	for(i=1; i<=MaxClients; i++)
	{
		g_iDamage[i] = 0;
		g_iKillsThisLife[i] = 0;
		g_iSpecialInfected[i] = INFECTED_NONE;
		g_iSuperHealth[i] = 0;
		g_iSuperHealthSubtract[i] = 0;
	}
	
	g_iZombieTank = 0;
	g_bTankOnce = false;
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
		for(i = 1; i <= MaxClients; i++)
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
		new idx = GetRandomInt(0,playerCount-1);
		new temp = players[idx];
		players[idx] = players[0];
		players[0] = temp;		
		
		// Sort players using team preference criteria
		if(GetConVarBool(szf_cvAllowTeamPref)) 
		{
			SortCustom1D(players, playerCount, SortFunc1D:Sort_Preference);
		}
		
		// Calculate team counts. At least one survivor must exist.	 
		surCount = RoundToFloor(playerCount*GetConVarFloat(szf_cvRatio));
		if((surCount==0) && (playerCount>0))
		{
			surCount = 1;
		}	
			
		// Assign active players to survivor and zombie teams.
		g_iStartSurvivors = 0;
		new bool:bSurvivors[MAXPLAYERS+1] = false;
		i = 1;
		while(surCount>0 && i<=playerCount)
		{
			new iClient = players[i];
			if(validClient(iClient))
			{
				new bool:bGood = true;
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
public Action:OnSetupEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!zf_bEnabled)
		return Plugin_Continue;
		 
	EndGracePeriod();
	
	g_StartTime = GetTime();
	g_AdditionalTime = 0;
	g_bRoundActive = true;
	
	return Plugin_Continue;
}

EndGracePeriod()
{
	if(!zf_bEnabled || roundState()==RoundActive || roundState()==RoundPost)
		return;
	
	setRoundState(RoundActive);
	CPrintToChatAll("{olive}[SZF]{default} %t", "Grace Period End");
	ZombieRage(true);
}

//
// Round End Event
//
public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!zf_bEnabled) return Plugin_Continue;
	
	//
	// Prepare for a completely new round, if
	// + Round was a full round (full_round flag is set), OR
	// + Zombies are the winning team.
	//
	zf_bNewRound = GetEventBool(event, "full_round") || (GetEventInt(event, "team") == zomTeam());
	setRoundState(RoundPost);
	
	SetGlow();
	UpdateZombieDamageScale();
	g_bRoundActive = false;
	
	return Plugin_Continue;
}

//
// Player Spawn Event
//
public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{	 
	if(!zf_bEnabled)
		return Plugin_Continue;	
			
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//StartSoundSystem(client, MUSIC_NONE);
	
	g_iSuperHealth[client] = 0;
	g_iSuperHealthSubtract[client] = 0;
	g_bHitOnce[client] = false;
	g_iHitBonusCombo[client] = 0;
	g_bBackstabbed[client] = false;
	g_iKillsThisLife[client] = 0;
	g_fDamageTakenLife[client] = 0.0;
	g_fDamageDealtLife[client] = 0.0;
	
	DropCarryingItem(client, false);
	
	
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
				
				new iSurvivors = GetSurvivorCount();
				new iHealth = GetConVarInt(szf_cvTankHealth) * iSurvivors;
				if(iHealth < GetConVarInt(szf_cvTankHealthMin))
					iHealth = GetConVarInt(szf_cvTankHealthMin);
				if(iHealth > GetConVarInt(szf_cvTankHealthMax))
					iHealth = GetConVarInt(szf_cvTankHealthMax);
				g_iSuperHealth[client] = iHealth;
				
				new iSubtract = 0;
				if(GetConVarFloat(szf_cvTankTime) > 0.0)
				{
					iSubtract = RoundFloat(float(iHealth) / GetConVarFloat(szf_cvTankTime));
					if(iSubtract < 3) iSubtract = 3;
				}
				g_iSuperHealthSubtract[client] = iSubtract;
				TF2_AddCondition(client, TFCond_Kritzkrieged, 999.0);
				SetEntityHealth(client, 450);
				
				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				SetEntityRenderColor(client, 0, 255, 0, 255);
				PerformFastRespawn2(client);
				
				//SetEntityGravity(client, 10.0);
				
				MusicHandleAll();
				
				for (new i = 1; i <= MaxClients; i++)
				{
					if(validClient(i)) CPrintToChat(i, "{olive}[SZF]{default} %t", "Tank");
				}
			}
			
		}
	}
	
	new TFClassType:clientClass = TF2_GetPlayerClass(client);
	

	resetClientState(client);
	CreateZombieSkin(client);
				
	// 1. Prevent players spawning on survivors if round has started.
	//		Prevent players spawning on survivors as an invalid class.
	//		Prevent players spawning on zombies as an invalid class.
	if(isSur(client))
	{
		if(roundState() == RoundActive)
		{
			spawnClient(client, zomTeam());
			return Plugin_Continue;
		}
		if(!validSurvivor(clientClass))
		{
			spawnClient(client, surTeam()); 
			return Plugin_Continue;
		}			
	}
	else if(isZom(client))
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
	CreateTimer(0.1, timer_postSpawn, client, TIMER_FLAG_NO_MAPCHANGE); 
	
	SetGlow();
	UpdateZombieDamageScale();
	TankCanReplace(client);
	CheckStartWeapons();
	//HandleClientInventory(client);
			
	return Plugin_Continue; 
}

//
// Player Death Event
//
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!zf_bEnabled)
		return Plugin_Continue;

	decl killers[2];
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	killers[0] = GetClientOfUserId(GetEventInt(event, "attacker")); 
	killers[1] = GetClientOfUserId(GetEventInt(event, "assister"));  

	ClientCommand(victim, "r_screenoverlay\"\"");
	
	DropCarryingItem(victim);
	
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
		new index = -1; 
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
		CreateTimer(6.0, timer_zombify, victim, TIMER_FLAG_NO_MAPCHANGE);
		// check if he's the last
		CreateTimer(0.1, CheckLastPlayer);
		
		new iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_DEAD]-1);
		decl String:strPath[PLATFORM_MAX_PATH];
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

		for(new i = 0; i < 2; i++)
		{								 
			if(validLivingClient(killers[i]))
			{
				// Handle ammo kill bonuses.
				// + Soldiers receive 2 rockets per kill.
				// + Demomen receive 2 pipes per kill.
				// + Snipers receive 5 rifle / 2 arrows per kill.
				new TFClassType:killerClass = TF2_GetPlayerClass(killers[i]);				
				switch(killerClass)
				{
					case TFClass_Soldier: addResAmmo(killers[i], 0, 2);
					case TFClass_DemoMan: addResAmmo(killers[i], 0, 2);
					case TFClass_Sniper:
					{
						if(isEquipped(killers[i], ZFWEAP_SNIPERRIFLE) || isEquipped(killers[i], ZFWEAP_SYDNEYSLEEPER))
							addResAmmo(killers[i], 0, 5);
						else if(isEquipped(killers[i], ZFWEAP_HUNTSMAN))
							addResAmmo(killers[i], 0, 2);
					}
				}

				// Handle morale bonuses.
				// + Each kill grants a small health bonus and increases current crit bonus.
				new curH = GetClientHealth(killers[i]);
				new maxH = GetEntProp(killers[i], Prop_Data, "m_iMaxHealth"); 
				if(curH < maxH)
				{
					curH += (szf_critBonus[killers[i]] * 2);
					curH = min(curH, maxH);				
					//SetEntityHealth(killers[i], curH);
				}
				//szf_critBonus[killers[i]] = min(100, szf_critBonus[killers[i]] + 5); 
									 
			} // if				 
		} // for 
	} // if 
	
	SetGlow();
	UpdateZombieDamageScale();
	CheckStartWeapons();
	 
	return Plugin_Continue;
}

//
// Object Built Event
//
/*public Action:OnPlayerBuiltObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!zf_bEnabled)
		return Plugin_Continue;

	new index = GetEventInt(event, "index");
	new building = GetEventInt(event, "object");

	// 1. Handle dispenser rules.
	//		Disable dispensers when they begin construction.
	//		Increase max health to 250 (default level 1 is 150).			
	if(building == PLAYERBUILTOBJECT_ID_DISPENSER)
	{
		SetEntProp(index, Prop_Send, "m_bDisabled", 1);
		SetEntProp(index, Prop_Send, "m_iMaxHealth", 250);
	}

	return Plugin_Continue;		 
}*/

////////////////////////////////////////////////////////////
//
// Periodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action:timer_main(Handle:timer) // 1Hz
{		 
	if(!zf_bEnabled)
		return Plugin_Continue;
	
	handle_survivorAbilities();
	handle_zombieAbilities();	 
	if(g_bZombieRage)
	{
		setTeamRespawnTime(zomTeam(), 0.0);
	}
	else
	{
		new Float:fDelay = 0.0;
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
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if(validLivingZom(i) && g_iSpecialInfected[i] == INFECTED_TANK)
			{
				if(g_iSuperHealth[i] > 0)
				{
					g_iSuperHealth[i] -= g_iSuperHealthSubtract[i];
				}
				else
				{
					new iHealth = GetClientHealth(i);
					if(iHealth > 1)
					{
						iHealth -= g_iSuperHealthSubtract[i];
						if(iHealth < 1) iHealth = 1;
						SetEntityHealth(i, iHealth);
					}
					else
					{
						ForcePlayerSuicide(i);
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action:timer_mainSlow(Handle:timer) // 4 min
{ 
	if(!zf_bEnabled)
		return Plugin_Continue;	
	help_printZFInfoChat(0);
	
	return Plugin_Continue;
}

public Action:timer_mainFast(Handle:timer)
{ 
	if(!zf_bEnabled)
		return Plugin_Continue;	
	GooDamageCheck();
	
	return Plugin_Continue;
}

public Action:timer_hoarde(Handle:timer) // 1/5th Hz
{	
	if(!zf_bEnabled)
		return Plugin_Continue;
	handle_hoardeBonus();
	
	return Plugin_Continue;	
}

public Action:timer_datacollect(Handle:timer) // 1/5th Hz
{	
	if(!zf_bEnabled)
		return Plugin_Continue;
	FastRespawnDataCollect();
	
	return Plugin_Continue;	
}

////////////////////////////////////////////////////////////
//
// Aperiodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action:timer_graceStartPost(Handle:timer)
{ 
	// Disable all resupply cabinets.
	new index = -1;
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
		decl String:strParent[255];
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
	
	new iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_PREPARE]-1);
	decl String:strPath[PLATFORM_MAX_PATH];
	MusicGetPath(MUSIC_PREPARE, iRandom, strPath, sizeof(strPath));
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !isZom(i) && ShouldHearEventSounds(i))
		{
			EmitSoundToClient(i, strPath);
		}
	}	
	
	return Plugin_Continue; 
}

public Action:timer_graceEnd(Handle:timer)
{
	EndGracePeriod();

	return Plugin_Continue;	
}

public Action:timer_initialHelp(Handle:timer, any:client)
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

public Action:timer_postSpawn(Handle:timer, any:client)
{
	if(validClient(client) && IsPlayerAlive(client))
	{
		HandleClientInventory(client);
		// Handle zombie spawn logic.
		if(isZom(client))
			stripWeapons(client);
		if(!isZom(client))
			CreateTimer(0.1, Timer_CheckItems, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue; 
}

public Action:timer_zombify(Handle:timer, any:client)
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
handle_gameFrameLogic()
{
	new iCount = GetSurvivorCount();
	// 1. Limit spy cloak to 80% of max.
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && isZom(i))
		{
			if(getCloak(i) > 80.0) 
				setCloak(i, 80.0);
		}
		if(roundState() == RoundActive)
		{
			if(validClient(i) && IsPlayerAlive(i) && isSur(i) && iCount == 1)
			{
				if(GetActivePlayerCount() >= 10 && !TF2_IsPlayerInCondition(i, TFCond_Kritzkrieged))
				{
					TF2_AddCondition(i, TFCond_Kritzkrieged, 999.0);
				}
				if(GetActivePlayerCount() < 10 && TF2_IsPlayerInCondition(i, TFCond_Kritzkrieged))
				{
					TF2_RemoveCondition(i, TFCond_Kritzkrieged);
				}
			}
		}
	}
}
	
handle_winCondition()
{	
	// 1. Check for any survivors that are still alive.
	new bool:anySurvivorAlive = false;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && isSur(i))
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

handle_survivorAbilities()
{
	/*decl clipAmmo;
	decl resAmmo;
	decl ammoAdj;
		
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && isSur(i))
		{
			// 1. Handle survivor weapon rules.
			//		SMG doesn't have to reload. 
			//		Syringe gun / blutsauger don't have to reload. 
			//		Flamethrower / backburner ammo limited to 125.
			switch(TF2_GetPlayerClass(i))
			{
				case TFClass_Sniper:
				{
					if(isEquipped(i, ZFWEAP_SMG))
					{
						clipAmmo = getClipAmmo(i, 1);
						resAmmo = getResAmmo(i, 1);						
						ammoAdj = min((25 - clipAmmo), resAmmo);
						if(ammoAdj > 0)
						{
							setClipAmmo(i, 1, (clipAmmo + ammoAdj));
							setResAmmo(i, 1, (resAmmo - ammoAdj));
						}
					}
				}
				
				case TFClass_Medic: 
				{
					if(isEquipped(i, ZFWEAP_SYRINGEGUN) || isEquipped(i, ZFWEAP_BLUTSAUGER))
					{
						clipAmmo = getClipAmmo(i, 0);
						resAmmo = getResAmmo(i, 0);
						ammoAdj = min((40 - clipAmmo), resAmmo);
						if(ammoAdj > 0)
						{
							setClipAmmo(i, 0, (clipAmmo + ammoAdj));
							setResAmmo(i, 0, (resAmmo - ammoAdj));
						}
					}					 
				}
				
				case TFClass_Pyro:
				{
					resAmmo = getResAmmo(i, 0);
					if(resAmmo > 125)
					{
						ammoAdj = max((resAmmo - 10),125);
						setResAmmo(i, 0, ammoAdj);
					}		
				}					
			} //switch
			
			// 2. Handle survivor crit bonus rules.
			//		Decrement morale bonus.
			szf_critBonus[i] = max(0, szf_critBonus[i] - 1);
			
		} //if
	} //for
	
	// 3. Handle sentry rules.
	//		+ Norm sentry starts with 60 ammo and decays to 10.
	//		+ Mini sentry starts with 60 ammo and decays to 0, then self destructs.
	//		+ No sentry can be upgraded.
	new index = -1;
	while ((index = FindEntityByClassname(index, "obj_sentrygun")) != -1)
	{		
		new bool:sentBuilding = GetEntProp(index, Prop_Send, "m_bBuilding") == 1;
		new bool:sentPlacing = GetEntProp(index, Prop_Send, "m_bPlacing") == 1;
		new bool:sentCarried = GetEntProp(index, Prop_Send, "m_bCarried") == 1;
		new bool:sentIsMini = GetEntProp(index, Prop_Send, "m_bMiniBuilding") == 1;
		if(!sentBuilding && !sentPlacing && !sentCarried)
		{	
			new sentAmmo = GetEntProp(index, Prop_Send, "m_iAmmoShells");
			if(sentAmmo > 0)
			{
				if(sentIsMini || (sentAmmo > 10))
				{
					sentAmmo = min(60, (sentAmmo - 1));
					SetEntProp(index, Prop_Send, "m_iAmmoShells", sentAmmo);					
				}
			}
			else
			{
				SetVariantInt(GetEntProp(index, Prop_Send, "m_iMaxHealth"));
				AcceptEntityInput(index, "RemoveHealth");
			}
		}
		
		new sentLevel = GetEntProp(index, Prop_Send, "m_iHighestUpgradeLevel");
		if(sentLevel > 1)
		{
			SetVariantInt(GetEntProp(index, Prop_Send, "m_iMaxHealth"));
			AcceptEntityInput(index, "RemoveHealth");		
		}
	}*/
}

handle_zombieAbilities()
{
	decl TFClassType:clientClass;
	decl curH;
	decl maxH; 
	decl bonus;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && isZom(i) && g_iSpecialInfected[i] != INFECTED_TANK)
		{	 
			clientClass = TF2_GetPlayerClass(i);
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
			szf_critBonus[i] = bonus;
			
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

handle_hoardeBonus()
{ 
	decl playerCount;
	decl player[MAXPLAYERS];
	decl playerHoardeId[MAXPLAYERS];
	decl Float:playerPos[MAXPLAYERS][3];
	
	decl hoardeSize[MAXPLAYERS];

	decl curPlayer;
	decl curHoarde;
	decl Handle:hStack;
	
	// 1. Find all active zombie players.
	playerCount = 0;
	for(new i=1; i<=MaxClients; i++)
	{	
		if(IsClientInGame(i) && IsPlayerAlive(i) && isZom(i))
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
	for(new i = 0; i < playerCount; i++)
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
			for(new j = i+1; j < playerCount; j++)
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
	for(new i = 1; i <= MaxClients; i++)
		zf_hoardeBonus[i] = 0;		
	for(new i = 0; i < playerCount; i++)
		zf_hoardeBonus[player[i]] = hoardeSize[playerHoardeId[i]] - 1;
		
	CloseHandle(hStack);		
}

////////////////////////////////////////////////////////////
//
// ZF Logic Functionality
//
////////////////////////////////////////////////////////////
zfEnable()
{		 
	zf_bEnabled = true;
	zf_bNewRound = true;
	setRoundState(RoundInit2);
	
	zfSetTeams();
		
	for(new i = 0; i <= MAXPLAYERS; i++)
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
	szf_tMainFast = CreateTimer(0.5, timer_mainFast, _, TIMER_REPEAT);
	
	if(szf_tHoarde != INVALID_HANDLE)
		CloseHandle(szf_tHoarde);
	szf_tHoarde = CreateTimer(5.0, timer_hoarde, _, TIMER_REPEAT); 
	
	if(szf_tDataCollect != INVALID_HANDLE)
		CloseHandle(szf_tDataCollect);
	szf_tDataCollect = CreateTimer(2.0, timer_datacollect, _, TIMER_REPEAT);

	#if defined _steamtools_included
	if(steamtools)
	{
		decl String:gameDesc[64];
		Format(gameDesc, sizeof(gameDesc), "Super Zombie Fortress (%s)", PLUGIN_VERSION);
		Steam_SetGameDescription(gameDesc);
	}
	#endif
}

zfDisable()
{	
	zf_bEnabled = false;
	zf_bNewRound = true;
	setRoundState(RoundInit2);
	
	for(new i = 0; i <= MAXPLAYERS; i++)
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
	new index = -1;
	while((index = FindEntityByClassname(index, "func_regenerate")) != -1)
		AcceptEntityInput(index, "Enable");

	#if defined _steamtools_included
	if(steamtools)
	{
		Steam_SetGameDescription("Team Fortress");
	}
	#endif
}

zfSetTeams()
{
	//
	// Determine team roles.
	// + By default, survivors are RED and zombies are BLU.
	//
	new survivorTeam = _:TFTeam_Red;
	new zombieTeam = _:TFTeam_Blue;
	
	//
	// Determine whether to swap teams on payload maps.
	// + For "pl_" prefixed maps, swap teams if sm_zf_swaponpayload is set.
	//
	if(mapIsPL())
	{
		if(GetConVarBool(szf_cvSwapOnPayload)) 
		{			
			survivorTeam = _:TFTeam_Blue;
			zombieTeam = _:TFTeam_Red;
		}
	}
	
	//
	// Determine whether to swap teams on attack / defend maps.
	// + For "cp_" prefixed maps with all RED control points, swap teams if sm_zf_swaponattdef is set.
	//
	if(mapIsCP())
	{
		if(GetConVarBool(szf_cvSwapOnAttdef))
		{
			new bool:isAttdef = true;
			new index = -1;
			while((index = FindEntityByClassname(index, "team_control_point")) != -1)
			{
				if(GetEntProp(index, Prop_Send, "m_iTeamNum") != _:TFTeam_Red)
				{
					isAttdef = false;
					break;
				}
			}
			
			if(isAttdef)
			{
				survivorTeam = _:TFTeam_Blue;
				zombieTeam = _:TFTeam_Red;
			}
		}
	}
	
	// Set team roles.
	setSurTeam(survivorTeam);
	setZomTeam(zombieTeam);
}

zfSwapTeams()
{
	new survivorTeam = surTeam();
	new zombieTeam = zomTeam();
	
	// Swap team roles.
	setSurTeam(zombieTeam);
	setZomTeam(survivorTeam);
}

////////////////////////////////////////////////////////////
//
// Utility Functionality
//
////////////////////////////////////////////////////////////
public Sort_Preference(client1, client2, const array[], Handle:hndl)
{	
 // Used during round start to sort using client team preference.
	new prefCli1 = IsFakeClient(client1) ? ZF_TEAMPREF_NONE : prefGet(client1, TeamPref);
	new prefCli2 = IsFakeClient(client2) ? ZF_TEAMPREF_NONE : prefGet(client2, TeamPref);	
	return (prefCli1 < prefCli2) ? -1 : (prefCli1 > prefCli2) ? 1 : 0;
}

resetClientState(client)
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
public help_printZFInfoChat(client)
{
	if(client == 0)
	{
		CPrintToChatAll("{olive}[SZF]{default} %t", "Server Info", PLUGIN_VERSION);
		CPrintToChatAll("{olive}[SZF]{default} %t", "SZF Command");		
	}
	else
	{
		CPrintToChat(client, "{olive}[SZF]{default} %t", "Server Info", PLUGIN_VERSION);
		CPrintToChatAll("{olive}[SZF]{default} %t", "SZF Command");
	}
}

////////////////////////////////////////////////////////////
//
// Main Menu Functionality
//
////////////////////////////////////////////////////////////
public panel_PrintMain(client)
{
	new Handle:panel = CreatePanel();
	decl String:temp_string21[256];
	Format(temp_string21, sizeof(temp_string21),"%T", "SZF Main Menu", client);
	SetPanelTitle(panel, temp_string21);
	Format(temp_string21, sizeof(temp_string21),"%T", "Help", client);
	DrawPanelItem(panel, temp_string21);	
	if(GetConVarBool(szf_cvAllowTeamPref)) 
	{
		Format(temp_string21, sizeof(temp_string21),"%T", "Preferences", client);
		DrawPanelItem(panel, temp_string21);
	}
	Format(temp_string21, sizeof(temp_string21),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string21);
	SendPanelToClient(panel, client, panel_HandleMain, 10);
	CloseHandle(panel);
}

public panel_HandleMain(Handle:menu, MenuAction:action, param1, param2)
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
public panel_PrintPrefs(client)
{
	new Handle:panel = CreatePanel();
	decl String:temp_string1[256];
	Format(temp_string1, sizeof(temp_string1),"%T", "ZF Preferences", client);
	SetPanelTitle(panel, temp_string1);
	if(GetConVarBool(szf_cvAllowTeamPref)) 
	{
		Format(temp_string1, sizeof(temp_string1),"%T", "Team Preference", client);
		DrawPanelItem(panel, temp_string1);	
	}
	Format(temp_string1, sizeof(temp_string1),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string1);
	SendPanelToClient(panel, client, panel_HandlePrefs, 10);
	CloseHandle(panel);
}

public panel_HandlePrefs(Handle:menu, MenuAction:action, param1, param2)
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

public panel_PrintPrefs00(client)
{
	new Handle:panel = CreatePanel();
	decl String:temp_string2[512];
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

public panel_HandlePrefTeam(Handle:menu, MenuAction:action, param1, param2)
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
public panel_PrintHelp(client)
{
	new Handle:panel = CreatePanel();
	
	decl String:temp_string3[1024];
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

public panel_HandleHelp(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1: panel_PrintOverview(param1);
			case 2: panel_PrintTeam(param1, _:surTeam());
			case 3: panel_PrintTeam(param1, _:zomTeam());
			case 4: panel_PrintSurClass(param1);
			case 5: panel_PrintZomClass(param1);
			default: return;	 
		} 
	} 
}
 
//
// Main.Help.Overview Menus
//
public panel_PrintOverview(client)
{
	new Handle:panel = CreatePanel();
	
	decl String:temp_string4[1024];
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

public panel_HandleOverview(Handle:menu, MenuAction:action, param1, param2)
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
public panel_PrintTeam(client, team)
{
	new Handle:panel = CreatePanel();
	if(team == _:surTeam())
	{
		decl String:temp_string5[1024];
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
	else if(team == _:zomTeam())
	{
		decl String:temp_string6[2048];
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
	decl String:temp_string7[512];
	Format(temp_string7, sizeof(temp_string7),"%T", "Return to Help Menu", client);
	DrawPanelItem(panel, temp_string7);
	Format(temp_string7, sizeof(temp_string7),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string7);
	SendPanelToClient(panel, client, panel_HandleTeam, 10);
	CloseHandle(panel);
}

public panel_HandleTeam(Handle:menu, MenuAction:action, param1, param2)
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
public panel_PrintSurClass(client)
{
	new Handle:panel = CreatePanel();
	
	decl String:temp_string8[512];
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

public panel_HandleSurClass(Handle:menu, MenuAction:action, param1, param2)
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
			
public panel_PrintZomClass(client)
{
	new Handle:panel = CreatePanel();
	decl String:temp_string9[512];
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

public panel_HandleZomClass(Handle:menu, MenuAction:action, param1, param2)
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

public panel_PrintClass(client, TFClassType:class)
{
	new Handle:panel = CreatePanel();
	switch(class)
	{
		case TFClass_Soldier:
		{
			decl String:temp_string10[1024];
			Format(temp_string10, sizeof(temp_string10),"%T", "Soldier Human 1", client);
			SetPanelTitle(panel, temp_string10);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string10, sizeof(temp_string10),"%T", "Soldier Human 2", client);
			DrawPanelText(panel, temp_string10);
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Pyro:
		{
			decl String:temp_string11[512];
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
			decl String:temp_string12[1024];
			Format(temp_string12, sizeof(temp_string12),"%T", "Demoman Human 1", client);
			SetPanelTitle(panel, temp_string12);
			DrawPanelText(panel, "-------------------------------------------");
			Format(temp_string12, sizeof(temp_string12),"%T", "Demoman Human 2", client);
			DrawPanelText(panel, temp_string12);		
			DrawPanelText(panel, "-------------------------------------------");
		}
		case TFClass_Engineer:
		{
			decl String:temp_string13[2048];
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
			decl String:temp_string14[2048];
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
			decl String:temp_string15[1024];
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
			decl String:temp_string16[1024];
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
			decl String:temp_string17[1024];
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
			decl String:temp_string18[1024];
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
			decl String:temp_string19[1024];
			Format(temp_string19, sizeof(temp_string19),"%T", "Unassigned", client);
			SetPanelTitle(panel, temp_string19);
			DrawPanelText(panel, "-------------------------------------------"); 
			Format(temp_string19, sizeof(temp_string19),"%T", "Spectator", client);			
			DrawPanelText(panel, temp_string19);
			DrawPanelText(panel, "-------------------------------------------");
		}
	}
	decl String:temp_string20[512];
	Format(temp_string20, sizeof(temp_string20),"%T", "Return to Help Menu", client);
	DrawPanelItem(panel, temp_string20);
	Format(temp_string20, sizeof(temp_string20),"%T", "Close Menu", client);
	DrawPanelItem(panel, temp_string20);
	SendPanelToClient(panel, client, panel_HandleClass, 8);
	CloseHandle(panel);
}

public panel_HandleClass(Handle:menu, MenuAction:action, param1, param2)
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

public dummy_PanelHandler(Handle:menu, MenuAction:action, param1, param2)
{
	return;
}

SetGlow()
{
	new iCount = GetSurvivorCount();
	new iGlow = 0;
	new iGlow2;
	
	if(iCount >= 1 && iCount <= 3) iGlow = 1;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			iGlow2 = iGlow;
			if(!isSur(i))
				iGlow2 = 0;
			if(isZom(i) && g_iSpecialInfected[i] == INFECTED_TANK)
				iGlow2 = 1;
			SetEntProp(i, Prop_Send, "m_bGlowEnabled", iGlow2);
		}
	}
}

stock GetPlayerCount()
{
	new playerCount = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && (GetClientTeam(i) > 1))
		{
			playerCount++;  
		}
	}
	return playerCount;
}

stock GetSurvivorCount()
{
	new iCount = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(validLivingSur(i))
		{
			iCount++;
		}
	}
	return iCount;
}

public OnSlagChange(iClient, iFeature, bool:bEnabled)
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

UpdateZombieDamageScale()
{
	g_fZombieDamageScale = 1.0;
	if(!zf_bEnabled || g_iStartSurvivors<=0 || roundState()!=RoundActive)
		return;	

	new Float:fTime = 1.0 - GetTimePercentage();
	if(fTime <= 0.0)
		return;

	new iCurrentSurvivors = GetSurvivorCount();
	new iExpectedSurvivors = RoundFloat(float(g_iStartSurvivors) * (SquareRoot(fTime) + fTime)*0.5);
	new iSurvivorDifference = iCurrentSurvivors - iExpectedSurvivors;
	
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
	
	//decl String:strInput[255];
	//Format(strInput, sizeof(strInput), "%d %d {3} {4} message_1", fTime, iExpectedSurvivors, iCurrentSurvivors, g_fZombieDamageScale*100.0);
	//if(g_bCapturingLastPoint) Format(strInput, sizeof(strInput), "{1} message_2", strInput);
	//ShowDebug(strInput);
	
	if(!g_bZombieRage && g_iZombieTank<=0 && !ZombiesHaveTank())
	{
		if(fTime<=GetConVarFloat(szf_cvTankOnce)*0.01 && !g_bTankOnce && g_fZombieDamageScale>=1.0)
		{
			ZombieTank();
		}
		else if(fTime<=0.05 && fTime>=0.04)
		{
			ZombieRage();
		}
		else if(g_fZombieDamageScale>=1.3 || (GetRandomInt(1, 100)<=GetConVarInt(szf_cvFrenzyChance) && g_fZombieDamageScale>=1.0))
		{
			if(GetRandomInt(0, 100) <= GetConVarInt(szf_cvFrenzyTankChance) && g_fZombieDamageScale > 1.0) ZombieTank();
			else ZombieRage();
		}
	}
}

public Action:RespawnPlayer(Handle:hTimer, any:iClient)
{
	if(IsClientInGame(iClient) && !IsPlayerAlive(iClient))
	{
		TF2_RespawnPlayer(iClient);
		CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:CheckLastPlayer(Handle:hTimer)
{
	new iCount = GetSurvivorCount();
	if(iCount == 1)
	{
		for (new iLoop=1; iLoop<=MaxClients; iLoop++)
		{
			if(IsClientInGame(iLoop) && IsPlayerAlive(iLoop) && isSur(iLoop))
			{
				TF2_RegeneratePlayer(iLoop);
				HandleClientInventory(iLoop);
				SetEntityHealth(iLoop, 255);
				CPrintToChat(iLoop, "{olive}[SZF]{default} %t", "Last Mann", iLoop);
				MusicHandleClient(iLoop);
				return;
			}
		}
	}
}

public Action:OnTimeAdded(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iAddedTime = GetEventInt(event, "seconds_added");
	g_AdditionalTime = g_AdditionalTime + iAddedTime;
}

stock GetSecondsLeft()
{
	//Get round time that the round started with
	new ent = FindEntityByClassname(MaxClients+1, "team_round_timer");
	new Float:RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	new iRoundStartLength = RoundToZero(RoundStartLength);
	new TimeBuffer = iRoundStartLength + g_AdditionalTime;

	if(g_StartTime <= 0)
		return TimeBuffer;
	
	new SecElapsed = GetTime() - g_StartTime;
	
	new iTimeLeft = TimeBuffer-SecElapsed;
	if(iTimeLeft < 0)
		iTimeLeft = 0;
	if(iTimeLeft > TimeBuffer)
		iTimeLeft = TimeBuffer;
	
	return iTimeLeft;
}  

stock Float:GetTimePercentage()
{
	//Alright bitch, play tiemz ovar
	if(g_StartTime <= 0)
		return 0.0;
	new SecElapsed = GetTime() - g_StartTime;
	//PrintToChatAll("%i Seconds have elapsed since the round started", SecElapsed)
	
	//Get round time that the round started with
	new ent = FindEntityByClassname(MaxClients+1, "team_round_timer");
	new Float:RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	//PrintToChatAll("Float:RoundStartLength == %f", RoundStartLength)
	new iRoundStartLength = RoundToZero(RoundStartLength);
	
	
	//g_AdditionalTime = time added this round
	//PrintToChatAll("TimeAdded This Round: %i", g_AdditionalTime)
	
	new TimeBuffer = iRoundStartLength + g_AdditionalTime;
	//new TimeLeft = TimeBuffer - SecElapsed;
	
	new Float:TimePercentage = float(SecElapsed) / float(TimeBuffer);
	//PrintToChatAll("TimeLeft Sec: %i", TimeLeft)
	
	if(TimePercentage < 0.0)
		TimePercentage = 0.0;
	if(TimePercentage > 1.0)
		TimePercentage = 1.0;

	return TimePercentage;
}  

CreateZombieSkin(iClient)
{   
	// Add a new model
	decl String:strModel[PLATFORM_MAX_PATH];
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

public OnMapStart()
{
	PrecacheZombieModels();
	LoadSoundSystem();
	FastRespawnReset();
	DetermineControlPoints();
	
	RemovePhysicObjects();
	
	PrecacheParticle("asplode_hoodoo_green");
	PrecacheSound2(SOUND_BONUS);
	
	new i;
	for (i = 0; i < sizeof(g_strSoundFleshHit); i++)
	{
		PrecacheSound2(g_strSoundFleshHit[i]);
	}
	
	for (i = 0; i < sizeof(g_strSoundCritHit); i++)
	{
		PrecacheSound2(g_strSoundCritHit[i]);
	}
	
	new Handle:hConvar = FindConVar("slag_map_has_music");
	if(hConvar != INVALID_HANDLE)
		SetConVarBool(hConvar, true);
}

PrecacheZombieModels()
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

/*ShowDebug(String:strInput[])
{
	new iClient = GetMecha();
	if(iClient > 0)
	{
		SetHudTextParams(0.04, 0.3, 10.0, 50, 255, 50, 255);
		ShowHudText(iClient, 1, strInput);
	}
}*/

stock GetMecha()	// VSH and SZF did it.. .w. I get you want debug mode but make it for server owners too
{
	return -1;
}

LoadSoundSystem()
{
	if(g_hMusicArray != INVALID_HANDLE)
		CloseHandle(g_hMusicArray);
	g_hMusicArray = CreateArray();
	
	for (new iLoop = 0; iLoop < sizeof(g_iMusicCount); iLoop++)
	{
		g_iMusicCount[iLoop] = 0;
	}
	
	new Handle:hKeyvalue = CreateKeyValues("music");
	
	decl String:strValue[PLATFORM_MAX_PATH];
	
	decl String:strPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, strPath, sizeof(strPath), "data/superzombiefortress.txt");
	//LogMessage("Loading sound system: %s", strPath);
	FileToKeyValues(hKeyvalue, strPath);
	KvRewind(hKeyvalue);
	//KeyValuesToFile(hKeyvalue, "test.txt");
	KvGotoFirstSubKey(hKeyvalue);
	do
	{
		new Handle:hEntry = CreateArray(PLATFORM_MAX_PATH);
		KvGetString(hKeyvalue, "path", strValue, sizeof(strValue), "error");
		PushArrayString(hEntry, strValue);
		
		PrecacheSound2(strValue);
		
		//LogMessage("Found: %s", strValue);
		KvGetString(hKeyvalue, "category", strValue, sizeof(strValue), "error");
		PushArrayString(hEntry, strValue);
		
		new iCategory = MusicCategoryToNumber(strValue);
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

MusicCategoryToNumber(String:strCategory[])
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

	return -1;
}

MusicChannel(iMusic)
{
	switch(iMusic)
	{
		case MUSIC_DRUMS, MUSIC_SNARE:
			return CHANNEL_MUSIC_DRUMS;
		case MUSIC_SLAYER_MILD, MUSIC_SLAYER:
			return CHANNEL_MUSIC_SLAYER;
		case MUSIC_TRUMPET, MUSIC_BANJO, MUSIC_HEART_SLOW, MUSIC_HEART_MEDIUM, MUSIC_HEART_FAST, MUSIC_DROWN, MUSIC_TANK, MUSIC_LASTSTAND, MUSIC_LASTTENSECONDS, MUSIC_NEARDEATH:
			return CHANNEL_MUSIC_SINGLE;
		case MUSIC_RABIES, MUSIC_DEAD, MUSIC_INCOMING, MUSIC_PREPARE, MUSIC_NEARDEATH2, MUSIC_AWARD:
			return CHANNEL_MUSIC_NONE;
	}
	return CHANNEL_MUSIC_DRUMS;
}

MusicGetPath(iCategory = MUSIC_DRUMS, iNumber, String:strInput[], iMaxSize)
{
	//PrintToChatAll("Attempting to get path for category %d (num %d)", iCategory, iNumber);
	new iCount = 0;
	new iEntryCategory;
	decl String:strValue[PLATFORM_MAX_PATH];
	new Handle:hEntry;
	for (new i = 0; i < GetArraySize(g_hMusicArray); i++)
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

public OnPluginEnd()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i)) StopSoundSystem(i);
	}
}

StopSoundSystem(iClient, bool:bLogic = true, bool:bMusic = true, bool:bConsiderFull = false, iLevel = MUSIC_NONE)
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
		new Handle:hTimer = g_hMusicTimer[iClient];
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

StopSound2(iClient, iMusic)
{
	if(StrEqual(g_strMusicLast[iClient][iMusic], ""))
		return;
	
	new iChannel = MusicChannel(iMusic);
	StopSound(iClient, iChannel, g_strMusicLast[iClient][iMusic]);
	
	Format(g_strMusicLast[iClient][iMusic], PLATFORM_MAX_PATH, "");
}

StartSoundSystem(iClient, iLevel = -1)
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
		new iRandom = GetClientRandom(iClient, 0, 0, 1);
		StartSoundSystem2(iClient, MUSIC_SLAYER);
		if(iRandom == 0)
			StartSoundSystem2(iClient, MUSIC_BANJO);
		else
			StartSoundSystem2(iClient, MUSIC_DRUMS);
	}
	if(iLevel == MUSIC_MILD)
	{
		new iRandom = GetClientRandom(iClient, 0, 0, 1);
		new iRandom2 = GetClientRandom(iClient, 1, 0, 1);
		
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

public Action:SoundSystemRepeat(Handle:hTimer, any:iClient)
{
	if(!IsClientInGame(iClient))
	{
		g_hMusicTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	StartSoundSystem(iClient);
	return Plugin_Continue;
}

StartSoundSystem2(iClient, iMusic)
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
	
	new iRandom = GetRandomInt(0, g_iMusicCount[iMusic]-1);
	decl String:strPath[PLATFORM_MAX_PATH];
	MusicGetPath(iMusic, iRandom, strPath, sizeof(strPath));
	//PrintToChatAll("Emitting: %s", strPath);
	new iChannel = MusicChannel(iMusic);
	EmitSoundToClient(iClient, strPath, _, iChannel, _, _, 1.0);
	Format(g_strMusicLast[iClient][iMusic], PLATFORM_MAX_PATH, "%s", strPath);
}

bool:ShouldHearEventSounds(iClient)
{
	if(g_iMusicLevel[iClient]==MUSIC_INTENSE || g_iMusicLevel[iClient]==MUSIC_MILD)
		return false;

	return true;
}

GetClientRandom(iClient, iNumber, iMin, iMax)
{
	if(g_iMusicRandom[iClient][iNumber] >= 0)
		return g_iMusicRandom[iClient][iNumber];
	new iRandom = GetRandomInt(iMin, iMax);
	g_iMusicRandom[iClient][iNumber] = iRandom;
	return iRandom;
}

stock PrecacheSound2(String:strSound[])
{
	decl String:strPath[PLATFORM_MAX_PATH];
	Format(strPath, sizeof(strPath), "sound/%s", strSound);
	
	PrecacheSound(strSound, true);
	AddFileToDownloadsTable(strPath);
}

ZombieRage(bool:bBeginning = false)
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
		new iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_INCOMING]-1);
		decl String:strPath[PLATFORM_MAX_PATH];
		MusicGetPath(MUSIC_INCOMING, iRandom, strPath, sizeof(strPath));
		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(ShouldHearEventSounds(i))
				{
					EmitSoundToClient(i, strPath, _, SNDLEVEL_AIRCRAFT);
				}
				if(isZom(i))
				{
					CPrintToChat(i, "{olive}[SZF]{default} %t", "Frenzy");
				}
				if(isZom(i) && !IsPlayerAlive(i))
				{
					TF2_RespawnPlayer(i);
					CreateTimer(0.1, timer_postSpawn, i, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public Action:StopZombieRage(Handle:hTimer)
{
	g_bZombieRage = false;
	UpdateZombieDamageScale();
	
	if(roundState() == RoundActive)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && isZom(i))
			{
				CPrintToChat(i, "{olive}[SZF]{default} %t", "Rest");
			}
		}
	}
}

public Action:SpookySound(Handle:hTimer)
{
	if(roundState() != RoundActive)
		return;
	
	new iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_RABIES]-1);
	decl String:strPath[PLATFORM_MAX_PATH];
	MusicGetPath(MUSIC_RABIES, iRandom, strPath, sizeof(strPath));
	
	new iTarget = -1;
	new iFail = 0;
	do
	{
		iTarget = GetRandomInt(1, MaxClients);
		iFail++;
	}
	while((!IsClientInGame(iTarget) || !IsPlayerAlive(iTarget) || !ShouldHearEventSounds(iTarget) || !validActivePlayer(iTarget)) && iFail < 100);
	
	if(IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && validActivePlayer(iTarget))
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && ShouldHearEventSounds(i) && i != iTarget && !isZom(i)) EmitSoundToClient(i, strPath, iTarget);
		}
	}
}

stock EmitSoundFromOrigin(const String:sound[],const Float:orig[3], iLevel = SNDLEVEL_NORMAL)
{
	EmitSoundToAll(sound, SOUND_FROM_WORLD, SNDCHAN_AUTO, iLevel, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, orig, NULL_VECTOR, true, 0.0);
}

Float:GetZombieNumber(iClient)
{
	decl Float:fPosClient[3];
	decl Float:fPosZombie[3];
	GetClientEyePosition(iClient, fPosClient);
	new Float:fDistance;
	new Float:fZombieNumber = 0.0;
	for(new z=1; z<=MaxClients; z++)
	{
		if(IsClientInGame(z) && IsPlayerAlive(z) && isZom(z))
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

MusicHandleAll()
{
	for(new iClient = 1; iClient <= MaxClients; iClient++)
	{
		MusicHandleClient(iClient);
	}
}

MusicHandleClient(iClient)
{
	if(!validClient(iClient))
		return;
	
	if(GetClientTeam(iClient) == 1)
	{
		new iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
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
		new iCurrentHealth = GetClientHealth(iClient);
		new iMaxHealth = GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
		new Float:fHealth = float(iCurrentHealth) / float(iMaxHealth);
		if(fHealth < 0.5)
			fHealth = 0.5;
		if(fHealth > 1.1)
			fHealth = 1.1;
		
		new Float:fRage = 0.0;
		if(g_bZombieRage)
			fRage = 1.0;
		
		new Float:fZombies = GetZombieNumber(iClient);
		
		new Float:fScared = fZombies / fHealth + fRage * 20.0;
		
		/*
		if(IsMecha(iClient))
		{
			decl String:strInput[255];
			Format(strInput, sizeof(strInput), "Zombies: %.1f\nHealth: %.1f\nScared: %.1f", fZombies, fHealth, fScared);
			SetHudTextParams(0.04, 0.5, 10.0, 50, 255, 50, 255);
			ShowHudText(iClient, 1, strInput);
		}
		*/
		
		new iMusic = MUSIC_NONE;
		if(isSur(iClient))
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

public Action:command_rabies(client, args)
{
	if(!zf_bEnabled)
		return Plugin_Continue;

	CreateTimer(0.0, SpookySound);
	PrintToConsole(client, "Called rabies");
			
	return Plugin_Continue;
}

public Action:command_goo(client, args)
{
	if(!zf_bEnabled)
		return Plugin_Continue;

	SpitterGoo(client);
			
	return Plugin_Continue;
}

FastRespawnReset()
{
	if(g_hFastRespawnArray != INVALID_HANDLE)
		CloseHandle(g_hFastRespawnArray);
	g_hFastRespawnArray = CreateArray(3);
}

FastRespawnNearby(iClient, Float:fDistance, bool:bMustBeInvisible = true)
{
	if(g_hFastRespawnArray == INVALID_HANDLE)
		return -1;
	
	new Handle: hTombola = CreateArray();
	
	decl Float:fPosClient[3];
	decl Float:fPosEntry[3];
	decl Float:fPosEntry2[3];
	new Float:fEntryDistance;
	GetClientAbsOrigin(iClient, fPosClient);
	for (new i = 0; i < GetArraySize(g_hFastRespawnArray); i++)
	{
		GetArrayArray(g_hFastRespawnArray, i, fPosEntry);
		fPosEntry2[0] = fPosEntry[0];
		fPosEntry2[1] = fPosEntry[1];
		fPosEntry2[2] = fPosEntry[2] += 90.0;
		
		new bool:bAllow = true;
		
		fEntryDistance = GetVectorDistance(fPosClient, fPosEntry);
		fEntryDistance /= 50.0;
		if(fEntryDistance > fDistance) bAllow = false;
		
		// check if survivors can see it
		if(bMustBeInvisible && bAllow)
		{
			for (new iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
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
		new iRandom = GetRandomInt(0, GetArraySize(hTombola)-1);
		new iResult = GetArrayCell(hTombola, iRandom);
		CloseHandle(hTombola);
		return iResult;
	}
	else
	{
		CloseHandle(hTombola);
	}
	return -1;
}

bool:PerformFastRespawn(iClient)
{
	if(!g_bZombieRage || !g_bZombieRageAllowRespawn)
		return false;
	
	return PerformFastRespawn2(iClient);
}

bool:PerformFastRespawn2(iClient)
{	
	// first let's find a target
	new Handle:hTombola = CreateArray();
	for (new i = 1; i <= MaxClients; i++)
	{
		if(validLivingSur(i))
			PushArrayCell(hTombola, i);
	}
	
	if(GetArraySize(hTombola) <= 0)
	{
		CloseHandle(hTombola);
		return false;
	}
	
	new iTarget = GetArrayCell(hTombola, GetRandomInt(0, GetArraySize(hTombola)-1));
	CloseHandle(hTombola);
	
	new iResult = FastRespawnNearby(iTarget, 7.0);
	if(iResult < 0)
		return false;
	
	decl Float:fPosSpawn[3], Float:fPosTarget[3], Float:fAngle[3];
	GetArrayArray(g_hFastRespawnArray, iResult, fPosSpawn);
	GetClientAbsOrigin(iTarget, fPosTarget);
	VectorTowards(fPosSpawn, fPosTarget, fAngle);
	
	TeleportEntity(iClient, fPosSpawn, fAngle, NULL_VECTOR);
	return true;
}

FastRespawnDataCollect()
{
	if(g_hFastRespawnArray == INVALID_HANDLE) FastRespawnReset();
	
	decl Float:fPos[3];
	for (new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient) && validActivePlayer(iClient) && FastRespawnNearby(iClient, 1.0, false)<0 && !(GetEntityFlags(iClient) & FL_DUCKING == FL_DUCKING) && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND))
		{
			GetClientAbsOrigin(iClient, fPos);
			PushArrayArray(g_hFastRespawnArray, fPos);
		}
	}
}

stock VectorTowards(Float:vOrigin[3], Float:vTarget[3], Float:vAngle[3])
{
	decl Float:vResults[3];
	
	MakeVectorFromPoints(vOrigin, vTarget, vResults);
	GetVectorAngles(vResults, vAngle);
}

stock bool:PointsAtTarget(Float:fBeginPos[3], any:iTarget)
{
	new Float:fTargetPos[3];
	GetClientEyePosition(iTarget, fTargetPos);
	
	new Handle:hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(fBeginPos, fTargetPos, MASK_VISIBLE, RayType_EndPoint, TraceDontHitOtherEntities, iTarget);
	
	new iHit = -1;
	if(TR_DidHit(hTrace))
		iHit = TR_GetEntityIndex(hTrace);
	
	CloseHandle(hTrace);
	return (iHit == iTarget);
}

public bool:TraceDontHitOtherEntities(iEntity, iMask, any:iData)
{
	if(iEntity == iData)
		return true;
	if(iEntity > 0)
		return false;

	return true;
}

public bool:TraceDontHitEntity(iEntity, iMask, any:iData)
{
	if(iEntity == iData)
		return false;

	return true;
}

stock bool:CanRecieveDamage(iClient)
{
	if(iClient<=0 || !IsClientInGame(iClient))
		return true;

	if(isUbered(iClient) || isBonked(iClient))
		return false;

	return true;
}

stock GetClientPointVisible(iClient)
{
	decl Float:vOrigin[3], Float:vAngles[3], Float:vEndOrigin[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);
	
	new Handle:hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceDontHitEntity, iClient);
	TR_GetEndPosition(vEndOrigin, hTrace);
	
	new iReturn = -1;
	new iHit = TR_GetEntityIndex(hTrace);
	
	if(TR_DidHit(hTrace) && iHit!=iClient && (GetVectorDistance(vOrigin, vEndOrigin)/50.0)<=2.0)
	{
		iReturn = iHit;
	}
	CloseHandle(hTrace);
	
	return iReturn;
}

stock bool:ObstancleBetweenEntities(iEntity1, iEntity2)
{
	decl Float:vOrigin1[3], Float:vOrigin2[3];
	
	if(validClient(iEntity1)) GetClientEyePosition(iEntity1, vOrigin1);
	else GetEntPropVector(iEntity1, Prop_Send, "m_vecOrigin", vOrigin1);
	GetEntPropVector(iEntity2, Prop_Send, "m_vecOrigin", vOrigin2);
	
	new Handle:hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin1, vOrigin2, MASK_ALL, RayType_EndPoint, TraceDontHitEntity, iEntity1);
	
	new bool:bHit = TR_DidHit(hTrace);
	new iHit = TR_GetEntityIndex(hTrace);
	CloseHandle(hTrace);
	
	if(!bHit || iHit!=iEntity2)
		return true;
	
	return false;
}

HandleClientInventory(iClient)
{
	if(iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_iMode == GAMEMODE_NEW)
	{
		TF2_RemoveWeaponSlot(iClient, 0);
		TF2_RemoveWeaponSlot(iClient, 1);
		RemoveSecondaryWearable(iClient);
	}
	
	new iEntity;
	if(TF2_GetPlayerClass(iClient) == TFClass_Scout && hWeaponSandman != INVALID_HANDLE)
	{
		iEntity = GetPlayerWeaponSlot(iClient, 2);
		if(iEntity > 0 && IsValidEdict(iEntity))
			TF2_RemoveWeaponSlot(iClient, 2);
		iEntity = TF2Items_GiveNamedItem(iClient, hWeaponSandman);
		EquipPlayerWeapon(iClient, iEntity);
	}
	if(TF2_GetPlayerClass(iClient) == TFClass_Heavy)
	{
		if(g_iSpecialInfected[iClient] == INFECTED_TANK && hWeaponSteelFists != INVALID_HANDLE)
		{
			iEntity = GetPlayerWeaponSlot(iClient, 2);
			if(iEntity > 0 && IsValidEdict(iEntity))
				TF2_RemoveWeaponSlot(iClient, 2);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponSteelFists);
			EquipPlayerWeapon(iClient, iEntity);
		}
		else if(hWeaponFists != INVALID_HANDLE)
		{
			iEntity = GetPlayerWeaponSlot(iClient, 2);
			if(iEntity > 0 && IsValidEdict(iEntity))
				TF2_RemoveWeaponSlot(iClient, 2);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponFists);
			EquipPlayerWeapon(iClient, iEntity);
		}
	}
	
	/*if(hWeaponStickyLauncher != INVALID_HANDLE)
	{
		iEntity = GetPlayerWeaponSlot(iClient, 1);
		if(iEntity > 0 && IsValidEdict(iEntity) && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 265)
		{
			TF2_RemoveWeaponSlot(iClient, 1);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponStickyLauncher);
			EquipPlayerWeapon(iClient, iEntity);
		}
	}
	if(hWeaponRocketLauncher != INVALID_HANDLE)
	{
		iEntity = GetPlayerWeaponSlot(iClient, 0);
		if(iEntity > 0 && IsValidEdict(iEntity))
		{
			new iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			if(iIndex == 237 || iIndex == 228)
			{
				TF2_RemoveWeaponSlot(iClient, 0);
				iEntity = TF2Items_GiveNamedItem(iClient, hWeaponRocketLauncher);
				EquipPlayerWeapon(iClient, iEntity);
			}
		}
	}
	if(TF2_GetPlayerClass(iClient) == TFClass_Medic)
	{
		iEntity = GetPlayerWeaponSlot(iClient, 0);
		if(hWeaponSyringe != INVALID_HANDLE && iEntity > 0 && IsValidEdict(iEntity) && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 36)
		{
			TF2_RemoveWeaponSlot(iClient, 0);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponSyringe);
			EquipPlayerWeapon(iClient, iEntity);
		}
		
		iEntity = GetPlayerWeaponSlot(iClient, 2);
		if(hWeaponBonesaw != INVALID_HANDLE && iEntity > 0 && IsValidEdict(iEntity) && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 304)
		{
			TF2_RemoveWeaponSlot(iClient, 2);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponBonesaw);
			EquipPlayerWeapon(iClient, iEntity);
		}
	}
	
	iEntity = GetPlayerWeaponSlot(iClient, 2);
	if(iEntity > 0 && IsValidEdict(iEntity) && (GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 357 || GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 266 || GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 482))
	{
		if(TF2_GetPlayerClass(iClient) == TFClass_DemoMan && hWeaponSword != INVALID_HANDLE)
		{
			TF2_RemoveWeaponSlot(iClient, 2);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponSword);
			EquipPlayerWeapon(iClient, iEntity);
		}
		else if(hWeaponShovel != INVALID_HANDLE)
		{
			TF2_RemoveWeaponSlot(iClient, 2);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponShovel);
			EquipPlayerWeapon(iClient, iEntity);
		}
	}*/
	
	iEntity = GetPlayerWeaponSlot(iClient, 4);
	if(iEntity > 0 && IsValidEdict(iEntity) && hWeaponWatch != INVALID_HANDLE && TF2_GetPlayerClass(iClient) == TFClass_Spy)
	{
		TF2_RemoveWeaponSlot(iClient, 4);
		iEntity = TF2Items_GiveNamedItem(iClient, hWeaponWatch);
		EquipPlayerWeapon(iClient, iEntity);
	}
	
	if(hWeaponSword != INVALID_HANDLE)
	{
		iEntity = GetPlayerWeaponSlot(iClient, 2);
		if(iEntity > 0 && IsValidEdict(iEntity) && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 132)
		{
			TF2_RemoveWeaponSlot(iClient, 2);
			iEntity = TF2Items_GiveNamedItem(iClient, hWeaponSword);
			EquipPlayerWeapon(iClient, iEntity);
		}
	}
	
	SetValidSlot(iClient);
	CheckStartWeapons();
}

SetValidSlot(iClient)
{
	new iOld = GetEntProp(iClient, Prop_Send, "m_hActiveWeapon");
	if(iOld > 0)
		return;
	
	new iSlot;
	new iEntity;
	for (iSlot = 0; iSlot <= 5; iSlot++)
	{
		iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if(iEntity > 0 && IsValidEdict(iEntity))
		{
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);
			return;
		}
	}
}

SetupSDK()
{
	/*hConfiguration = LoadGameConfigFile("mechatheslag_global");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConfiguration, SDKConf_Virtual, "EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	hEquipWearable = EndPrepSDKCall();*/
}

SetupWeapons()
{
	// Scout's Special Stun Bat
	hWeaponSandman = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponSandman, "tf_weapon_bat_wood");
	TF2Items_SetItemIndex(hWeaponSandman, 44);
	TF2Items_SetQuality(hWeaponSandman, 6);
	TF2Items_SetAttribute(hWeaponSandman, 0, 38, 1.0);
	TF2Items_SetNumAttributes(hWeaponSandman, 1);
	
	// Sticky Launcher
	hWeaponStickyLauncher = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponStickyLauncher, "tf_weapon_pipebomblauncher");
	TF2Items_SetItemIndex(hWeaponStickyLauncher, 20);
	TF2Items_SetQuality(hWeaponStickyLauncher, 0);
	TF2Items_SetNumAttributes(hWeaponStickyLauncher, 0);
	
	// Rocket Launcher
	hWeaponRocketLauncher = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponRocketLauncher, "tf_weapon_rocketlauncher");
	TF2Items_SetItemIndex(hWeaponRocketLauncher, 18);
	TF2Items_SetQuality(hWeaponRocketLauncher, 0);
	TF2Items_SetNumAttributes(hWeaponRocketLauncher, 0);
	
	// Loch'n'Load
	hWeaponLochNLoad = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponLochNLoad, "tf_weapon_grenadelauncher");
	TF2Items_SetItemIndex(hWeaponLochNLoad, 308);
	TF2Items_SetQuality(hWeaponLochNLoad, 0);
	TF2Items_SetAttribute(hWeaponLochNLoad, 0, 127, 2.0);
	TF2Items_SetAttribute(hWeaponLochNLoad, 1, 103, 1.25);
	TF2Items_SetNumAttributes(hWeaponLochNLoad, 2);
	
	// Flaregun
	hWeaponFlareGun = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponFlareGun, "tf_weapon_flaregun");
	TF2Items_SetItemIndex(hWeaponFlareGun, 39);
	TF2Items_SetQuality(hWeaponFlareGun, 0);
	TF2Items_SetAttribute(hWeaponFlareGun, 0, 25, 0.5);
	TF2Items_SetNumAttributes(hWeaponFlareGun, 1);
	
	// Shotgun (Pyro)
	hWeaponShotgunPyro = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponShotgunPyro, "tf_weapon_shotgun_pyro");
	TF2Items_SetItemIndex(hWeaponShotgunPyro, 12);
	TF2Items_SetQuality(hWeaponShotgunPyro, 0);
	TF2Items_SetNumAttributes(hWeaponShotgunPyro, 0);
	
	// Shotgun (Soldier)
	hWeaponShotgunSoldier = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponShotgunSoldier, "tf_weapon_shotgun_soldier");
	TF2Items_SetItemIndex(hWeaponShotgunSoldier, 10);
	TF2Items_SetQuality(hWeaponShotgunSoldier, 0);
	TF2Items_SetNumAttributes(hWeaponShotgunSoldier, 0);
	
	// Rightous Bison
	hWeaponBison = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponBison, "tf_weapon_raygun");
	TF2Items_SetItemIndex(hWeaponBison, 442);
	TF2Items_SetQuality(hWeaponBison, 6);
	TF2Items_SetAttribute(hWeaponFlareGun, 0, 281, 1.0);
	TF2Items_SetNumAttributes(hWeaponBison, 1);
	
	// Chargin' Targe
	hWeaponTarge = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponTarge, "tf_wearable_demoshield");
	TF2Items_SetItemIndex(hWeaponTarge, 131);
	TF2Items_SetQuality(hWeaponTarge, 6);
	TF2Items_SetNumAttributes(hWeaponTarge, 0);
	
	// Demoman's Eyelander
	hWeaponSword = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponSword, "tf_weapon_sword");
	TF2Items_SetItemIndex(hWeaponSword, 132);
	TF2Items_SetQuality(hWeaponSword, 6);
	TF2Items_SetNumAttributes(hWeaponSword, 0);

	// Shovel
	hWeaponShovel = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponShovel, "tf_weapon_shovel");
	TF2Items_SetItemIndex(hWeaponShovel, 6);
	TF2Items_SetQuality(hWeaponShovel, 0);
	TF2Items_SetNumAttributes(hWeaponShovel, 0);
	
	// Fists
	hWeaponFists = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponFists, "tf_weapon_fists");
	TF2Items_SetItemIndex(hWeaponFists, 5);
	TF2Items_SetQuality(hWeaponFists, 0);
	TF2Items_SetNumAttributes(hWeaponFists, 0);
	
	// Fists of Steel
	hWeaponSteelFists = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponSteelFists, "tf_weapon_fists");
	TF2Items_SetItemIndex(hWeaponSteelFists, 331);
	TF2Items_SetQuality(hWeaponSteelFists, 6);
	TF2Items_SetNumAttributes(hWeaponSteelFists, 0);
	
	// Stock Syringe Gun
	hWeaponSyringe = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponSyringe, "tf_weapon_syringegun_medic");
	TF2Items_SetItemIndex(hWeaponSyringe, 17);
	TF2Items_SetQuality(hWeaponSyringe, 0);
	TF2Items_SetNumAttributes(hWeaponSyringe, 0);
	
	// Stock Bonesaw
	hWeaponBonesaw = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponBonesaw, "tf_weapon_bonesaw");
	TF2Items_SetItemIndex(hWeaponBonesaw, 8);
	TF2Items_SetQuality(hWeaponBonesaw, 0);
	TF2Items_SetNumAttributes(hWeaponBonesaw, 0);
	
	// Stock Watch
	hWeaponWatch = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeaponWatch, "tf_weapon_invis");
	TF2Items_SetItemIndex(hWeaponWatch, 30);
	TF2Items_SetQuality(hWeaponWatch, 0);
	TF2Items_SetNumAttributes(hWeaponWatch, 0);
}

SpitterGoo(iClient, iAttacker = 0)
{
	if(roundState() != RoundActive)
		return;

	//PrintToChatAll("Spitter goo at %N!", iClient);
	
	if(g_hGoo == INVALID_HANDLE) g_hGoo = CreateArray(5);
	
	decl Float:fClientPos[3], Float:fClientEye[3];
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyeAngles(iClient, fClientEye);
	
	g_iGooId++;	
	decl iEntry[5];
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

GooDamageCheck()
{
	decl Float:fPosGoo[3], iEntry[5], Float:fPosClient[3]; 
	new Float:fDistance;
	new iAttacker;
	
	new bool:bWasGooified[MAXPLAYERS+1];
	
	new iClient;
	for (iClient = 1; iClient <= MaxClients; iClient++)
	{
		bWasGooified[iClient] = g_bGooified[iClient];
		g_bGooified[iClient] = false;
	}
	
	if(g_hGoo != INVALID_HANDLE)
	{
		for (new i = 0; i < GetArraySize(g_hGoo); i++)
		{
			GetArrayArray(g_hGoo, i, iEntry);
			fPosGoo[0] = float(iEntry[0]);
			fPosGoo[1] = float(iEntry[1]);
			fPosGoo[2] = float(iEntry[2]);
			iAttacker = iEntry[3];
			
			for (iClient = 1; iClient <= MaxClients; iClient++)
			{
				if(validLivingSur(iClient) && !g_bGooified[iClient] && CanRecieveDamage(iClient) && !g_bBackstabbed[iClient])
				{
					GetClientEyePosition(iClient, fPosClient);
					fDistance = GetVectorDistance(fPosGoo, fPosClient) / 50.0;
					if(fDistance <= DISTANCE_GOO)
					{
						// deal damage
						g_iGooMultiplier[iClient] += GOO_INCREASE_RATE;
						new Float:fPercentageDistance = (DISTANCE_GOO-fDistance) / DISTANCE_GOO;
						if(fPercentageDistance < 0.5) fPercentageDistance = 0.5;
						new Float:fDamage = float(g_iGooMultiplier[iClient])/float(GOO_INCREASE_RATE) * fPercentageDistance;
						if(fDamage < 1.0) fDamage = 1.0;
						new iDamage = RoundFloat(fDamage);
						DealDamage(iClient, iDamage, iAttacker, _, "projectile_stun_ball");
						g_bGooified[iClient] = true;
						
						if(fDamage >= 7.0)
						{
							new iRandom = GetRandomInt(0, sizeof(g_strSoundCritHit)-1);
							EmitSoundToClient(iClient, g_strSoundCritHit[iRandom], _, SNDLEVEL_AIRCRAFT);
						}
						else
						{
							new iRandom = GetRandomInt(0, sizeof(g_strSoundFleshHit)-1);
							EmitSoundToClient(iClient, g_strSoundFleshHit[iRandom], _, SNDLEVEL_AIRCRAFT);
						}
					}
				}
			}  
		}
	}
	for (iClient = 1; iClient <= MaxClients; iClient++)
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

public Action:GooExpire(Handle:hTimer, any:iGoo)
{
	if(g_hGoo == INVALID_HANDLE)
		return;
	
	decl iEntry[5];
	new iEntryId;
	for (new i = 0; i < GetArraySize(g_hGoo); i++)
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

RemoveAllGoo()
{
	if(g_hGoo == INVALID_HANDLE)
		return;
	
	ClearArray(g_hGoo);
}

public Action:GooEffect(Handle:hTimer, any:iGoo)
{
	if(g_hGoo == INVALID_HANDLE)
		return Plugin_Stop;
	
	decl iEntry[5], Float:fPos[3];
	new iEntryId;
	for (new i = 0; i < GetArraySize(g_hGoo); i++)
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

public OnEntityCreated(iEntity, const String:strClassname[])
{
	if(StrEqual(strClassname, "tf_projectile_stun_ball", false))
	{
		SDKHook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKHook(iEntity, SDKHook_Touch, BallTouch);
	}
}

public Action:BallStartTouch(iEntity, iOther)
{
	if(!zf_bEnabled || !IsClassname(iEntity, "tf_projectile_stun_ball"))
		return Plugin_Continue;
	
	if(iOther > 0 && iOther <= MaxClients && IsClientInGame(iOther) && IsPlayerAlive(iOther) && isSur(iOther))
	{
		new iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		if(!(GetEntityFlags(iEntity) & FL_ONGROUND))
		{
			SpitterGoo(iOther, iOwner);
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action:BallTouch(iEntity, iOther)
{
	if(!zf_bEnabled || !IsClassname(iEntity, "tf_projectile_stun_ball"))
		return Plugin_Continue;
	
	if(iOther > 0 && iOther <= MaxClients && IsClientInGame(iOther) && IsPlayerAlive(iOther) && isSur(iOther))
	{
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKUnhook(iEntity, SDKHook_Touch, BallTouch);
		AcceptEntityInput(iEntity, "kill");
	}
	
	return Plugin_Stop;
}

stock ShowParticle(String:particlename[], Float:time, Float:pos[3], Float:ang[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
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

stock PrecacheParticle(String:strName[])
{
	if(IsValidEntity(0))
	{
		new iParticle = CreateEntityByName("info_particle_system");
		if(IsValidEdict(iParticle))
		{
			new String:tName[32];
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

public Action:RemoveParticle(Handle:timer, any:particle)
{
	if(particle >= 0 && IsValidEntity(particle))
	{
		new String:classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if(StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "Kill");
			particle = -1;
		}
	}
}

stock DealDamage(iVictim, iDamage, iAttacker=0,iDmgType=DMG_GENERIC, String:strWeapon[]="")
{
	if(!validClient(iAttacker))
		iAttacker = 0;

	if(validClient(iVictim) && iDamage > 0)
	{
		decl String:strDamage[16];
		IntToString(iDamage, strDamage, 16);
		decl String:strDamageType[32];
		IntToString(iDmgType, strDamageType, 32);
		new iHurt = CreateEntityByName("point_hurt");
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

GetMostDamageZom()
{
	new Handle:hArray = CreateArray();
	new i;
	new iHighest = 0;
	
	for (i = 1; i <= MaxClients; i++)
	{
		if(validZom(i))
		{
			if(g_iDamage[i] > iHighest) iHighest = g_iDamage[i];
		}
	}
	
	for (i = 1; i <= MaxClients; i++)
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
	
	new iClient = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray)-1));
	CloseHandle(hArray);
	return iClient;
}

bool:ZombiesHaveTank()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(validLivingZom(i) && g_iSpecialInfected[i] == INFECTED_TANK) return true;
	}
	return false;
}

ZombieTank(iCaller = 0)
{
	if(!zf_bEnabled || roundState()!=RoundActive) 
		return;
	
	if(ZombiesHaveTank())
	{
		if(validClient(iCaller)) CPrintToChat(iCaller, "{olive}[SZF]{default} %t", "Tank Deny Active");
		return;
	}
	if(g_iZombieTank > 0)
	{   
		if(validClient(iCaller)) CPrintToChat(iCaller, "{olive}[SZF]{default} %t","Tank Deny Ready");
		return;
	}
	if(g_bZombieRage)
	{
		if(validClient(iCaller)) CPrintToChat(iCaller, "{olive}[SZF]{default} %t","Tank Deny Frenzy");
		return;
	}
	
	g_iZombieTank = GetMostDamageZom();
	if(g_iZombieTank <= 0) return;
	
	for (new i = 1; i <= MaxClients; i++)
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

public Action:command_tank(client, args)
{
	if(!zf_bEnabled) return Plugin_Handled;
	if(ZombiesHaveTank()) return Plugin_Handled;
	if(g_iZombieTank > 0) return Plugin_Handled;
	if(g_bZombieRage) return Plugin_Handled;

	g_iZombieTank = client;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(validZom(i))
		{
			CPrintToChat(i, "%t", "{olive}[SZF]{default} %t", "Tank Choosen", g_iZombieTank);
		}
	}
			
	return Plugin_Handled;
}

bool:TankCanReplace(iClient)
{
	if(g_iZombieTank <= 0) return false;
	if(g_iZombieTank == iClient) return false;
	if(g_iSpecialInfected[iClient] != INFECTED_NONE) return false;
	if(TF2_GetPlayerClass(iClient) != TF2_GetPlayerClass(g_iZombieTank)) return false;
	
	new iHealth = GetClientHealth(g_iZombieTank);
	decl Float:fPos[3];
	decl Float:fAng[3];
	decl Float:fVel[3];
	
	GetClientAbsOrigin(g_iZombieTank, fPos);
	GetClientAbsAngles(g_iZombieTank, fVel);
	GetEntPropVector(g_iZombieTank, Prop_Data, "m_vecVelocity", fVel);
	SetEntityHealth(iClient, iHealth);
	TeleportEntity(iClient, fPos, fAng, fVel);
	
	TF2_RespawnPlayer(g_iZombieTank);
	CreateTimer(0.1, timer_postSpawn, g_iZombieTank, TIMER_FLAG_NO_MAPCHANGE);
	
	return true;
}

public Action:command_tank_random(client, args)
{
	if(!zf_bEnabled) return Plugin_Handled;
	ZombieTank(client);
			
	return Plugin_Handled;
}

public Action:TF2Items_OnGiveNamedItem(client, String:classname[], iItemDefinitionIndex, &Handle:item)
{
	if(!zf_bEnabled)
	{
		return Plugin_Continue;
	}

	switch(iItemDefinitionIndex)
	{
		case 36:	// Blutsauger
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "16 ; 1 ; 129 ; 0 ; 191 ; -2");
			// 16: On Hit: Gain up to +1 health
			// 129:	0 health drained per second on wearer
			// 191:	-2 health drained per second on wearer
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_RemoveByDefIndex(client, 129);
			}
			#endif
		}
		case 129, 1001:	// Buff Banner
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "319 ; 0.6");
			// 319:	-40% buff duration
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 132, 266, 482, 1082:	// Eyelander, Horseless Headless Horsemann's Headtaker, Nessie's Nine Iron, Festive Eyelander
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "54 ; 0.75");
			// 54:	-25% slower move speed on wearer
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 133:	// Gunboats
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5 ; 135 ; 0.7");
			// 58:	+50% self damage force
			// 135:	-30% blast damage from rocket jumps
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_SetByDefIndex(client, 58, 1.5);
				TF2Attrib_SetByDefIndex(client, 135, 0.7);
			}
			#endif
		}
		case 142:	// Gunslinger
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "26 ; 0");
			// 26:	+0 max health on wearer
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_RemoveByDefIndex(client, 26);
			}
			#endif
		}
		case 155:	// Southern Hospitality
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "61 ; 1 ; 412 ; 1.1");
			// 61: 0% fire damage vulnerability on wearer
			// 412: 10% damage vulnerability on wearer
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 226:	// Battalion's Backup
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "26 ; 0 ; 140 ; 10 ; 319 ; 0.6");
			// 26:	+0 max health on wearer
			// 140:	+10 max health on wearer
			// 319:	-40% buff duration
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_RemoveByDefIndex(client, 26);
			}
			#endif
		}
		case 228:	// Black Box
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "741 ; 5");
			// 741:	On Hit: Gain up to +5 health per attack
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 237, 265:	// Rocket Jumper & Sticky Jumper
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.3");
			// 58:	+30% self damage force
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 304:	// Amputator
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "57 ; 0 ; 190 ; 1");
			// 57:	+0 health regenerated per second on wearer
			// 190:	+1 health regenerated per second on wearer
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_RemoveByDefIndex(client, 57);
			}
			#endif
		}
		case 354:	// Concheror
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "57 ; 0 ; 190 ; 1 ; 319 ; 0.6");
			// 57:	+0 health regenerated per second on wearer
			// 190:	+1 health regenerated per second on wearer
			// 319:	-40% buff duration
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_RemoveByDefIndex(client, 57);
			}
			#endif
		}
		case 404:	// Persian Persuader
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "778 ; 1.15");
			// 58:	Melee hits refill 15% of your charge meter
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 405, 608:	// Ali Baba's Wee Booties & Bootlegger
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "26 ; 0 ; 140 ; 20");
			// 26:	+0 max health on wearer
			// 140:	+20 max health on wearer
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_RemoveByDefIndex(client, 26);
				TF2Attrib_SetByDefIndex(client, 140, 20.0);
			}
			#endif
		}
		case 444:	// Mantreads
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5 ; 135 ; 1.3");
			// 58:	+50% self damage force
			// 135:	+30% blast damage from rocket jumps
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_SetByDefIndex(client, 58, 1.5);
				TF2Attrib_SetByDefIndex(client, 135, 1.3);
			}
			#endif
		}
		case 642:	// Cozy Camper
		{
			new Handle:itemOverride=PrepareItemHandle(item, _, _, "57 ; 0 ; 190 ; 1");
			// 57:	+0 health regenerated per second on wearer
			// 190:	+1 health regenerated per second on wearer
			if(itemOverride!=INVALID_HANDLE)
			{
				item=itemOverride;
				return Plugin_Changed;
			}

			#if defined _tf2attributes_included
			if(tf2attributes)
			{
				TF2Attrib_RemoveByDefIndex(client, 57);
				TF2Attrib_SetByDefIndex(client, 190, 1.0);
			}
			#endif
		}
	}
	if(!StrContains(classname, "tf_weapon_shovel") ||
	   !StrContains(classname, "tf_weapon_fireaxe") ||
	   !StrContains(classname, "tf_weapon_breakable_sign") ||
	   !StrContains(classname, "tf_weapon_slap") ||
	   !StrContains(classname, "tf_weapon_bottle") ||
	   !StrContains(classname, "tf_weapon_sword") ||
	   !StrContains(classname, "tf_weapon_katana") ||
	   !StrContains(classname, "tf_weapon_wrench") ||
	   !StrContains(classname, "tf_weapon_robot_arm") ||
	   !StrContains(classname, "tf_weapon_club"))			// Melees
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "28 ; 0.5 ; 69 ; 0.1");
		// 28:	-50% random critical hit chance
		// 69:	-90% health from healers on wearer
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Soldier && !StrContains(classname, "tf_weapon_rocketlauncher"))	// Soldier Rocket Launchers
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "59 ; 0.5 ; 77 ; 0.75 ; 135 ; 0.5");
		// 59:	-50% self damage force
		// 77:	-25% max primary ammo on wearer
		// 135:	-50% blast damage from rocket jumps
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Soldier && !StrContains(classname, "tf_weapon_particle_cannon"))	// Cow Mangler 5000
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "5 ; 1.35 ; 59 ; 0.5 ; 72 ; 0.5 ; 77 ; 0.75 ; 96 ; 1.5 ; 135 ; 0.5");
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
	if(TF2_GetPlayerClass(client)==TFClass_Soldier && !StrContains(classname, "tf_weapon_raygun"))	// Righteous Bison
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "5 ; 1.25 ; 96 ; 1.35");
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
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5 ; 135 ; 1.3");
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
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "220 ; 15");
		// 220:	Gain 15% of base health on kill
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Pyro && !StrContains(classname, "tf_weapon_flamethrower"))	// Flamethrowers
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "77 ; 0.5 ; 869 ; 1");
		// 77:	-50% max primary ammo on wearer
		// 869:	Minicrits whenever it would normally crit
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Pyro && !StrContains(classname, "tf_weapon_rocketlauncher_fireball"))	// Dragon's Fury
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "795 ; 0.6 ; 869 ; 1");
		// 795:	-40% damage bonus vs burning players
		// 869:	Minicrits whenever it would normally crit
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Pyro && !StrContains(classname, "tf_weapon_jar_gas"))	// Gas Passer
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "2059 ; 3000");
		// 2059:	
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_DemoMan && !StrContains(classname, "tf_weapon_grenadelauncher") || !StrContains(classname, "tf_weapon_cannon"))	// Grenade Launchers & Loose Cannon
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "77 ; 0.75");
		// 77:	-25% max primary ammo on wearer
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_DemoMan && !StrContains(classname, "tf_weapon_pipebomblauncher"))	// Stickybomb Launchers
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "59 ; 0.5 ; 79 ; 0.75 ; 135 ; 0.5");
		// 59:	-50% self damage force
		// 79:	-25% max secondary ammo on wearer
		// 135:	-50% blast damage from rocket jumps
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_DemoMan && !StrContains(classname, "tf_wearable_demoshield"))	// Chargin' Targe, Splendid Screen, Tide Turner, Festive Targe
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.5");
		// 249:	-50% increase in charge recharge rate
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_DemoMan && !StrContains(classname, "tf_wearable_stickbomb"))	// Ullapool Caber
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "28 ; 0.25 ; 734 ; 0.1", true);
		// 28: -75% random critical hit chance
		// 734:	-90% less healing from all sources
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Engineer && !StrContains(classname, "tf_weapon_shotgun_revenge"))	// Frontier Justice
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "869 ; 1");
		// 869:	Minicrits whenever it would normally crit
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Engineer && !StrContains(classname, "tf_weapon_drg_pomson"))	// Pomson 6000
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "5 ; 1.2 ; 96 ; 1.35");
		// 5:	-20% slower fire rate
		// 96:	+35% slower reload time
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Engineer && !StrContains(classname, "tf_weapon_shotgun_building_rescue"))	// Rescue Ranger
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "77 ; 0.75");
		// 77:	-25% max primary ammo on wearer
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Engineer && !StrContains(classname, "tf_weapon_pistol"))	// Engineer Pistols
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "79 ; 0.24");
		// 79:	-76% max secondary ammo on wearer
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Engineer && !StrContains(classname, "tf_weapon_mechanical_arm"))	// Short Circuit
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "20 ; 1 ; 408 ; 1");
		// 20:	100% critical hit vs burning players
		// 408:	100% critical hit vs non-burning players
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Engineer && !StrContains(classname, "tf_weapon_pda_engineer_build"))	// Engineer Build PDAs
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "286 ; 0.5 ; 287 ; 0.65 ; 464 ; 0.5 ; 465 ; 0.5 ; 790 ; 10");
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
	if(TF2_GetPlayerClass(client)==TFClass_Medic && !StrContains(classname, "tf_weapon_crossbow"))	// Crusader's Crossbow
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "2 ; 3 ; 77 ; 0.2 ; 138 ; 0.333 ; 775 ; 0.333");
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
	if(TF2_GetPlayerClass(client)==TFClass_Medic && !StrContains(classname, "tf_weapon_medigun"))	// Medi Guns
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "9 ; 0.2");
		// 9:	-80% ÜberCharge rate
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Medic && !StrContains(classname, "tf_weapon_bonesaw"))	// Medic Melees
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "28 ; 0.3 ; 131 ; 4 ; 69 ; 0.15");
		// 28:	-70% random critical hit chance
		// 69:	-85% health from healers on wearer
		// 131:	-300% natural regen rate
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	if(TF2_GetPlayerClass(client)==TFClass_Sniper && !StrContains(classname, "tf_weapon_jar"))	// Jarate
	{
		new Handle:itemOverride=PrepareItemHandle(item, _, _, "249 ; 0.4");
		// 249:	-60% increase in charge recharge rate
		if(itemOverride!=INVALID_HANDLE)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action:Timer_CheckItems(Handle:timer, any:userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client) || !IsPlayerAlive(client) || !zf_bEnabled)
	{
		return Plugin_Continue;
	}

	SetEntityRenderColor(client, 255, 255, 255, 255);
	new index=-1;
	new civilianCheck[MaxClients+1];

	new weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
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
		index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch(index)
		{
			case 998:	// Vaccinator
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				SpawnWeapon(client, "tf_weapon_medigun", 29, 1, 0, "9 ; 0.2");
			}
		}

		if(TF2_GetPlayerClass(client)==TFClass_Medic)
		{
			if(GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee)==142)  //Gunslinger (Randomizer, etc. compatability)
			{
				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, 255, 255, 255, 75);
			}
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
				SpawnWeapon(client, "tf_weapon_wrench", 7, 1, 0, "28 ; 0.5 ; 69 ; 0.1");
			}
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
	civilianCheck[client]=0;
	return Plugin_Continue;
}

stock Handle:PrepareItemHandle(Handle:item, String:name[]="", index=-1, const String:att[]="", bool:dontPreserve=false)
{
	static Handle:weapon;
	new addattribs;

	new String:weaponAttribsArray[32][32];
	new attribCount=ExplodeString(att, ";", weaponAttribsArray, 32, 32);

	if(attribCount % 2)
	{
		--attribCount;
	}

	new flags=OVERRIDE_ATTRIBUTES;
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
	//new Handle:weapon=TF2Items_CreateItem(flags);  //INVALID_HANDLE;  Going to uncomment this since this is what Randomizer does

	if(item!=INVALID_HANDLE)
	{
		addattribs=TF2Items_GetNumAttributes(item);
		if(addattribs>0)
		{
			for(new i; i<2*addattribs; i+=2)
			{
				new bool:dontAdd=false;
				new attribIndex=TF2Items_GetAttributeId(item, i);
				for(new z; z<attribCount+i; z+=2)
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
		new i2;
		for(new i; i<attribCount && i2<16; i+=2)
		{
			new attrib=StringToInt(weaponAttribsArray[i]);
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

stock SpawnWeapon(client, String:name[], index, level, qual, String:att[])
{
	new Handle:hWeapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if(hWeapon==INVALID_HANDLE)
	{
		return -1;
	}

	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	new String:atts[32][32];
	new count=ExplodeString(att, ";", atts, 32, 32);

	if(count % 2)
	{
		--count;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		new i2;
		for(new i; i<count; i+=2)
		{
			new attrib=StringToInt(atts[i]);
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

	new entity=TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock GetIndexOfWeaponSlot(client, slot)
{
	new weapon=GetPlayerWeaponSlot(client, slot);
	return (weapon>MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock bool:IsValidClient(client, bool:replaycheck = true)
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

stock FindEntityByClassname2(startEnt, const String:classname[])
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

stock bool:HasRazorback(iClient) {
	new iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable")) != -1)
	{
		if(IsClassname(iEntity, "tf_wearable") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 57) return true;
	}
	return false;
}

stock bool:RemoveSecondaryWearable(iClient)
{
	new iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_demoshield")) != -1)
	{
		if(IsClassname(iEntity, "tf_wearable_demoshield") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			RemoveEdict(iEntity);
			return true;
		}
	}
	return false;
}

public Action:RemoveBackstab(Handle:hTimer, any:iClient)
{
	if(!validClient(iClient)) return;
	if(!IsPlayerAlive(iClient)) return;
	g_bBackstabbed[iClient] = false;
}

bool:MusicCanReset(iMusic)
{
	if(iMusic == MUSIC_INTENSE) return false;
	if(iMusic == MUSIC_MILD) return false;
	if(iMusic == MUSIC_VERYMILD3) return false;
	return true;
}

stock bool:IsClassname(iEntity, String:strClassname[]) {
	if(iEntity <= 0) return false;
	if(!IsValidEdict(iEntity)) return false;
	
	decl String:strClassname2[32];
	GetEdictClassname(iEntity, strClassname2, sizeof(strClassname2));
	if(StrEqual(strClassname, strClassname2, false)) return true;
	return false;
}

GiveBonus(iClient, String:strBonus[])
{
	if(iClient <= 0) return;
	if(!IsClientInGame(iClient)) return;
	if(IsFakeClient(iClient)) return;
	
	//if(iClient != GetMecha()) return;
	
	if(g_hBonus[iClient] == INVALID_HANDLE)
	{
		g_iBonusCombo[iClient] = 0;
		g_bBonusAlt[iClient] = false;
		g_hBonus[iClient] = CreateArray(255);
	}
	
	PushArrayString(g_hBonus[iClient], strBonus);
	
	if(g_hBonusTimers[iClient] == INVALID_HANDLE) g_hBonusTimers[iClient] = CreateTimer(1.0, ShowBonus, iClient);
}

public Action:ShowBonus(Handle:hTimer, any:iClient)
{
	g_hBonusTimers[iClient] = INVALID_HANDLE;
	
	if(iClient <= 0) return Plugin_Handled;
	if(!IsClientInGame(iClient)) return Plugin_Handled;
	
	
	if(GetArraySize(g_hBonus[iClient]) <= 0)
	{
		ClientCommand(iClient, "r_screenoverlay \"\"");
		CloseHandle(g_hBonus[iClient]);
		g_hBonus[iClient] = INVALID_HANDLE;
		return Plugin_Handled;
	}
	
	if(!g_bBonusAlt[iClient])
	{
		decl String:strEntry[255];
		decl String:strPath[PLATFORM_MAX_PATH];
		GetArrayString(g_hBonus[iClient], 0, strEntry, sizeof(strEntry));
		Format(strPath, sizeof(strPath), "r_screenoverlay\"left4fortress/%s\"", strEntry);
		ClientCommand(iClient, strPath);
		
		new iPitch = g_iBonusCombo[iClient] * 30 + 100;
		if(iPitch > 250) iPitch = 250;
		
		new iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_AWARD]-1);
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
		if(g_hBonusTimers[iClient] == INVALID_HANDLE) g_hBonusTimers[iClient] = CreateTimer(0.1, ShowBonus, iClient);
	}
	
	new Handle:event=CreateEvent("player_escort_score", true);
	SetEventInt(event, "player", iClient);
	SetEventInt(event, "points", 5);
	FireEvent(event);
	
	g_bBonusAlt[iClient] = !g_bBonusAlt[iClient];
	
	return Plugin_Handled;
}

GetAverageDamage()
{
	new iTotalDamage = 0;
	new iCount = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			iTotalDamage += g_iDamage[i];
			iCount++;
		}
	}
	return RoundFloat(float(iTotalDamage) / float(iCount));
}

PrecacheBonus(String:strPath[])
{
	decl String:strPath2[PLATFORM_MAX_PATH];
	Format(strPath2, sizeof(strPath2), "materials/left4fortress/%s.vmt", strPath);
	AddFileToDownloadsTable(strPath2);
	Format(strPath2, sizeof(strPath2), "materials/left4fortress/%s.vtf", strPath);
	AddFileToDownloadsTable(strPath2);
}

RemovePhysicObjects()
{
	if(g_iMode == GAMEMODE_NEW) return;
	new index = -1; 
	while ((index = FindEntityByClassname(index, "prop_physics")) != -1)
	{
		if(IsClassname(index, "prop_physics")) AcceptEntityInput(index, "Kill");
	}
}

GetActivePlayerCount()
{
	new i = 0;
	for (new j = 1; j <= MaxClients; j++)
	{
		if(validActivePlayer(j)) i++;
	}
	return i;
}

DetermineControlPoints()
{
	g_bCapturingLastPoint = false;
	g_iControlPoints = 0;
	
	for (new i = 0; i < sizeof(g_iControlPointsInfo); i++)
	{
		g_iControlPointsInfo[i][0] = -1;
	}
	
	//LogMessage("SZF: Calculating cps...");
	
	new iMaster = -1;

	new iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point_master")) != -1)
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
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point")) != -1) {
		if(IsClassname(iEntity, "team_control_point") && g_iControlPoints < sizeof(g_iControlPointsInfo)) {
			new iIndex = GetEntProp(iEntity, Prop_Data, "m_iPointIndex");			
			g_iControlPointsInfo[g_iControlPoints][0] = iIndex;
			g_iControlPointsInfo[g_iControlPoints][1] = 0;
			g_iControlPoints++;
			
			//LogMessage("Found CP with index %d", iIndex);
		}
	}
	
	//LogMessage("Found a total of %d cps", g_iControlPoints);
	
	CheckRemainingCP();
}

public Action:OnCPCapture(Handle:hEvent, const String:strName[], bool:bHide)
{
	if(g_iControlPoints <= 0) return;
	
	//LogMessage("Captured CP");

	new iCaptureIndex = GetEventInt(hEvent, "cp");
	if(iCaptureIndex < 0) return;
	if(iCaptureIndex >= g_iControlPoints) return;
	
	for (new i = 0; i < g_iControlPoints; i++)
	{
		if(g_iControlPointsInfo[i][0] == iCaptureIndex)
		{
			g_iControlPointsInfo[i][1] = 2;
		}
	}
	
	CheckRemainingCP();
}

public Action:OnCPCaptureStart(Handle:hEvent, const String:strName[], bool:bHide)
{
	if(g_iControlPoints <= 0) return;
	

	new iCaptureIndex = GetEventInt(hEvent, "cp");
	//LogMessage("Began capturing CP #%d / (total %d)", iCaptureIndex, g_iControlPoints);
	if(iCaptureIndex < 0) return;
	if(iCaptureIndex >= g_iControlPoints) return;
	
	for (new i = 0; i < g_iControlPoints; i++)
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

CheckRemainingCP()
{
	g_bCapturingLastPoint = false;
	if(g_iControlPoints <= 0) return;
	
	//LogMessage("Checking remaining CP");

	new iCaptureCount = 0;
	new iCapturing = 0;
	for (new i = 0; i < g_iControlPoints; i++)
	{
		if(g_iControlPointsInfo[i][1] >= 2) iCaptureCount++;
		if(g_iControlPointsInfo[i][1] == 1) iCapturing++;
	}
	
	//LogMessage("Capture count: %d, Max CPs: %d, Capturing: %d", iCaptureCount, g_iControlPoints, iCapturing);
	
	if(iCaptureCount == g_iControlPoints-1 && iCapturing > 0)
	{
		g_bCapturingLastPoint = true;
		if(g_fZombieDamageScale < 1.0 && !g_bTankOnce) ZombieTank();
	}
}

TFClassWeapon:GetWeaponInfoFromModel(String:strModel[], &iSlot, &iSwitchSlot, &Handle:hWeapon, &bool:bWearable, String:strName[], iMaxSize)
{
	new TFClassWeapon:iClass = TFClassWeapon_Unknown;
	
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

AttemptGrabItem(iClient)
{
	new iTarget = GetClientPointVisible(iClient);
	new iWeapon;
	new String:strClassname[255];
	if (iTarget > 0)
		GetEdictClassname(iTarget, strClassname, sizeof(strClassname));
	if (iTarget<=0 || !IsClassname(iTarget, "prop_dynamic"))
		return false;

	decl String:strModel[255];
	GetEntityModel(iTarget, strModel, sizeof(strModel));

	if(TF2_GetPlayerClass(iClient) == TFClass_Soldier) // Soldier Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_shotgun.mdl"))
		{
			//GiveItem(iClient, 10, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun_soldier", 10, 1, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_shotgun/c_shotgun.mdl"))
		{
			//GiveItem(iClient, 10, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun_soldier", 10, 1, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_rocketlauncher.mdl"))
		{
			//GiveItem(iClient, 18, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_rocketlauncher", 18, 1, 19, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_blackbox/c_blackbox.mdl"))
		{
			//GiveItem(iClient, 228, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_rocketlauncher", 228, 5, 18, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_directhit/c_directhit.mdl"))
		{
			//GiveItem(iClient, 127, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_rocketlauncher_directhit", 127, 5, 19, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bet_rocketlauncher/c_bet_rocketlauncher.mdl"))
		{
			//GiveItem(iClient, 513, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_rocketlauncher", 513, 5, 19, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl"))
		{
			//GiveItem(iClient, 415, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun_soldier", 415, 5, 36, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl"))
		{
			//GiveItem(iClient, 442, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_raygun", 442, 5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_liberty_launcher/c_liberty_launcher.mdl"))
		{
			//GiveItem(iClient, 414, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_rocketlauncher", 414, 5, 20, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl"))
		{
			//GiveItem(iClient, 441, iTarget) 
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_buff_item", 129, 5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_shogun_warhorn/c_shogun_warhorn.mdl"))
		{
			//GiveItem(iClient, 354, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_buff_item", 354, 5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bugle/c_bugle.mdl"))
		{
			//GiveItem(iClient, 129, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_buff_item", 129, 5);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Pyro) // Pyro Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_shotgun.mdl"))
		{
			//GiveItem(iClient, 12, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun", 12, 5, 36, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_shotgun/c_shotgun.mdl"))
		{
			//GiveItem(iClient, 12, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun", 12, 5, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl"))
		{
			//GiveItem(iClient, 39, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_flaregun", 39, 5, 16);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_detonator/c_detonator.mdl"))
		{
			//GiveItem(iClient, 351, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_flaregun", 351, 5, 16);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl"))
		{
			//GiveItem(iClient, 415, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun", 415, 5, 36, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_degreaser/c_degreaser.mdl"))
		{
			//GiveItem(iClient, 215, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_flamethrower", 215, 5, 100);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_phlogistinator/c_drg_phlogistinator.mdl"))
		{
			//GiveItem(iClient, 594, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_flamethrower", 594, 5, 100);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_flamethrower/c_flamethrower.mdl"))
		{
			//GiveItem(iClient, 21, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_flamethrower", 21, 1, 100);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_manmelter/c_drg_manmelter.mdl"))
		{
			//GiveItem(iClient, 595, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_flaregun_revenge", 595, 5);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_DemoMan) // Demoman Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_grenadelauncher.mdl"))
		{
			//GiveItem(iClient, 19, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_grenadelauncher", 19, 1, 15, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_scottish_resistance.mdl"))
		{
			//GiveItem(iClient, 130, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			iWeapon = CreateWeapon(iClient, iTarget, "tf_weapon_pipebomblauncher", 130, 5, 24, 0);
			TF2Attrib_SetByDefIndex(iWeapon, 59, 0.5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_lochnload/c_lochnload.mdl"))
		{
			//GiveItem(iClient, 308, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_grenadelauncher", 308, 5, 15, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_stickybomb_launcher.mdl"))
		{
			//GiveItem(iClient, 20, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			iWeapon = CreateWeapon(iClient, iTarget, "tf_weapon_pipebomblauncher", 20, 1, 24, 0);
			TF2Attrib_SetByDefIndex(iWeapon, 59, 0.5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_sticky_jumper.mdl"))
		{
			//GiveItem(iClient, 265, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			iWeapon = CreateWeapon(iClient, iTarget, "tf_weapon_pipebomblauncher", 265, 5, 48, 0);
			TF2Attrib_SetByDefIndex(iWeapon, 59, 0.5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_targe/c_targe.mdl"))
		{
			//GiveItem(iClient, 131, iTarget)
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_persian_shield/c_persian_shield.mdl"))
		{
			//GiveItem(iClient, 406, iTarget)
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Engineer) // Engineer Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_shotgun.mdl"))
		{
			//GiveItem(iClient, 9, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun_primary", 9, 1, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_shotgun/c_shotgun.mdl"))
		{
			//GiveItem(iClient, 9, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun_primary", 9, 1, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_dex_shotgun/c_dex_shotgun.mdl"))
		{
			//GiveItem(iClient, 527, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_shotgun_primary", 9, 1, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_ttg_max_gun/c_ttg_max_gun.mdl"))
		{
			//GiveItem(iClient, 160, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_pistol", 160, 1, 60, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_frontierjustice.mdl"))
		{
			//GiveItem(iClient, 141, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_sentry_revenge", 141, 5, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl"))
		{
			//GiveItem(iClient, 141, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_sentry_revenge", 141, 5, 38, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_wrangler.mdl"))
		{
			//GiveItem(iClient, 140, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_laser_pointer", 140, 5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_pistol.mdl"))
		{
			//GiveItem(iClient, 22, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_pistol", 22, 1, 60, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl"))
		{
			//GiveItem(iClient, 588, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_drg_pomson", 588, 5);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Medic) // Medic Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/c_models/c_medigun/c_medigun.mdl"))
		{
			//GiveItem(iClient, 29, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_medigun", 29, 1);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_proto_medigun/c_proto_medigun.mdl"))
		{
			//GiveItem(iClient, 411, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_medigun", 411, 5);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_syringegun/c_syringegun.mdl"))
		{
			//GiveItem(iClient, 17, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_syringegun_medic", 17, 1, 190, 0);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_syringegun.mdl"))
		{
			//GiveItem(iClient, 17, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_syringegun_medic", 17, 1, 190, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_proto_syringegun/c_proto_syringegun.mdl"))
		{
			//GiveItem(iClient, 412, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_syringegun_medic", 412, 5, 190, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_crusaders_crossbow/c_crusaders_crossbow.mdl"))
		{
			//GiveItem(iClient, 305, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_crossbow", 305, 5, 31, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_leechgun/c_leechgun.mdl"))
		{
			//GiveItem(iClient, 36, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_syringegun_medic", 36, 5, 190, 0);
		}
	}
	else if(TF2_GetPlayerClass(iClient) == TFClass_Sniper) // Sniper Only Weapons
	{
		if(StrEqual(strModel, "models/weapons/w_models/w_sniperrifle.mdl"))
		{
			//GiveItem(iClient, 14, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_sniperrife", 14, 1, 25);
		}
		else if(StrEqual(strModel, "models/weapons/w_models/w_smg.mdl"))
		{
			//GiveItem(iClient, 16, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_smg", 16, 1, 100, 0);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_dartgun.mdl"))
		{
			//GiveItem(iClient, 230, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_sniperrifle", 230, 5, 25);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bazaar_sniper/c_bazaar_sniper.mdl"))
		{
			//GiveItem(iClient, 402, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_sniperrifle", 402, 5, 25);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_dex_sniperrifle/c_dex_sniperrifle.mdl"))
		{
			//GiveItem(iClient, 526, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_sniperrifle", 526, 5, 25);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/urinejar.mdl"))
		{
			//GiveItem(iClient, 58, iTarget)
			TF2_RemoveWeaponSlot(iClient, 1);
			CreateWeapon(iClient, iTarget, "tf_weapon_jar", 58, 5, 1);
		}
		else if(StrEqual(strModel, "models/weapons/c_models/c_bow/c_bow.mdl"))
		{
			//GiveItem(iClient, 56, iTarget)
			TF2_RemoveWeaponSlot(iClient, 0);
			CreateWeapon(iClient, iTarget, "tf_weapon_compound_bow", 56, 5, 13, 0);
		}
	}
	return true;
}

CreateWeapon(int client, int target, char[] classname, int itemindex, int level=-1, int ammo=-1, int clip=-1)	// Modified from luki1412's GiveBotsWeapons
{
	AcceptEntityInput(target, "Kill");
	int weapon = CreateEntityByName(classname);
	
	if(!IsValidEntity(weapon))
	{
		return -1;
	}
	
	char entclass[64];
	GetEntityNetClass(weapon, entclass, sizeof(entclass));
	SetEntData(weapon, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);	 
	SetEntData(weapon, FindSendPropInfo(entclass, "m_bInitialized"), 1);

	if(level<1)
	{
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), GetRandomInt(1, 100));
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityQuality"), 6);
	}
	else if(level==1)
	{
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityQuality"), 0);
	}
	else
	{
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
		SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityQuality"), 6);
	}
	
	DispatchSpawn(weapon);
	SDKCall(g_hWeaponEquip, client, weapon);
	SetAmmo(client, weapon, ammo, clip);

	ClientCommand(client, "playgamesound ui/item_heavy_gun_pickup.wav");
	ClientCommand(client, "playgamesound ui/item_heavy_gun_drop.wav");

	if(szf_cvRemoveWeapon)
	{
		AcceptEntityInput(target, "Kill");
	}
	return weapon;
}

stock SetAmmo(client, weapon, ammo=-1, clip=-1)
{
	if(IsValidEntity(weapon))
	{
		if(clip>-1)
		{
			SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
		}

		new ammoType=(ammo>-1 ? GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") : -1);
		if(ammoType!=-1)
		{
			SetEntProp(client, Prop_Data, "m_iAmmo", ammo, _, ammoType);
		}
		else if(ammo>-1)  //Only complain if we're trying to set ammo
		{
			decl String:classname[64];
			GetEdictClassname(weapon, classname, sizeof(classname));
			LogError("[SZF] Cannot give ammo to weapon %s!", classname);
		}
	}
}

GetModelPath(iIndex, String:strModel[], iMaxSize)
{
	new iTable = FindStringTable("modelprecache");
	ReadStringTable(iTable, iIndex, strModel, iMaxSize);
}

GetEntityModel(iEntity, String:strModel[], iMaxSize, String:strPropName[] = "m_nModelIndex")
{
	//m_iWorldModelIndex
	new iIndex = GetEntProp(iEntity, Prop_Send, strPropName);
	GetModelPath(iIndex, strModel, iMaxSize);
}

GetPlayerWeaponSlot2(iClient, iSlot)
{
	new iEntity = GetPlayerWeaponSlot(iClient, iSlot);
	if(iEntity > 0 && IsValidEdict(iEntity)) return iEntity;
	
	if(iSlot == 1)
	{
		iEntity = -1;
		while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_demoshield")) != -1)
		{
			if(IsClassname(iEntity, "tf_wearable_demoshield") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient) return iEntity;
		}
	}
	
	return -1;
}

CheckStartWeapons()
{
	new iClassesWithoutWeapons[10] = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(validLivingSur(i) && !DoesPlayerHaveRealWeapon(i))
		{
			new TFClassType:iClass = TF2_GetPlayerClass(i);
			iClassesWithoutWeapons[iClass]++;
			//PrintToChat(i, "You do not have a real weapon");
		}
	}
	
	decl String:strModel[PLATFORM_MAX_PATH];

	new iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "prop_dynamic")) != -1)
	{
		if(IsClassname(iEntity, "prop_dynamic") && GetWeaponType(iEntity) == 1)
		{
			GetEntityModel(iEntity, strModel, sizeof(strModel));
			new TFClassWeapon:iClass = GetWeaponClass(strModel);
			
			new Handle:hArray = CreateArray();
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
			
			
			new bool:bEnable = false;
			for (new i = 0; i < GetArraySize(hArray); i++)
			{
				new iClass2 = GetArrayCell(hArray, i);
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
	}
}

GetWeaponType(iEntity)
{
	decl String:strName[255];
	GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));
	if(StrEqual(strName, "szf_weapons_intro", false)) return 1;
	
	return 0;
}

TFClassWeapon:GetWeaponClass(String:strModel[])
{	
	new Handle:hWeapon = INVALID_HANDLE;
	new iSlot = -1;
	new iSwitchSlot = -1;
	new bool:bWearable = false;
	decl String:strName[255];
	
	new TFClassWeapon:iWeaponClass = GetWeaponInfoFromModel(strModel, iSlot, iSwitchSlot, hWeapon, bWearable, strName, sizeof(strName));
	
	return iWeaponClass;
}

bool:DoesPlayerHaveRealWeapon(iClient)
{
	new iEntity = GetPlayerWeaponSlot(iClient, 0);
	if(iEntity > 0 && IsValidEdict(iEntity)) return true;
	iEntity = GetPlayerWeaponSlot(iClient, 1);
	if(iEntity > 0 && IsValidEdict(iEntity)) return true;
	
	return false;
}

bool:AttemptCarryItem(iClient)
{
	if(DropCarryingItem(iClient))
		return true;

	new iTarget = GetClientPointVisible(iClient);
	
	new String:strClassname[255];
	if(iTarget > 0)
		GetEdictClassname(iTarget, strClassname, sizeof(strClassname));
	if(iTarget <= 0 || !IsClassname(iTarget, "prop_physics"))
		return false;
	
	decl String:strName[255];
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

UpdateClientCarrying(iClient)
{
	new iTarget = g_iCarryingItem[iClient];
	
	//PrintCenterText(iClient, "Teleporting gas can (%d)", iTarget);
	
	if(iTarget <= 0) return;
	if(!IsClassname(iTarget, "prop_physics"))
	{
		DropCarryingItem(iClient);
		return;
	}
	
	//PrintCenterText(iClient, "Teleporting gas can 1");
	
	decl String:strName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", strName, sizeof(strName));
	if(!StrEqual(strName, "gascan", false)) return;
	
	decl Float:vOrigin[3], Float:vAngles[3], Float:vDistance[3];
	new Float:vEmpty[3];
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

bool:DropCarryingItem(iClient, bool:bDrop = true)
{
	new iTarget = g_iCarryingItem[iClient];
	if(iTarget <= 0) return false;
	
	g_iCarryingItem[iClient] = -1;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 1);
	
	if(!IsClassname(iTarget, "prop_physics")) return true;
	
	//PrintToChat(iClient, "Dropped gas can");
	//SetEntProp(iTarget, Prop_Send, "m_nSolidType", 6);
	AcceptEntityInput(iTarget, "EnableMotion");
   
	if(bDrop && (IsEntityStuck(iTarget) || ObstancleBetweenEntities(iClient, iTarget)))
	{
		decl Float:vOrigin[3];
		GetClientEyePosition(iClient, vOrigin);
		TeleportEntity(iTarget, vOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	return true;
}

stock AnglesToVelocity(Float:fAngle[3], Float:fVelocity[3], Float:fSpeed = 1.0)
{
	fVelocity[0] = Cosine(DegToRad(fAngle[1]));
	fVelocity[1] = Sine(DegToRad(fAngle[1]));
	fVelocity[2] = Sine(DegToRad(fAngle[0])) * -1.0;
	
	NormalizeVector(fVelocity, fVelocity);
	
	ScaleVector(fVelocity, fSpeed);
}

stock bool:IsEntityStuck(iEntity)
{
	decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];
	
	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceDontHitEntity, iEntity);
	return (TR_DidHit());
}
