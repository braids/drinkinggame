/* Plugin Template generated by Pawn Studio */

#include <sourcemod>
#include <string>
#include <sdktools>
#include <tf2>
#include <sdkhooks>
#include <tf2_stocks>
#include <adt_trie>

#include "globals.sp"

#include "helpers.sp"
#include "tf2_extra.sp"
// REMOVE Database.sp
// #include "database.sp"
#include "effects.sp"
// REMOVE Taunts.sp
// #include "taunts.sp"
#include "balance.sp"
#include "chug.sp"
#include "drinks.sp"

public Plugin:myinfo =
{
	name = "Drinking game plugin",
	author = "Jesse Young (CodeMonkey) & Lucas Penney (Luke)",
	description = "Sends players with [DG] in their name a message when they should drink",
	version = "3.0.0",
	url = "http://www.team-brh.com"
}

public OnPluginStart()
{
	DG_Globals_Initialize();
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_win",Event_RoundWin);
	HookEvent("object_destroyed",Event_SentryDeath);
	HookEvent("player_spawn",Event_PlayerSpawn);
	HookEvent("player_changename",Event_PlayerChangeName);
	HookEvent("teamplay_round_start",Event_RoundStart);
	RegConsoleCmd("say",Command_Say);
	RegConsoleCmd("dg_drinklist",DG_DrinkListCommand);
	// REMOVE Taunt command
    //RegConsoleCmd("dg_mytaunt",DG_Taunts_MyTauntCommand);
	//RegConsoleCmd("dg_settaunt",DG_Taunts_SetTauntCommand);
	RegConsoleCmd("dg_info",DG_InfoCommand);
    // REMOVE Stats command
    //RegConsoleCmd("dg_stats",DG_StatsCommand);
	RegConsoleCmd("dg_mystats",DG_Drinks_MyStats);
	RegAdminCmd("dg_add_bots", DG_AddBotsCommand, ADMFLAG_GENERIC);
	RegAdminCmd("dg_balance", DG_Balance_CallBalanceCommand, ADMFLAG_GENERIC);
	RegAdminCmd("dg_chuground", DG_Chug_ChugRoundCommand, ADMFLAG_GENERIC);

    // REMOVE Stat URL
	//dgStatsURL = CreateConVar("dg_statsurl", "http://stats.team-brh.com/dg", "Web location where DGers can view their stats");
	dgRulesURL = CreateConVar("dg_rulesurl", "http://www.team-brh.com/forums/viewtopic.php?f=8&t=7666", "Web location where rules are posted for when a player types dg_info in chat");
	dgBottleDeath = CreateConVar("dg_bottledeath", "1", "Spawn bottles based on how many drinks were given on death");
	dgUnfairBalance = CreateConVar("dg_unfairbalance", "1", "Prevent certain heavy medic pairs from being dg-balanced separated");
	dgHolidayMode = CreateConVar("dg_holidaymode", "0", "Drink irresponsibly this holiday season.");
	dgDebug = CreateConVar("dg_debug", "0", "Drinking Game Debug Mode");
	//For findtarget
	LoadTranslations("common.phrases");

    // REMOVE DG DB Connection
	// DG_Database_Connect();
	// DG_Database_LoadWeaponInfo();

    // ADD WEAPON DG INFO LOADING HERE
    
	//Turn on holiday mode if month is december
	new String:date[30];
	FormatTime(date, sizeof(date), "%b");
	SetConVarBool(dgHolidayMode, StrEqual(date, "Dec"));
}

public OnPluginEnd() {
	//Kill all sprites on end
	DG_Effects_KillAllSprites();
}

public OnConfigsExecuted() {
	if (GetConVarBool(dgDebug)) {
		return;
	}
	PrecacheSound("vo/burp05.mp3");
	PrecacheModel("models/props_gameplay/bottle001.mdl",true);
}

public OnMapStart() {
	if (GetConVarBool(dgDebug)) {
		return;
	}
	PrecacheGeneric(DG_SPRITE_RED_VMT, true);
	AddFileToDownloadsTable(DG_SPRITE_RED_VMT);
	PrecacheGeneric(DG_SPRITE_RED_VTF, true);
	AddFileToDownloadsTable(DG_SPRITE_RED_VTF);

	PrecacheGeneric(DG_SPRITE_BLU_VMT, true);
	AddFileToDownloadsTable(DG_SPRITE_BLU_VMT);
	PrecacheGeneric(DG_SPRITE_BLU_VTF, true);
	AddFileToDownloadsTable(DG_SPRITE_BLU_VTF);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	if (DG_Balance_Timer != INVALID_HANDLE) {
		CloseHandle(DG_Balance_Timer);
		DG_Balance_Timer = INVALID_HANDLE;
	}
	DG_Balance_Timer = CreateTimer(5.0,DG_Balance_CallBalance);
}

