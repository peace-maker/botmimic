/**
 * Bot Mimic - Record your movments and have bots playing it back.
 * Admin menu integration and menu interface.
 * by Peace-Maker
 * visit http://wcfan.de
 * 
 * Changelog:
 * 1.0   - 22.07.2013: Released rewrite
 * 1.1   - 02.10.2014: Added sm_savebookmark and bookmark integration and pausing/resuming while recording.
 */

#pragma semicolon 1
#include <sourcemod>
#include <cstrike>
#include <botmimic>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

#define PLUGIN_VERSION "1.1"

// This player just stopped recording. Show him the details edit menu when the record was saved.
bool g_bPlayerRecordingFromMenu[MAXPLAYERS+1];
bool g_bPlayerStoppedRecording[MAXPLAYERS+1];

char g_sPlayerSelectedCategory[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sPlayerSelectedRecord[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sPlayerSelectedBookmark[MAXPLAYERS+1][MAX_BOOKMARK_NAME_LENGTH];
char g_sNextBotMimicsThis[PLATFORM_MAX_PATH];
char g_sSupposedToMimic[MAXPLAYERS+1][PLATFORM_MAX_PATH];
bool g_bRenameRecord[MAXPLAYERS+1];
bool g_bEnterCategoryName[MAXPLAYERS+1];

// Admin Menu
TopMenu g_hAdminMenu;

public Plugin myinfo = 
{
	name = "Bot Mimic Menu",
	author = "Jannik \"Peace-Maker\" Hartung",
	description = "Handle records and record own movements",
	version = PLUGIN_VERSION,
	url = "http://www.wcfan.de/"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_mimic", Cmd_Record, ADMFLAG_CONFIG, "Opens the bot mimic menu", "botmimic");
	RegAdminCmd("sm_stoprecord", Cmd_StopRecord, ADMFLAG_CONFIG, "Stops your current record", "botmimic");
	RegAdminCmd("sm_savebookmark", Cmd_SaveBookmark, ADMFLAG_CONFIG, "Saves a bookmark with the given name in the record the target records. sm_savebookmark <name|steamid|#userid> <bookmark name>", "botmimic");
	
	AddCommandListener(CmdLstnr_Say, "say");
	AddCommandListener(CmdLstnr_Say, "say_team");
	
	LoadTranslations("common.phrases");
	
	if(LibraryExists("adminmenu"))
	{
		TopMenu hTopMenu = GetAdminTopMenu();
		if(hTopMenu != null)
			OnAdminMenuReady(hTopMenu);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "adminmenu"))
		g_hAdminMenu = null;
}

/**
 * Public forwards
 */
public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if(IsFakeClient(client) && g_sNextBotMimicsThis[0] != '\0')
	{
		strcopy(g_sSupposedToMimic[client], sizeof(g_sSupposedToMimic[]), g_sNextBotMimicsThis);
		g_sNextBotMimicsThis[0] = '\0';
	}
	
	return true;
}

public void OnClientPutInServer(int client)
{
	if(g_sSupposedToMimic[client][0] != '\0')
	{
		BotMimic_PlayRecordFromFile(client, g_sSupposedToMimic[client]);
	}
}

public void OnClientDisconnect(int client)
{
	g_sPlayerSelectedCategory[client][0] = '\0';
	g_sPlayerSelectedRecord[client][0] = '\0';
	g_sPlayerSelectedBookmark[client][0] = '\0';
	g_sSupposedToMimic[client][0] = '\0';
	g_bRenameRecord[client] = false;
	g_bEnterCategoryName[client] = false;
	g_bPlayerStoppedRecording[client] = false;
	g_bPlayerRecordingFromMenu[client] = false;
}

/**
 * Command callbacks
 */
public Action Cmd_Record(int client, int args)
{
	if(!client)
		return Plugin_Handled;
	
	if(BotMimic_IsPlayerRecording(client))
	{
		PrintToChat(client, "[BotMimic] You're currently recording! Stop the current take first.");
		DisplayRecordInProgressMenu(client);
		return Plugin_Handled;
	}
	
	DisplayCategoryMenu(client);
	return Plugin_Handled;
}

public Action Cmd_StopRecord(int client, int args)
{
	if(!client)
		return Plugin_Handled;
	
	if(!BotMimic_IsPlayerRecording(client))
	{
		PrintToChat(client, "[BotMimic] You aren't recording.");
		DisplayCategoryMenu(client);
		return Plugin_Handled;
	}
	
	BotMimic_StopRecording(client, true);
	
	return Plugin_Handled;
}

