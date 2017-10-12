#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

#define TRED 2
#define TBLU 3
#define QUEUE 1
#define TSPEC 0

#define TEAM_SPEC 1
#define TEAM_RED 2
#define TEAM_BLU 3

#define TEAM_SIZE 2

public Plugin kothbball =
{
    name = "KOTH BBALL",
    author = "Pye",
    description = "KOTH mode for TF2BBALL",
    version = "0.0.2",
    url = "http://www.sourcemod.net/"
};

Database db;

char player_SteamId[MAXPLAYERS+1][32];
char player_Name[MAXPLAYERS+1][32];
int player_Wins[MAXPLAYERS+1];
int player_Losses[MAXPLAYERS+1];
int player_TopStreak[MAXPLAYERS+1];
int player_Streak[MAXPLAYERS+1];

int serverQueue[MAXPLAYERS+1];
int playerStatus[MAXPLAYERS+1];

int redTeam[TEAM_SIZE];
int bluTeam[TEAM_SIZE];

public OnPluginStart()
{
  RegConsoleCmd("add", Command_Add, "Add to game.");
  RegConsoleCmd("remove", Command_Remove, "Remove from game.");
  RegConsoleCmd("spectate", Command_JoinTeam, "Remove from game.");
  RegConsoleCmd("jointeam", Command_JoinTeam, "jointeam");
  RegConsoleCmd("mystatus", Command_MyStatus, "Print the queue");
  RegConsoleCmd("streaks", Command_Streaks, "Show top streaks");
  RegAdminCmd("punt", Command_Punt, ADMFLAG_GENERIC, "Removes player by id (from console) from queue");
  RegAdminCmd("resetstreaks", Command_ResetStreaks, ADMFLAG_GENERIC, "Resets Server Top Streaks");
  SQL_setup();
}

public OnMapStart()
{
    HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);
}

public OnConfigsExecuted()
{
    ServerCommand("sm_respawn_time_enabled 1");
    ServerCommand("sm_respawn_time_blue 2");
    ServerCommand("sm_respawn_time_red 2");

    ServerCommand("tf_tournament_classlimit_scout 0");
    ServerCommand("tf_tournament_classlimit_soldier 2");
    ServerCommand("tf_tournament_classlimit_pyro 0");
    ServerCommand("tf_tournament_classlimit_demoman 0");
    ServerCommand("tf_tournament_classlimit_heavy 0");
    ServerCommand("tf_tournament_classlimit_engineer 0");
    ServerCommand("tf_tournament_classlimit_medic 0");
    ServerCommand("tf_tournament_classlimit_sniper 0");
    ServerCommand("tf_tournament_classlimit_spy 0");
}

public OnMapEnd()
{
    UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);
}

public OnClientDisconnect(int client)
{
  if (isValidClient(client))
  {
    char playername[64];
    GetClientName(client, playername, sizeof(playername));
    PrintToChatAll("%s - removed from queue", playername);

    if(playerStatus[client] == QUEUE)
    {
      leaveQueue(client);
    }
    else if(playerStatus[client] == TRED || playerStatus[client] == TBLU)
    {
      for(int i = 0; i < TEAM_SIZE; i++)
      {
        if(redTeam[i] == client)
        {
          redTeam[i] = 0;
          playerStatus[client] = TSPEC;
        }
        else if(bluTeam[i] == client)
        {
          bluTeam[i] = 0;
          playerStatus[client] = TSPEC;
        }
      }
    }
    for(int i = 0; i < 4 ; i++)
    {
      if(getRedTeamSize() + getBluTeamSize() <= 4)
        fillTeams();
    }
  }
}

public OnClientPostAdminCheck(int client)
{
  if (isValidClient(client))
  {
    playerStatus[client] = TSPEC;
    PrintCenterText(client, "Use !add to join the game, !remove to return to spectator");

    char query[256];
    char sqlDirtySteamId[31];
    char sqlSteamId[64];
    GetClientAuthId(client, AuthId_Steam2, sqlDirtySteamId, sizeof(sqlDirtySteamId));
    SQL_EscapeString(db, sqlDirtySteamId, sqlSteamId, sizeof(sqlSteamId));
    strcopy(player_SteamId[client], 32, sqlSteamId);
    Format(query, sizeof(query), "SELECT wins, losses, topstreak FROM kothbball_stats WHERE steamid='%s' LIMIT 1", sqlSteamId);
    SQL_TQuery(db, SQL_OnConnectQuery, query, client);
  }
}