public Action:Command_Say(client,args) {
	new String:text[200];
	GetCmdArgString(text,sizeof(text));
	StripQuotes(text);
	//Just leave if the console says something
	if (client == 0) {
		return Plugin_Continue;
	}

	new String:forumPost[300];
	GetConVarString(dgRulesURL,forumPost,sizeof(forumPost));

	if (StrContains(text, "dg",false) != -1 || StrContains(text, "dcg",false) != -1
		|| StrContains(text, "sg",false) != -1 || StrContains(text, "scg",false) != -1) {
		if (StrContains(text, "what is",false) != -1)
			ShowMOTDPanel(client,"DG Rules",forumPost,MOTDPANEL_TYPE_URL);
		else if (StrContains(text, "wat is",false) != -1)
			ShowMOTDPanel(client,"DG Rules",forumPost,MOTDPANEL_TYPE_URL);
		else if (StrContains(text, "wtf is",false) != -1)
			ShowMOTDPanel(client,"DG Rules",forumPost,MOTDPANEL_TYPE_URL);
		else if (StrContains(text, "why do you have",false) != -1)
			ShowMOTDPanel(client,"DG Rules",forumPost,MOTDPANEL_TYPE_URL);
		else if (StrContains(text, "how to",false) != -1)
			ShowMOTDPanel(client,"DG Rules",forumPost,MOTDPANEL_TYPE_URL);
		else if (StrContains(text, "how do",false) != -1)
			ShowMOTDPanel(client,"DG Rules",forumPost,MOTDPANEL_TYPE_URL);
	}

	//If they're trying to run a dg command, run it as a client command as if they entered it in console
	if (StrContains(text, "dg_", false) != -1) {
		ClientCommand(client, text);
	}

	return Plugin_Continue;
}

public Action:DG_InfoCommand(int client, args) {
	new String:forumPost[300];
	GetConVarString(dgRulesURL,forumPost,sizeof(forumPost));
	ShowMOTDPanel(client,"DG Rules",forumPost,MOTDPANEL_TYPE_URL);
	return Plugin_Handled;
}

// REMOVE DG Stats command
/*
public Action:DG_StatsCommand(int client, args) {
	new String:text[128];
	GetCmdArgString(text, sizeof(text));
	new String:cmd[32];
	new nextCmd = BreakString(text,cmd,sizeof(cmd));
	new String:blank[255];
	if (nextCmd == -1) {
		ShowDGStats(client, blank);
	}
	else {
		ShowDGStats(client, text[nextCmd]);
	}
}
*/

public Action:DG_DrinkListCommand(int client, args) {
	DG_ReadList(client,0);
	return Plugin_Handled;
}

//is player DG for the purposes of causing drinks
public bool:DG_IsPlayerPlaying(String:playerName[]) {
	if(StrContains(playerName,"[DG]",false) != -1) {
		return true;
	}
	if(StrContains(playerName,"[SG]",false) != -1) {
		return true;
	}
	if(StrContains(playerName,"[DCG]",false) != -1) {
		return true;
	}
	if(StrContains(playerName,"[SCG]",false) != -1) {
		return true;
	}
	return false;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	//Give the player their drinks
	DG_Drinks_GivePlayerDeathDrinks(event, name);

	new bool:buildingDeath = StrEqual(name,"object_destroyed",false);
	if (!buildingDeath) {
		//If it's a player that died, kill their sprite
		new victim_id = GetEventInt(event, "userid")
		new victim = GetClientOfUserId(victim_id);
		DG_Effects_KillSprite(victim);
	}
}

public getDrinkCount(String:name[]) {
	if (GetConVarBool(dgDebug)) {
		return 3;
	}
	//Make sure not to read a bad map
	if (Weapons != INVALID_HANDLE) {
		new wepBonus = 0;
		GetTrieValue(Weapons,name,wepBonus);
		return wepBonus;
	}
	return 0;
}