public Action Cmd_SaveBookmark(int client, int args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "[BotMimic] Saves a bookmark with the given name in the record the target records. sm_savebookmark <name|steamid|#userid> <bookmark name>");
		return Plugin_Handled;
	}
	
	char sTarget[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int iTarget = FindTarget(client, sTarget, false, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(!BotMimic_IsPlayerRecording(iTarget))
	{
		ReplyToCommand(client, "[BotMimic] Target %N is not recording.", iTarget);
		return Plugin_Handled;
	}
	
	char sBookmarkName[MAX_BOOKMARK_NAME_LENGTH];
	GetCmdArg(2, sBookmarkName, sizeof(sBookmarkName));
	TrimString(sBookmarkName);
	StripQuotes(sBookmarkName);
	
	if(strlen(sBookmarkName) == 0)
	{
		ReplyToCommand(client, "[BotMimic] You have to give a name for the bookmark.");
		return Plugin_Handled;
	}
	
	BotMimic_SaveBookmark(iTarget, sBookmarkName);
	
	ReplyToCommand(client, "[BotMimic] Saved bookmark \"%s\" in %N's record.", sBookmarkName, iTarget);
	
	return Plugin_Handled;
}

public Action CmdLstnr_Say(int client, const char[] command, int argc)
{
	char sText[256];
	GetCmdArgString(sText, sizeof(sText));
	StripQuotes(sText);

	if(g_bRenameRecord[client])
	{
		g_bRenameRecord[client] = false;
		
		if(StrEqual(sText, "!stop", false))
		{
			PrintToChat(client, "[BotMimic] Renaming aborted.");
			DisplayRecordDetailMenu(client);
			return Plugin_Handled;
		}
		
		if(g_sPlayerSelectedRecord[client][0] == '\0')
		{
			if(g_sPlayerSelectedCategory[client][0] == '\0')
				DisplayCategoryMenu(client);
			else
				DisplayRecordMenu(client);
			PrintToChat(client, "[BotMimic] You didn't target a record to rename.");
			return Plugin_Handled;
		}
		
		BMError error= BotMimic_ChangeRecordName(g_sPlayerSelectedRecord[client], sText);
		if(error != BM_NoError)
		{
			char sError[64];
			BotMimic_GetErrorString(error, sError, sizeof(sError));
			PrintToChat(client, "[BotMimic] There was an error changing the name: %s", sError);
			return Plugin_Handled;
		}
		
		DisplayRecordDetailMenu(client);
		
		PrintToChat(client, "[BotMimic] Record was renamed to \"%s\".", sText);
		return Plugin_Handled;
	}
	else if(g_bEnterCategoryName[client])
	{
		g_bEnterCategoryName[client] = false;
		
		if(StrEqual(sText, "!stop", false))
		{
			PrintToChat(client, "[BotMimic] Creation of category aborted.");
			DisplayCategoryMenu(client);
			return Plugin_Handled;
		}
		
		ArrayList hCategoryList = BotMimic_GetLoadedRecordCategoryList();
		hCategoryList.PushString(sText);
		
		//TODO: SortRecordList();
		strcopy(g_sPlayerSelectedCategory[client], sizeof(g_sPlayerSelectedCategory[]), sText);
		DisplayRecordMenu(client);
		PrintToChat(client, "[BotMimic] A new category was created named \"%s\".", sText);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

/**
 * Bot Mimic Callbacks
 */
public void BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file)
{
	if(g_bPlayerStoppedRecording[client])
	{
		g_bPlayerStoppedRecording[client] = false;
		strcopy(g_sPlayerSelectedRecord[client], PLATFORM_MAX_PATH, file);
		strcopy(g_sPlayerSelectedCategory[client], sizeof(g_sPlayerSelectedCategory[]), category);
		DisplayRecordDetailMenu(client);
	}
}

public void BotMimic_OnRecordDeleted(char[] name, char[] category, char[] path)
{
	for(int i=1;i<=MaxClients;i++)
	{
		if(StrEqual(g_sPlayerSelectedRecord[i], path))
		{
			g_sPlayerSelectedRecord[i][0] = '\0';
			DisplayRecordMenu(i);
		}
	}
	
	if(StrEqual(g_sNextBotMimicsThis, path))
		g_sNextBotMimicsThis[0] = '\0';
}

public Action BotMimic_OnStopRecording(int client, char[] name, char[] category, char[] subdir, char[] path, bool &save)
{
	// That's nothing we started.
	if(!g_bPlayerRecordingFromMenu[client])
		return Plugin_Continue;
	
	g_bPlayerRecordingFromMenu[client] = false;
	PrintHintText(client, "Stopped recording");
	return Plugin_Continue;
}

/**
 * Menu creation and handling
 */

void DisplayCategoryMenu(int client)
{
	g_bRenameRecord[client] = false;
	g_bEnterCategoryName[client] = false;
	g_sPlayerSelectedCategory[client][0] = '\0';
	g_sPlayerSelectedRecord[client][0] = '\0';
	
	Menu hMenu = new Menu(Menu_SelectCategory);
	hMenu.SetTitle("Manage Movement Recording Categories");
	if(g_hAdminMenu)
		hMenu.ExitBackButton = true;
	else
		hMenu.ExitButton = true;
	
	hMenu.AddItem("record", "Record new movement");
	hMenu.AddItem("createcategory", "Create new category");
	hMenu.AddItem("", "", ITEMDRAW_SPACER);
	
	ArrayList hCategoryList = BotMimic_GetLoadedRecordCategoryList();
	int iSize = hCategoryList.Length;
	char sCategory[64];
	for(int i=0;i<iSize;i++)
	{
		hCategoryList.GetString(i, sCategory, sizeof(sCategory));
		
		hMenu.AddItem(sCategory, sCategory);
	}
	
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_SelectCategory(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[PLATFORM_MAX_PATH];
		menu.GetItem(param2, info, sizeof(info));
		
		// He want's to start a new record
		if(StrEqual(info, "record"))
		{
			if(BotMimic_IsPlayerRecording(param1))
			{
				PrintToChat(param1, "[BotMimic] You're currently recording! Stop the current take first.");
				DisplayRecordInProgressMenu(param1);
				return;
			}
			
			if(!IsPlayerAlive(param1) || GetClientTeam(param1) < CS_TEAM_T)
			{
				PrintToChat(param1, "[BotMimic] You have to be alive to record your movements.");
				DisplayCategoryMenu(param1);
				return;
			}
			
			if(BotMimic_IsPlayerMimicing(param1))
			{
				PrintToChat(param1, "[BotMimic] You're currently mimicing another record. Stop that first before recording.");
				RedisplayAdminMenu(g_hAdminMenu, param1);
				return;
			}
			
			char sTempName[MAX_RECORD_NAME_LENGTH];
			Format(sTempName, sizeof(sTempName), "%d_%d", GetTime(), param1);
			g_bPlayerRecordingFromMenu[param1] = true;
			BotMimic_StartRecording(param1, sTempName, DEFAULT_CATEGORY);
			DisplayRecordInProgressMenu(param1);
		}
		else if(StrEqual(info, "createcategory"))
		{
			g_bEnterCategoryName[param1] = true;
			PrintToChat(param1, "[BotMimic] Type the name of the category in chat or \"!stop\" to abort. Remember that this is used as a folder name too!");
		}
		else
		{
			strcopy(g_sPlayerSelectedCategory[param1], sizeof(g_sPlayerSelectedCategory[]), info);
			DisplayRecordMenu(param1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			RedisplayAdminMenu(g_hAdminMenu, param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void DisplayRecordMenu(int client)
{
	g_sPlayerSelectedRecord[client][0] = '\0';
	
	// We don't have a category selected? Show the correct menu!
	// This is to go back to the correct menu when discarding a record in the progress menu.
	if(g_sPlayerSelectedCategory[client][0] == '\0')
	{
		DisplayCategoryMenu(client);
		return;
	}
	
	Menu hMenu = new Menu(Menu_SelectRecord);
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "Manage Recordings in %s", g_sPlayerSelectedCategory[client]);
	hMenu.SetTitle(sTitle);
	hMenu.ExitBackButton = true;
	
	hMenu.AddItem("record", "Record new movement");
	hMenu.AddItem("", "", ITEMDRAW_SPACER);
	
	ArrayList hRecordList = BotMimic_GetLoadedRecordList();
	
	int iSize = hRecordList.Length;
	char sPath[PLATFORM_MAX_PATH], sBuffer[MAX_RECORD_NAME_LENGTH+24], sCategory[64];
	int iFileHeader[BMFileHeader], iPlaying;
	for(int i=0;i<iSize;i++)
	{
		hRecordList.GetString(i, sPath, sizeof(sPath));
		
		// Only show records from the selected category
		BotMimic_GetFileCategory(sPath, sCategory, sizeof(sCategory));
		if(!StrEqual(g_sPlayerSelectedCategory[client], sCategory))
			continue;
		
		BotMimic_GetFileHeaders(sPath, iFileHeader);
		
		// How many bots are currently playing this record?
		iPlaying = 0;
		char sPlayerPath[PLATFORM_MAX_PATH];
		for(int c=1;c<=MaxClients;c++)
		{
			if(IsClientInGame(c) && BotMimic_IsPlayerMimicing(c))
			{
				BotMimic_GetRecordPlayerMimics(c, sPlayerPath, sizeof(sPlayerPath));
				if(StrEqual(sPath, sPlayerPath))
					iPlaying++;
			}
		}
		
		if(iPlaying > 0)
			Format(sBuffer, sizeof(sBuffer), "%s (Playing %dx)", iFileHeader[BMFH_recordName], iPlaying);
		else
			Format(sBuffer, sizeof(sBuffer), "%s", iFileHeader[BMFH_recordName]);
		
		hMenu.AddItem(sPath, sBuffer);
	}
	
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_SelectRecord(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[PLATFORM_MAX_PATH];
		menu.GetItem(param2, info, sizeof(info));
		
		// He want's to start a new record
		if(StrEqual(info, "record"))
		{
			if(BotMimic_IsPlayerRecording(param1))
			{
				PrintToChat(param1, "[BotMimic] You're currently recording! Stop the current take first.");
				DisplayRecordInProgressMenu(param1);
				return;
			}
			
			if(!IsPlayerAlive(param1) || GetClientTeam(param1) < CS_TEAM_T)
			{
				PrintToChat(param1, "[BotMimic] You have to be alive to record your movements.");
				DisplayRecordMenu(param1);
				return;
			}
			
			if(BotMimic_IsPlayerMimicing(param1))
			{
				PrintToChat(param1, "[BotMimic] You're currently mimicing another record. Stop that first before recording.");
				RedisplayAdminMenu(g_hAdminMenu, param1);
				return;
			}
			
			char sTempName[MAX_RECORD_NAME_LENGTH];
			Format(sTempName, sizeof(sTempName), "%d_%d", GetTime(), param1);
			g_bPlayerRecordingFromMenu[param1] = true;
			BotMimic_StartRecording(param1, sTempName, g_sPlayerSelectedCategory[param1]);
			DisplayRecordInProgressMenu(param1);
		}
		else
		{
			strcopy(g_sPlayerSelectedRecord[param1], PLATFORM_MAX_PATH, info);
			DisplayRecordDetailMenu(param1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		g_sPlayerSelectedCategory[param1][0] = '\0';
		if(param2 == MenuCancel_ExitBack)
			DisplayCategoryMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void DisplayRecordDetailMenu(int client)
{
	if(g_sPlayerSelectedRecord[client][0] == '\0' || !FileExists(g_sPlayerSelectedRecord[client]))
	{
		g_sPlayerSelectedRecord[client][0] = '\0';
		DisplayRecordMenu(client);
		return;
	}
	
	int iFileHeader[BMFileHeader];
	if(BotMimic_GetFileHeaders(g_sPlayerSelectedRecord[client], iFileHeader) != BM_NoError)
	{
		g_sPlayerSelectedRecord[client][0] = '\0';
		DisplayRecordMenu(client);
		return;
	}
	
	Menu hMenu = new Menu(Menu_HandleRecordDetails);
	hMenu.SetTitle("Record \"%s\": Details", iFileHeader[BMFH_recordName]);
	hMenu.ExitBackButton = true;
	
	hMenu.AddItem("playselect", "Select a bot to mimic");
	hMenu.AddItem("playadd", "Add a bot to mimic");
	hMenu.AddItem("stop", "Stop any bots mimicing this record");
	hMenu.AddItem("bookmarks", "Display bookmarks", iFileHeader[BMFH_bookmarkCount]>0?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	hMenu.AddItem("rename", "Rename this record");
	hMenu.AddItem("delete", "Delete");
	
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "Length: %d ticks", iFileHeader[BMFH_tickCount]);
	hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
	FormatTime(sBuffer, sizeof(sBuffer), "Recorded: %c", iFileHeader[BMFH_recordEndTime]);
	hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
	
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_HandleRecordDetails(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_sPlayerSelectedRecord[param1][0] == '\0' || !FileExists(g_sPlayerSelectedRecord[param1]))
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		int iFileHeader[BMFileHeader];
		if(BotMimic_GetFileHeaders(g_sPlayerSelectedRecord[param1], iFileHeader) != BM_NoError)
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		// Select a present bot
		if(StrEqual(info, "playselect"))
		{
			// Build up a menu with bots
			Menu hMenu = new Menu(Menu_SelectBotToMimic);
			hMenu.SetTitle("Which bot should mimic this record?");
			hMenu.ExitBackButton = true;
			
			char sUserId[6], sBuffer[MAX_NAME_LENGTH*2];
			char sPath[PLATFORM_MAX_PATH];
			for(int i=1;i<=MaxClients;i++)
			{
				if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) >= CS_TEAM_T && !IsClientSourceTV(i) && !IsClientReplay(i))
				{
					IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
					Format(sBuffer, sizeof(sBuffer), "%N", i);
					
					if(GetClientTeam(i) == CS_TEAM_T)
						Format(sBuffer, sizeof(sBuffer), "%s [T]", sBuffer);
					else
						Format(sBuffer, sizeof(sBuffer), "%s [CT]", sBuffer);
					
					if(BotMimic_IsPlayerMimicing(i))
					{
						BotMimic_GetRecordPlayerMimics(i, sPath, sizeof(sPath));
						BotMimic_GetFileHeaders(sPath, iFileHeader);
						Format(sBuffer, sizeof(sBuffer), "%s (Plays %s)", sBuffer, iFileHeader[BMFH_recordName]);
					}
					hMenu.AddItem(sUserId, sBuffer);
				}
			}
			
			// Only show the player list, if there is a bot on the server
			if(GetMenuItemCount(hMenu) > 0)
				hMenu.Display(param1, MENU_TIME_FOREVER);
			else
				DisplayRecordDetailMenu(param1);
		}
		// Add a new bot just for this purpose.
		else if(StrEqual(info, "playadd"))
		{
			Menu hMenu = new Menu(Menu_SelectBotTeam);
			hMenu.SetTitle("Select the team for the new bot");
			hMenu.ExitBackButton = true;
			
			hMenu.AddItem("t", "Terrorist");
			hMenu.AddItem("ct", "Counter-Terrorist");
			
			hMenu.Display(param1, MENU_TIME_FOREVER);
		}
		// Stop all bots playing this record
		else if(StrEqual(info, "stop"))
		{
			int iCount;
			char sPath[PLATFORM_MAX_PATH];
			for(int i=1;i<=MaxClients;i++)
			{
				if(IsClientInGame(i) && BotMimic_IsPlayerMimicing(i))
				{
					BotMimic_GetRecordPlayerMimics(i, sPath, sizeof(sPath));
					if(StrEqual(sPath, g_sPlayerSelectedRecord[param1]))
					{
						BotMimic_StopPlayerMimic(i);
						iCount++;
					}
				}
			}
			
			PrintToChat(param1, "[BotMimic] Stopped %d bots from mimicing record \"%s\".", iCount, iFileHeader[BMFH_recordName]);
			DisplayRecordDetailMenu(param1);
		}
		else if(StrEqual(info, "bookmarks"))
		{
			DisplayBookmarkListMenu(param1);
		}
		else if(StrEqual(info, "rename"))
		{
			g_bRenameRecord[param1] = true;
			PrintToChat(param1, "[BotMimic] Type the new name for record \"%s\" or type \"!stop\" to cancel.", iFileHeader[BMFH_recordName]);
		}
		else if(StrEqual(info, "delete"))
		{
			int iCount = BotMimic_DeleteRecord(g_sPlayerSelectedRecord[param1]);
			
			PrintToChat(param1, "[BotMimic] Stopped %d bots and deleted record \"%s\".", iCount, iFileHeader[BMFH_recordName]);
			
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		g_sPlayerSelectedRecord[param1][0] = '\0';
		if(param2 == MenuCancel_ExitBack)
			DisplayRecordMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_SelectBotToMimic(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_sPlayerSelectedRecord[param1][0] == '\0' || !FileExists(g_sPlayerSelectedRecord[param1]))
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		int iFileHeader[BMFileHeader];
		if(BotMimic_GetFileHeaders(g_sPlayerSelectedRecord[param1], iFileHeader) != BM_NoError)
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		int userid = StringToInt(info);
		int iBot = GetClientOfUserId(userid);
		
		if(!iBot || !IsClientInGame(iBot) || GetClientTeam(iBot) < CS_TEAM_T)
		{
			PrintToChat(param1, "[BotMimic] The bot you selected can't be found anymore.");
			DisplayRecordDetailMenu(param1);
			return;
		}
		
		char sPath[PLATFORM_MAX_PATH];
		if(BotMimic_IsPlayerMimicing(iBot))
		{
			BotMimic_GetRecordPlayerMimics(iBot, sPath, sizeof(sPath));
			// That bot already plays this record. stop that.
			if(StrEqual(sPath, g_sPlayerSelectedRecord[param1]))
			{
				BotMimic_StopPlayerMimic(iBot);
				PrintToChat(param1, "[BotMimic] %N stopped mimicing record \"%s\".", iBot, iFileHeader[BMFH_recordName]);
			}
			// He's been playing a different record, switch to the selected.
			else
			{
				BotMimic_StopPlayerMimic(iBot);
				BotMimic_PlayRecordFromFile(iBot, g_sPlayerSelectedRecord[param1]);
				PrintToChat(param1, "[BotMimic] %N started mimicing record \"%s\".", iBot, iFileHeader[BMFH_recordName]);
			}
		}
		else
		{
			BotMimic_PlayRecordFromFile(iBot, g_sPlayerSelectedRecord[param1]);
			PrintToChat(param1, "[BotMimic] %N started mimicing record \"%s\".", iBot, iFileHeader[BMFH_recordName]);
		}
		
		DisplayRecordDetailMenu(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			DisplayRecordDetailMenu(param1);
		else
			g_sPlayerSelectedRecord[param1][0] = '\0';
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_SelectBotTeam(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_sPlayerSelectedRecord[param1][0] == '\0' || !FileExists(g_sPlayerSelectedRecord[param1]))
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		int iFileHeader[BMFileHeader];
		if(BotMimic_GetFileHeaders(g_sPlayerSelectedRecord[param1], iFileHeader) != BM_NoError)
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		strcopy(g_sNextBotMimicsThis, sizeof(g_sNextBotMimicsThis), g_sPlayerSelectedRecord[param1]);
		
		if(StrEqual(info, "t"))
		{
			ServerCommand("bot_add_t");
		}
		else
		{
			ServerCommand("bot_add_ct");
		}
		
		PrintToChat(param1, "[BotMimic] Added new bot who mimics record \"%s\".", iFileHeader[BMFH_recordName]);
		
		DisplayRecordDetailMenu(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			DisplayRecordDetailMenu(param1);
		else
			g_sPlayerSelectedRecord[param1][0] = '\0';
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void DisplayBookmarkListMenu(int client)
{
	g_sPlayerSelectedBookmark[client][0]= '\0';
	
	int iFileHeader[BMFileHeader];
	if(BotMimic_GetFileHeaders(g_sPlayerSelectedRecord[client], iFileHeader) != BM_NoError)
	{
		g_sPlayerSelectedRecord[client][0] = '\0';
		DisplayRecordMenu(client);
		return;
	}
	
	Menu hMenu = new Menu(Menu_HandleBookmarkList);
	hMenu.SetTitle("Bookmarks for record \"%s\"", iFileHeader[BMFH_recordName]);
	hMenu.ExitBackButton = true;
	
	ArrayList hBookmarks;
	if(BotMimic_GetRecordBookmarks(g_sPlayerSelectedRecord[client], hBookmarks) != BM_NoError)
	{
		g_sPlayerSelectedRecord[client][0] = '\0';
		DisplayRecordMenu(client);
		return;
	}
	
	int iSize = hBookmarks.Length;
	char sBuffer[MAX_BOOKMARK_NAME_LENGTH];
	for(int i=0;i<iSize;i++)
	{
		hBookmarks.GetString(i, sBuffer, sizeof(sBuffer));
		hMenu.AddItem(sBuffer, sBuffer);
	}
	delete hBookmarks;
	
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_HandleBookmarkList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_sPlayerSelectedRecord[param1][0] == '\0' || !FileExists(g_sPlayerSelectedRecord[param1]))
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		int iFileHeader[BMFileHeader];
		if(BotMimic_GetFileHeaders(g_sPlayerSelectedRecord[param1], iFileHeader) != BM_NoError)
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		char info[MAX_BOOKMARK_NAME_LENGTH];
		menu.GetItem(param2, info, sizeof(info));
		strcopy(g_sPlayerSelectedBookmark[param1], MAX_BOOKMARK_NAME_LENGTH, info);
		
		DisplayBookmarkMimicingPlayers(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			DisplayRecordDetailMenu(param1);
		else
			g_sPlayerSelectedRecord[param1][0] = '\0';
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void DisplayBookmarkMimicingPlayers(int client)
{
	Menu hMenu = new Menu(Menu_HandleBookmarkMimicingPlayer);
	hMenu.SetTitle("Select which player who currently plays the record should jump to bookmark \"%s\":", g_sPlayerSelectedBookmark[client]);
	hMenu.ExitBackButton = true;
	
	char sBuffer[PLATFORM_MAX_PATH], sUserId[16];
	for(int i=1;i<=MaxClients;i++)
	{
		if(!IsClientInGame(i) || !BotMimic_IsPlayerMimicing(i))
			continue;
		
		BotMimic_GetRecordPlayerMimics(i, sBuffer, sizeof(sBuffer));
		if(!StrEqual(sBuffer, g_sPlayerSelectedRecord[client], false))
			continue;
		
		Format(sBuffer, sizeof(sBuffer), "%N (#%d)", i, GetClientUserId(i));
		IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
		hMenu.AddItem(sUserId, sBuffer);
	}
	
	if(GetMenuItemCount(hMenu) == 0)
		hMenu.AddItem("", "No players currently mimicing this record.", ITEMDRAW_DISABLED);
	
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_HandleBookmarkMimicingPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_sPlayerSelectedRecord[param1][0] == '\0' || !FileExists(g_sPlayerSelectedRecord[param1]))
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			g_sPlayerSelectedBookmark[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		if(g_sPlayerSelectedBookmark[param1][0] == '\0')
		{
			DisplayBookmarkListMenu(param1);
			return;
		}
		
		int iFileHeader[BMFileHeader];
		if(BotMimic_GetFileHeaders(g_sPlayerSelectedRecord[param1], iFileHeader) != BM_NoError)
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			g_sPlayerSelectedBookmark[param1][0] = '\0';
			DisplayRecordMenu(param1);
			return;
		}
		
		char info[MAX_BOOKMARK_NAME_LENGTH];
		menu.GetItem(param2, info, sizeof(info));
		
		int userid = StringToInt(info);
		int iTarget = GetClientOfUserId(userid);
		
		if(!iTarget || !IsClientInGame(iTarget) || GetClientTeam(iTarget) < CS_TEAM_T)
		{
			PrintToChat(param1, "[BotMimic] The bot you selected can't be found anymore.");
			DisplayBookmarkMimicingPlayers(param1);
			return;
		}
		
		if(!BotMimic_IsPlayerMimicing(iTarget))
		{
			PrintToChat(param1, "[BotMimic] %N isn't mimicing anything anymore.", iTarget);
			DisplayBookmarkMimicingPlayers(param1);
			return;
		}
		else
		{
			char sRecordPath[PLATFORM_MAX_PATH];
			BotMimic_GetRecordPlayerMimics(iTarget, sRecordPath, sizeof(sRecordPath));
			if(!StrEqual(sRecordPath, g_sPlayerSelectedRecord[param1], false))
			{
				PrintToChat(param1, "[BotMimic] %N isn't mimicing the selected record anymore.", iTarget);
				DisplayBookmarkMimicingPlayers(param1);
				return;
			}
		}
		
		BotMimic_GoToBookmark(iTarget, g_sPlayerSelectedBookmark[param1]);
		DisplayBookmarkMimicingPlayers(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			DisplayBookmarkListMenu(param1);
		else
		{
			g_sPlayerSelectedRecord[param1][0] = '\0';
			g_sPlayerSelectedBookmark[param1][0] = '\0';
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void DisplayRecordInProgressMenu(int client)
{
	if(!BotMimic_IsPlayerRecording(client))
	{
		DisplayRecordMenu(client);
		return;
	}
	
	Menu hMenu = new Menu(Menu_HandleRecordProgress);
	hMenu.SetTitle("Recording...");
	hMenu.ExitButton = false;
	
	if(BotMimic_IsRecordingPaused(client))
		hMenu.AddItem("resume", "Resume recording");
	else
		hMenu.AddItem("pause", "Pause recording");
	hMenu.AddItem("save", "Save recording");
	hMenu.AddItem("discard", "Discard recording");
	
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_HandleRecordProgress(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		// He isn't recording anymore
		if(!BotMimic_IsPlayerRecording(param1))
		{
			DisplayRecordMenu(param1);
			return;
		}
		
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		g_bPlayerRecordingFromMenu[param1] = false;
		if(StrEqual(info, "pause"))
		{
			if(!BotMimic_IsRecordingPaused(param1))
			{
				BotMimic_PauseRecording(param1);
				PrintToChat(param1, "[BotMimic] Paused recording.");
			}
			
			DisplayRecordInProgressMenu(param1);
		}
		else if(StrEqual(info, "resume"))
		{
			if(BotMimic_IsRecordingPaused(param1))
			{
				BotMimic_ResumeRecording(param1);
				PrintToChat(param1, "[BotMimic] Resumed recording.");
			}
			
			DisplayRecordInProgressMenu(param1);
		}
		else if(StrEqual(info, "save"))
		{
			g_bPlayerStoppedRecording[param1] = true;
			BotMimic_StopRecording(param1, true);
		}
		else if(StrEqual(info, "discard"))
		{
			BotMimic_StopRecording(param1, false);
			DisplayRecordMenu(param1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		PrintHintText(param1, "Recording...");
		PrintToChat(param1, "[BotMimic] Type !stoprecord to stop recording.");
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/**
 * Admin Menu Integration
 */
public void OnAdminMenuReady(Handle hndl)
{
	TopMenu topmenu = TopMenu.FromHandle(hndl);
	// Don't add the category twice!
	if(g_hAdminMenu == topmenu)
		return;
	
	g_hAdminMenu = topmenu;
	
	TopMenuObject iBotMimicCategory;
	if((iBotMimicCategory = topmenu.FindCategory("Bot Mimic")) == INVALID_TOPMENUOBJECT)
		iBotMimicCategory = topmenu.AddCategory("Bot Mimic", TopMenu_SelectCategory, "sm_mimic", ADMFLAG_CONFIG);
	
	if(iBotMimicCategory == INVALID_TOPMENUOBJECT)
		return;
	
	topmenu.AddItem("Record new movement", TopMenu_NewRecord, iBotMimicCategory, "sm_mimic", ADMFLAG_CONFIG);
	topmenu.AddItem("List categories", TopMenu_ListCategories, iBotMimicCategory, "sm_mimic", ADMFLAG_CONFIG);
}

public void TopMenu_SelectCategory(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "Bot Mimic");
	}
	else if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Bot Mimic");
	}
}

public void TopMenu_NewRecord(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Record new movement");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		if(!IsPlayerAlive(param) || GetClientTeam(param) < CS_TEAM_T)
		{
			PrintToChat(param, "[BotMimic] You have to be alive to record your movements.");
			RedisplayAdminMenu(topmenu, param);
			return;
		}
		
		if(BotMimic_IsPlayerRecording(param))
		{
			PrintToChat(param, "[BotMimic] You're already recording!");
			RedisplayAdminMenu(topmenu, param);
			return;
		}
		
		if(BotMimic_IsPlayerMimicing(param))
		{
			PrintToChat(param, "[BotMimic] You're currently mimicing another record. Stop that first before recording.");
			RedisplayAdminMenu(topmenu, param);
			return;
		}
		
		char sTempName[MAX_RECORD_NAME_LENGTH];
		Format(sTempName, sizeof(sTempName), "%d_%d", GetTime(), param);
		g_bPlayerRecordingFromMenu[param] = true;
		BotMimic_StartRecording(param, sTempName, DEFAULT_CATEGORY);
		DisplayRecordInProgressMenu(param);
	}
}

public void TopMenu_ListCategories(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "List categories");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		DisplayCategoryMenu(param);
	}
}