void joinQueue(int client)
{
  if(playerStatus[client] == TSPEC)
  {
    int queue_pos = 0;
    while(serverQueue[queue_pos])
      queue_pos++;

    serverQueue[queue_pos] = client;
    playerStatus[client] = QUEUE;
  }
}

void leaveQueue(int client)
{
  if(playerStatus[client] == QUEUE)
  {
    int player_pos = 0;
    while(serverQueue[player_pos] != client)
      player_pos++;

    changePlayerTeam(client, TEAM_SPEC)

    char playername[64];
    GetClientName(client, playername, sizeof(playername));
    // Refresh the Queue
    int newServerQueue[MAXPLAYERS+1];
    for(int i = 0; i < MAXPLAYERS; i++)
    {
      if(i >= player_pos)
      {
        newServerQueue[i] = serverQueue[i+1];
      } else {
        newServerQueue[i] = serverQueue[i];
      }
    }
    newServerQueue[MAXPLAYERS] = 0;
    serverQueue = newServerQueue;
  }
}

int popQueue()
{
  if(getQueueSize() > 0)
  {
    int client = serverQueue[0];

    // Refresh the Queue
    int newServerQueue[MAXPLAYERS+1];
    for(int i = 0; i < MAXPLAYERS; i++)
    {
      if(i >= 0)
      {
        newServerQueue[i] = serverQueue[i+1];
      } else {
        newServerQueue[i] = serverQueue[i];
      }
    }
    newServerQueue[MAXPLAYERS] = 0;
    serverQueue = newServerQueue;
    return client;
  }
  return 0;
}

bool fillTeams()
{
  int player;
  int redTeamSize = getRedTeamSize();
  int bluTeamSize = getBluTeamSize();
  int queueSize = getQueueSize();
  if(queueSize == 0 || (redTeamSize == 2 && bluTeamSize == 2))
  {
    if(redTeamSize - bluTeamSize > 1)
    {
      if(redTeam[1] != 0)
      {
        player = redTeam[1]
        changePlayerTeam(player, TEAM_BLU);
        return true;
      }
    } else if(bluTeamSize - redTeamSize > 1) {
      if(bluTeam[1] != 0)
      {
        player = bluTeam[1]
        changePlayerTeam(player, TEAM_BLU);
        return true;
      }
    } else if(redTeamSize - bluTeamSize == 1)
    {
      if(redTeam[1] != 0)
      {
        player = redTeam[1]
        changePlayerTeam(player, TEAM_SPEC);
        joinQueue(player);
        return true;
      }
    } else if (bluTeamSize - redTeamSize == 1)
    {
      if(bluTeam[1] != 0)
      {
        player = bluTeam[1]
        changePlayerTeam(player, TEAM_SPEC);
        joinQueue(player);
        return true;
      }
    }
    return false;
  }
  if (redTeamSize == 1 && bluTeamSize == 1 && queueSize <= 1)
    return false;

  if(redTeamSize > bluTeamSize)
  {
    player = popQueue();
    changePlayerTeam(player, TEAM_BLU);
    return true;
  } else {
    player = popQueue();
    changePlayerTeam(player, TEAM_RED);
    return true;
  }
}

bool rotateTeams(int winner)
{
  int loser, loser0, loser1;
  int winner0, winner1;
  if(winner == TEAM_RED)
  {
    loser = TEAM_BLU;
    loser0 = bluTeam[0];
    loser1 = bluTeam[1];
    winner0 = redTeam[0];
    winner1 = redTeam[1];
  } else if (winner == TEAM_BLU)
  {
    loser = TEAM_RED;
    loser0 = redTeam[0];
    loser1 = redTeam[1];
    winner0 = bluTeam[0];
    winner1 = bluTeam[1];
  }
  if (getRedTeamSize() == 1)
  {
    changePlayerTeam(loser0, TEAM_SPEC);
    changePlayerTeam(winner0, loser);
    joinQueue(loser0);
    for(int i = 0; i < 4 ; i++)
    {
      if(getRedTeamSize() + getBluTeamSize() <= 4)
        fillTeams();
    }

  } else {
    changePlayerTeam(loser0, TEAM_SPEC);
    changePlayerTeam(loser1, TEAM_SPEC);
    changePlayerTeam(winner0, loser);
    changePlayerTeam(winner1, winner);
    joinQueue(loser0);
    joinQueue(loser1);
    for(int i = 0; i < 4 ; i++)
    {
      if(getRedTeamSize() + getBluTeamSize() <= 4)
        fillTeams();
    }
  }
}