public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	if (GetConVarBool(dgDebug)) {
		return;
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new String:playerName[32];
	GetClientName(client, playerName,sizeof(playerName));

	//If they are DG'n put a sprite above their heads
	if (DG_IsPlayerPlaying(playerName)) {
		if (GetClientTeam(client) == RED_TEAM) {
			DG_Effects_CreateSprite(client,DG_SPRITE_RED_VMT);
		}
		else {
			DG_Effects_CreateSprite(client,DG_SPRITE_BLU_VMT);
		}
	}
}

public Action:SetTransmit(entity, client) {
	//ATTN: THIS FUNCTION MAY HOLD THE BUG THAT CAUSES DG SPRITE AT SOME TEAMMATES
	//Do not display if it is the clients own sprite
	if (dgSprites[client] == entity) {
		return Plugin_Handled;
	}

	//Find target entities owner
	new playerLookingAt = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if (dgSprites[i] == entity) {
			playerLookingAt = i;
			break;
		}
	}

	//If its a spy disguising or disguised or cloaked don't show it
	if (playerLookingAt > 0) {
		if (GetEntProp(playerLookingAt, Prop_Send, "m_nPlayerCond") & (TF2_PLAYERCOND_DISGUISING|TF2_PLAYERCOND_DISGUISED|TF2_PLAYERCOND_SPYCLOAK))
			return Plugin_Handled;
	}

	//If they are on the same team. Don't show it
	if (playerLookingAt > 0) {
		if (GetClientTeam(client) == GetClientTeam(playerLookingAt)) {
			return Plugin_Handled;
		}
	}

	new String:playerName[32];
	GetClientName(client, playerName,sizeof(playerName));

	//Don't display to non DGers
	if (!DG_IsPlayerPlaying(playerName)) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	//Adjust sprites when players change their name
	decl String:newName[32]; GetEventString(event,"newname" , newName, sizeof(newName));
	decl String:oldName[32]; GetEventString(event,"oldname" , oldName,sizeof(oldName));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new bool:dg    = DG_IsPlayerPlaying(newName);
	new bool:wasDG = DG_IsPlayerPlaying(oldName);

	//If they are dead don't worry about it it will be taken care of at spawn
	if (!IsPlayerAlive(client)) {
		return;
	}

	//Didn't actually leave or join game just leave
	if (dg && wasDG) {
		return;
	}
	//If they have started DGin
	if (dg && !GetConVarBool(dgDebug)) {
		if (GetClientTeam(client) == RED_TEAM)
			DG_Effects_CreateSprite(client,DG_SPRITE_RED_VMT);
		else if (GetClientTeam(client) == BLU_TEAM)
			DG_Effects_CreateSprite(client,DG_SPRITE_BLU_VMT);
	} else if(dgSprites[client] > 0) {
		//If it has a sprite kill it
		DG_Effects_KillSprite(client);
	}
}

public MenuHandler1(Handle:menu, MenuAction:action, param1, param2) {

}

public Event_SentryDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	Event_PlayerDeath(event,name,dontBroadcast);
}

