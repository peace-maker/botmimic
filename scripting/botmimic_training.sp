#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <botmimic>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"

ConVar g_hCVShowDamage;
ConVar g_hCVPlayHitSound;

public Plugin myinfo = 
{
	name = "Bot Mimic Training",
	author = "Jannik \"Peace-Maker\" Hartung",
	description = "Plays sounds if you hit a mimicing bot",
	version = PLUGIN_VERSION,
	url = "http://www.wcfan.de/"
}

public void OnPluginStart()
{
	g_hCVShowDamage = CreateConVar("sm_botmimic_showdamage", "1", "Show damage when hitting a mimicing bot?", _, true, 0.0, true, 1.0);
	g_hCVPlayHitSound = CreateConVar("sm_botmimic_playhitsound", "1", "Play a sound when hitting a mimicing bot?", _, true, 0.0, true, 1.0);
	
	HookEvent("player_hurt", Event_OnPlayerHurt);
}

public void OnMapStart()
{
	PrecacheSound("ui/achievement_earned.wav", true);
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client)
		return;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!attacker)
		return;
	
	if(BotMimic_IsPlayerMimicing(client))
	{
		// Show the hitgroup he's been hit and the damage done.
		if(g_hCVShowDamage.BoolValue)
		{
			int iHitGroup = event.GetInt("hitgroup");
			char sHitGroup[64];
			switch(iHitGroup)
			{
				case 0:
					Format(sHitGroup, sizeof(sHitGroup), "Body");
				case 1:
					Format(sHitGroup, sizeof(sHitGroup), "Head");
				case 2:
					Format(sHitGroup, sizeof(sHitGroup), "Bosom");
				case 3:
					Format(sHitGroup, sizeof(sHitGroup), "Belly");
				case 4:
					Format(sHitGroup, sizeof(sHitGroup), "L Hand");
				case 5:
					Format(sHitGroup, sizeof(sHitGroup), "R Hand");
				case 6:
					Format(sHitGroup, sizeof(sHitGroup), "L Foot");
				case 7:
					Format(sHitGroup, sizeof(sHitGroup), "R Foot");
			}
			
			PrintCenterText(attacker, "%s : %d", sHitGroup, event.GetInt("dmg_health") + event.GetInt("dmg_armor"));
		}
		
		if(g_hCVPlayHitSound.BoolValue)
			EmitSoundToClient(attacker, "ui/achievement_earned.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_ROCKET);
	}
}