bool changePlayerTeam(player, team)
{
  if(!isValidClient(player))
  {
    return false;
  }

  if(playerStatus[player] == TRED)
  {
    if(redTeam[0] == player)
      redTeam[0] = 0;
    if(redTeam[1] == player)
      redTeam[1] = 0;
  }
  else if(playerStatus[player] == TBLU)
  {
    if(bluTeam[0] == player)
      bluTeam[0] = 0;
    if(bluTeam[1] == player)
      bluTeam[1] = 0;
  }

  if(team == TEAM_RED)
  {
    for(int i = 0; i < TEAM_SIZE; i++)
    {
      if (redTeam[i] == 0)
      {
        redTeam[i] = player;
        ChangeClientTeam(player, team);
        playerStatus[player] = TRED;
        return true;
      }
    }
  }
  else if (team == TEAM_BLU)
  {
    for(int i = 0; i < TEAM_SIZE; i++)
    {
      if (bluTeam[i] == 0)
      {
        bluTeam[i] = player;
        ChangeClientTeam(player, team);
        playerStatus[player] = TBLU;
        return true;
      }
    }
  }

  ForcePlayerSuicide(player);
  ChangeClientTeam(player, team);
  playerStatus[player] = TSPEC
  return true;
}

int getRedTeamSize()
{
  int index = 0;
  int size = 0;
  while(index < MAXPLAYERS)
  {
    if(playerStatus[index] == TRED)
    {
      size++;
    }
   index++; 
  }
  return size;
}

int getBluTeamSize()
{
  int index = 0;
  int size = 0;
  while(index < MAXPLAYERS)
  {
    if(playerStatus[index] == TBLU)
    {
      size++;
    }
   index++; 
  }
  return size;
}

int getQueueSize()
{
  int index = 0;
  int size = 0;
  while(index < MAXPLAYERS)
  {
    if(playerStatus[index] == QUEUE) 
    {
      size++;
    }
   index++; 
  }
  return size;
}

int getQueuePosition(int client)
{
  int position = 0;
  while(serverQueue[position] != client)
  {
    position++;
  }
  return position;
}

bool isValidClient(iClient)
{
	if(iClient < 1 || iClient > MaxClients)
		return false;
	if(!IsClientConnected(iClient))
		return false;
	if(IsClientInKickQueue(iClient))
		return false;
	if(IsClientSourceTV(iClient))
		return false;
	return IsClientInGame(iClient);
}

public Action:Command_JoinTeam(int client, int args)
{
  if (!isValidClient(client))
    return Plugin_Continue;

  if(playerStatus[client] == TSPEC)
  {
    changePlayerTeam(client, TEAM_SPEC);
  }
  else if(playerStatus[client] == TRED)
  {
    changePlayerTeam(client, TEAM_RED);
  }
  else if(playerStatus[client] == TBLU)
  {
    changePlayerTeam(client, TEAM_BLU);
  }

  if(getRedTeamSize() + getBluTeamSize() <= 4)
    fillTeams();
  return Plugin_Handled;
}