public Event_RoundWin(Handle:event, const String:name[], bool:dontBroadcast) {
	new team = GetEventInt(event,"team")

	//See if there are any drinkers that round
	new bool:drinkers = false;
	for (new i = 1; i <= MaxClients; i++) {
		if (TotalDrinks[i] > 0)
			drinkers = true;
	}

	//Loop through all clients
	for (new i = 1; i <= MaxClients; i++) {
	//Make sure client is connected
		if (!IsClientInGame(i)) {
			continue;
		}

		//Get player Name
		new String:playerName[32];
		GetClientName(i, playerName,sizeof(playerName));


		if (DG_IsPlayerPlaying(playerName)){
			if (!drinkers) {
				PrintToChat(i, "%sNo one even drank that round, get killing you drunks",msgColor);
			}
			//If on losing team
			if (GetClientTeam(i) != team) {
				PrintCenterText(i,"Your team lost! Drink bitch");
			}
		}
		if (DeadRingerDrinks[i] > 0) {
			PrintCenterText(i,"DRINK %d BITCH", DeadRingerDrinks[i]);
			PrintToChat(i,"%sYou were dead ringing you cheeky git %d",msgColor, DeadRingerDrinks[i]);

			new Handle:myPanel = CreatePanel();
			new String:panelBuffer[100];
			if(!GetConVarBool(dgDebug)){
				EmitSoundToClient(i,"vo/burp05.mp3");
			}
			//Display the window
			Format(panelBuffer,sizeof(panelBuffer),"[+%d]You would have drank at time of fake death(s)",DeadRingerDrinks[i]);
			DrawPanelText(myPanel,panelBuffer);
			DrawPanelText(myPanel,"--------------------------------");
			Format(panelBuffer,sizeof(panelBuffer),"Total: %d",DeadRingerDrinks[i]);
			DrawPanelText(myPanel, panelBuffer);
			DrawPanelText(myPanel," ");
			Format(panelBuffer,sizeof(panelBuffer),"Total drinks this round: %d",TotalDrinks[i]);
			DrawPanelText(myPanel,panelBuffer);
			DrawPanelItem(myPanel,"Close");
			SendPanelToClient(myPanel,i,MenuHandler1,5);
			CloseHandle(myPanel);
			DeadRingerDrinks[i] = 0;
		}
		else if (BuildingDrinks[i] > 0) {
			PrintCenterText(i,"DRINK %d BITCH", BuildingDrinks[i]);
			PrintToChat(i,"%sYour buildings were killed last life drink %d",msgColor, BuildingDrinks[i]);

			new Handle:myPanel = CreatePanel();
			new String:panelBuffer[100];
			if(!GetConVarBool(dgDebug)){
				EmitSoundToClient(i,"vo/burp05.mp3");
			}
			//Display the window
			Format(panelBuffer,sizeof(panelBuffer),"[+%d]Your buildings were killed that life",BuildingDrinks[i]);
			DrawPanelText(myPanel,panelBuffer);
			DrawPanelText(myPanel,"--------------------------------");
			Format(panelBuffer,sizeof(panelBuffer),"Total: %d",BuildingDrinks[i]);
			DrawPanelText(myPanel, panelBuffer);
			DrawPanelText(myPanel," ");
			Format(panelBuffer,sizeof(panelBuffer),"Total drinks this round: %d",TotalDrinks[i]);
			DrawPanelText(myPanel,panelBuffer);
			DrawPanelItem(myPanel,"Close");
			SendPanelToClient(myPanel,i,MenuHandler1,5);
			CloseHandle(myPanel);
			BuildingDrinks[i] = 0;
		}
	}

	new String:TopDrinkers[(MAXPLAYERS + 1)*(66)];
	DG_GetTopDrinkersString(TopDrinkers,sizeof(TopDrinkers),5);
	//If there is drinkers that round print out the top 5 DGers
	if (drinkers) {
		PrintToChatAll("%sTop 5 Drinkers:\n%s",msgColor, TopDrinkers);
	}

	for (new start = 1; start <= MaxClients; start++) {
		TotalDrinks[start] = 0;
		GivenDrinks[start] = 0;
	}
}

public OnClientDisconnect(client) {
	TotalDrinks[client] = 0;
	GivenDrinks[client] = 0;
	DG_Effects_KillSprite(client);
}

public Action:DG_ReadList(client, start) {
	new clients[MaxClients];
	for (new s = 0; s < MaxClients; s++){
		clients[s] = s+1;
	}

	SortCustom1D(clients,MaxClients,DG_SortByTotalDrinkCount)

	new String:name[64]
	new String:rtn[MaxClients][1000];
	new numDgers = 0;
	for (new i = 0; i < MaxClients; i++) {
		if (!IsClientConnected(clients[i]) && !IsClientInGame(clients[i])) {
			continue;
		}

		GetClientName(clients[i],name,sizeof(name));

		//Only count people with drinks
		if (TotalDrinks[clients[i]] > 0) {
			numDgers++;
			new String:strLine[510];

			Format(strLine,sizeof(strLine),"%s drank %d\n",name,TotalDrinks[clients[i]]);

			strcopy(rtn[numDgers - 1][0],1000,strLine);
		}
	}

	if (start < 0) {
		start = 0;
	}
	new stop = start + 5;
	if (stop > numDgers)
		stop = numDgers;

	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "Drinks this map");
	for (new i = start; i < stop; i++) {
		new String:value[1000]; Format(value, sizeof(value), "%d - %s", i+1, rtn[i]);
		DrawPanelText(panel, value);
	}

	if (start + 5 < numDgers) {
		DrawPanelItem(panel, "Next");
	}
	if (start > 0) {
		DrawPanelItem(panel, "Prev");
	}
	DrawPanelItem(panel, "Close");
	DrinkListStart[client] = start;
	SendPanelToClient(panel,client, DrinkListHandler, 20);
	CloseHandle(panel);
	return Plugin_Handled;
}