public Action:scrambleRed(Handle timer)
{
  rotateTeams(TEAM_RED);
}
public Action:scrambleBlu(Handle timer)
{
  rotateTeams(TEAM_BLU);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
  int winners[TEAM_SIZE];
  int losers[TEAM_SIZE];
  int winner = GetEventInt(event, "team");
  if(winner == TEAM_RED)
  {
    winners = redTeam;
    losers = bluTeam;
    CreateTimer(5.0, scrambleRed);
  }
  if(winner == TEAM_BLU)
  {
    winners = bluTeam;
    losers = redTeam;
    CreateTimer(5.0, scrambleBlu);
  }

  for(int i = 0; i < TEAM_SIZE; i++)
  {
    player_Streak[winners[i]]++;
    player_Streak[losers[i]] = 0;
    if(player_Streak[winners[i]] > player_TopStreak[winners[i]])
    {
      player_TopStreak[winners[i]] = player_Streak[winners[i]];
      SQL_updateTopStreak(winners[i], player_TopStreak[winners[i]]);
    }
    if(winners[i] != 0)
      PrintToChatAll("%s is on a %d game winning streak.", player_Name[winners[i]], player_Streak[winners[i]]);
  }

  PrintCenterTextAll(">>>>>| GAME END - SPLITTING TEAMS |<<<<<");
  SetEventInt(event, "silent", true);
  return Plugin_Continue;
}

public Action:OnGetGameDescription(String:gameDesc[64])
{
    Format(gameDesc, sizeof(gameDesc), "KOTHBBALL");
    return Plugin_Changed;
}

public Action:Command_Add(int client, int args)
{
  if (!isValidClient(client))
    return Plugin_Continue;

  char playername[64];
  GetClientName(client, playername, sizeof(playername));
  TF2_SetPlayerClass(client, TFClass_Soldier);

  if(playerStatus[client] == TSPEC)
  {
    joinQueue(client);
    PrintToChatAll("%s added to queue at position: %d", playername, getQueuePosition(client));
  }
  else if(playerStatus[client] == QUEUE)
  {
    PrintToChatAll("%s is already in queue!", playername);
  }
  else if(playerStatus[client] == TRED || playerStatus[client] == TBLU)
  {
    PrintToChatAll("%s is already in game!", playername);
  }

  for(int i = 0; i < 4 ; i++)
  {
    if(getRedTeamSize() + getBluTeamSize() <= 4)
      fillTeams();
  }
  return Plugin_Handled;
}

public Action:Command_Remove(int client, int args)
{
  if (!isValidClient(client))
    return Plugin_Continue;

  char playername[64];
  GetClientName(client, playername, sizeof(playername));

  if(playerStatus[client] == QUEUE)
  {
    leaveQueue(client);
    PrintToChatAll("%s removed from queue", playername);
  }
  else if(playerStatus[client] == TRED || playerStatus[client] == TBLU)
  {
    changePlayerTeam(client, TEAM_SPEC);
  }

  for(int i = 0; i < 4 ; i++)
  {
    if(getRedTeamSize() + getBluTeamSize() <= 4)
      fillTeams();
  }
  return Plugin_Handled;
}

public Action:Command_MyStatus(int client, int args)
{
  if (!isValidClient(client))
    return Plugin_Continue;

  char playername[64];
  GetClientName(client, playername, sizeof(playername));

  if(playerStatus[client] == QUEUE)
  {
    PrintToChatAll("%s is in QUEUE at position: %d", playername, getQueuePosition(client));
  }
  else if(playerStatus[client] == TSPEC)
  {
    PrintToChatAll("%s is in SPEC", playername);
  }
  else if(playerStatus[client] == TRED)
  {
    PrintToChatAll("%s is on RED TEAM", playername);
  }
  else if(playerStatus[client] == TBLU)
  {
    PrintToChatAll("%s is on BLU TEAM", playername);
  } else {
    PrintToChatAll("%s is UNKNOWN", playername);
  }

  return Plugin_Handled;
}

public Action:Command_Punt(int client, int args)
{
  if (!isValidClient(client))
    return Plugin_Continue;

  char user[32];
  GetCmdArg(1, user, sizeof(user));
  int targ = -1;
  int tar = StringToInt(user);
  for(int i = 1; i < MAXPLAYERS; i++)
  {
    if (!isValidClient(i))
      continue;
    if(GetClientUserId(i) == tar)
    {
      targ = i;
    }
  }
  if(targ == -1)
    return Plugin_Handled;

  char playername[64];
  GetClientName(targ, playername, sizeof(playername));

  if(playerStatus[targ] == QUEUE)
  {
    leaveQueue(targ);
    PrintToChatAll("%s removed from queue", playername);
  }
  else if(playerStatus[targ] == TRED || playerStatus[targ] == TBLU)
  {
    changePlayerTeam(targ, TEAM_SPEC);
  }

  for(int i = 0; i < 4 ; i++)
  {
    if(getRedTeamSize() + getBluTeamSize() <= 4)
      fillTeams();
  }
  return Plugin_Handled;
}

public Action:Command_Streaks(int client, int args)
{
  char query[256];
  Format(query, sizeof(query), "SELECT topstreak,name FROM kothbball_stats ORDER BY topstreak DESC LIMIT 5");
  SQL_TQuery(db, SQL_TopStreaks, query);
}

public Action:Command_ResetStreaks(int client, int args)
{
  char query[256]
  Format(query, sizeof(query), "UPDATE kothbball_stats SET topstreak=%d", 0);
  SQL_TQuery(db, SQL_ErrorCheckCallback, query);
  PrintToChatAll("Win Streaks Reset!");
}

// SQL
public SQL_setup()
{
  char error[256];
  db = SQL_Connect("storage-local", true, error, sizeof(error));

  if(db == INVALID_HANDLE)
    SetFailState("Could not connect to db: %s", error);

  SQL_TQuery(db, SQL_ErrorCheckCallback, "CREATE TABLE IF NOT EXISTS kothbball_stats (steamid TEXT, name TEXT, wins INTEGER, losses INTEGER, topstreak INTEGER)");
}

public SQL_updateTopStreak(int client, int topstreak)
{
  char query[256]
  Format(query, sizeof(query), "UPDATE kothbball_stats SET topstreak=%d WHERE steamid='%s'", topstreak, player_SteamId[client]);
  SQL_TQuery(db, SQL_ErrorCheckCallback, query);
}

public SQL_TopStreaks(Handle owner, Handle cb, const String:error[], int client)
{
	if(cb==INVALID_HANDLE)
	{
		LogError("getTopStreaks failed: %s", error);
		return;
	} 
  char name[64];
  int streak;
  int i = 0;
  PrintToChatAll("-------TOP STREAKS-------")
  while(SQL_FetchRow(cb))
  {
    if(i > 5)
      break;
    SQL_FetchString(cb, 1, name, 64);
    streak = SQL_FetchInt(cb, 0);
    PrintToChatAll("%d | %s", streak, name);
    i++;
  }
}

public SQL_OnConnectQuery(Handle owner, Handle cb, const String:error[], int client)
{
	if(cb==INVALID_HANDLE)
	{
		LogError("OnConnectQuery failed: %s", error);
		return;
	} 
  if(!isValidClient(client))
  {
		LogError("OnConnectQuery failed: %d is invalid client", client);
		return;
  }

  char query[512];
  char sqlDirtyName[MAX_NAME_LENGTH];
  char sqlName[(MAX_NAME_LENGTH*2)+1];
  GetClientName(client, sqlDirtyName, sizeof(sqlDirtyName));
  SQL_EscapeString(db, sqlDirtyName, sqlName, sizeof(sqlName));

  if(SQL_FetchRow(cb))
  {
    player_Wins[client] = SQL_FetchInt(cb, 0);
    player_Losses[client] = SQL_FetchInt(cb, 1);
    player_TopStreak[client] = SQL_FetchInt(cb, 2);
    player_Streak[client] = 0;
    strcopy(player_Name[client], 32, sqlName);
		Format(query, sizeof(query), "UPDATE kothbball_stats SET name='%s' WHERE steamid='%s'", sqlName, player_SteamId[client]);
		SQL_TQuery(db, SQL_ErrorCheckCallback, query);
  } else {
    Format(query, sizeof(query), "INSERT INTO kothbball_stats VALUES('%s', '%s', 0, 0, 0)", player_SteamId[client], sqlName);
    SQL_TQuery(db, SQL_ErrorCheckCallback, query);
    player_Wins[client] = 0;
    player_Losses[client] = 0;
    player_TopStreak[client] = 0;
    player_Streak[client] = 0;
    strcopy(player_Name[client], 32, sqlName);
  }
}

public SQL_ErrorCheckCallback(Handle owner, Handle cb, const String:error[], any data)
{
  return;
}