public DrinkListHandler(Handle:menu, MenuAction:action, client, value) {

	new numDgers = 0;
	for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}

		if  (TotalDrinks[i] > 0) {
			numDgers++;
		}
	}
	if (action == MenuAction_Select) {
		new next = 0;
		new prev = 0;
		//Next and prev is on there
		if (DrinkListStart[client] > 0 && DrinkListStart[client] + 5 < numDgers) {
			prev = 2;
			next = 1;
		} else if (DrinkListStart[client] == 0 && DrinkListStart[client] + 5 < numDgers) {
			next = 1;
		} else if (DrinkListStart[client] > 0) {
			prev = 1;
		}

		if (value == prev) {
			DG_ReadList(client, DrinkListStart[client]-5);
		}
		if (value == next) {
			DG_ReadList(client, DrinkListStart[client] + 5);
		}
	}
}

public DG_GetTopDrinkersString(String:buffer[], size, listmax) {
	new clients[MaxClients];

	for (new start = 0; start < MaxClients; start++){
		clients[start] = start+1;
	}

	SortCustom1D(clients,MaxClients,DG_SortByTotalDrinkCount)

	new String:name[64]
	//rtn is only going to be as big as the number of players
	new String:rtn[(MAXPLAYERS + 1)*(sizeof(name)+4)]
	new printed = 0;
	for (new i = 0; i < MaxClients; i++) {
		if (printed >= listmax) {
			continue;
		}

		if (!IsClientInGame(clients[i])) {
			continue;
		}

		GetClientName(clients[i],name,sizeof(name))

		//Only count people with drinks
		if (TotalDrinks[clients[i]] > 0) {
			printed++;
			new String:strLine[510];
			Format(strLine,sizeof(strLine),"%s drank %d\n",name,TotalDrinks[clients[i]]);
			StrCat(rtn,sizeof(rtn),strLine);
		}
	}

	strcopy(buffer,size,rtn);
}



public DG_SortByTotalDrinkCount(elem1, elem2, const array[],Handle:hndl) {
	if (TotalDrinks[elem1] < TotalDrinks[elem2]) {
		return 1;
	}
	if (TotalDrinks[elem1] == TotalDrinks[elem2]) {
		return 0;
	}
	else {
		return -1;
	}
}

// REMOVE Show DG Stats
/*
public ShowDGStats(client, String:plrname[]) {
	new String:statsUrl[300];
	GetConVarString(dgStatsURL,statsUrl,sizeof(statsUrl));

	new String:steam[32];
	GetClientAuthId(client,AuthId_Steam2,steam,sizeof(steam));
	if (strlen(plrname) > 0) {
		new String: url[255];
		Format(url,sizeof(url),"%s/dgstats.php?name=%s",statsUrl, plrname);
		ShowMOTDPanel(client,"DG Stats Search",url, MOTDPANEL_TYPE_URL);
	}
	else {
		new String: url[255];
		Format(url,sizeof(url),"%s/dgstats.php?steam_id=%s",statsUrl, steam);
		ShowMOTDPanel(client,"DG Stats player",url, MOTDPANEL_TYPE_URL);
	}
}
*/


public Action:DG_AddBotsCommand(client, args) {
	new count = 20;
	while (count > 0) {
		decl String:command[50];
		if (GetRandomFloat() < 0.8) {
			Format(command, sizeof(command), "tf_bot_add \"[DG] Drinker %i\"", count);
		}
		else {
			Format(command, sizeof(command), "tf_bot_add \"Non Drinker %i\"", count);
		}
		ServerCommand(command);
		count--;
	}
}

public OnGameFrame()
{
	new ent, Float:vOrigin[3], Float:vVelocity[3];

	for(new i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}
		if ((ent = dgSpritesParents[i]) > 0) {
			if (!IsValidEntity(ent)) {
				dgSpritesParents[i] = 0;
			}
			else {
				if ((ent = EntRefToEntIndex(ent)) > 0) {
					GetClientEyePosition(i, vOrigin);
					vOrigin[2] += 25.0;
					GetEntDataVector(i, gVelocityOffset, vVelocity);
					TeleportEntity(ent, vOrigin, NULL_VECTOR,vVelocity);
				}
			}
		}
	}
}
