#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

// ============================================================================
// Defines
// ============================================================================
#define TEAM_SPEC 1
#define TEAM_RED 2
#define TEAM_BLU 3
#define TEAM_QUEUE 4
#define TEAM_SIZE 2

public Plugin kothbball =
{
    name = "KOTH BBALL",
    author = "Pye",
    description = "KOTH mode for TF2BBALL",
    version = "0.3.0",
    url = "http://www.sourcemod.net/"
};


// ============================================================================
// Server Variables 
// ============================================================================
Database db;

ConVar cvar_EnableKothBball;

int serverQueue[MAXPLAYERS+1];
int redTeam[TEAM_SIZE];
int bluTeam[TEAM_SIZE];


// ============================================================================
// Player Variables 
// ============================================================================
Handle player_WelcomeTimer[MAXPLAYERS+1];
char player_SteamId[MAXPLAYERS+1][32];
char player_Name[MAXPLAYERS+1][32];
int player_Wins[MAXPLAYERS+1];
int player_Losses[MAXPLAYERS+1];
int player_TopStreak[MAXPLAYERS+1];
int player_Streak[MAXPLAYERS+1];
int playerStatus[MAXPLAYERS+1];


// ============================================================================
// Forwards 
// ============================================================================
public OnPluginStart()
{
  cvar_EnableKothBball = CreateConVar("kothbball_enabled", "0", "Enable/Disable KOTHBBALL");
  cvar_EnableKothBball.AddChangeHook(OnEnabledChange);

  RegConsoleCmd("add", Command_Add, "Add to game.");
  RegConsoleCmd("remove", Command_Remove, "Remove from game.");
  RegConsoleCmd("spectate", Command_JoinTeam, "Remove from game.");
  RegConsoleCmd("jointeam", Command_JoinTeam, "jointeam");
  RegConsoleCmd("status", Command_MyStatus, "Print the queue");
  RegConsoleCmd("streaks", Command_Streaks, "Show top streaks");
  RegConsoleCmd("upnext", Command_Streaks, "Show top streaks");
  RegAdminCmd("punt", Command_Punt, ADMFLAG_GENERIC, "Removes player by id (from console) from queue");
  RegAdminCmd("resetstreaks", Command_ResetStreaks, ADMFLAG_GENERIC, "Resets Server Top Streaks");
  SQL_setup();
}

public OnMapStart()
{
  if(GetConVarBool(cvar_EnableKothBball))
    HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);
}

public OnConfigsExecuted()
{
  if(GetConVarBool(cvar_EnableKothBball))
  {
    ServerCommand("sm_respawn_time_enabled 1");
    ServerCommand("sm_respawn_time_blue 2");
    ServerCommand("sm_respawn_time_red 2");

    ServerCommand("exec bball.cfg");
  } else {
    ServerCommand("sm_respawn_time_enabled 0");
  }
}

public OnMapEnd()
{
  if(GetConVarBool(cvar_EnableKothBball))
    UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);
}

public OnClientDisconnect(int client)
{
  if(GetConVarBool(cvar_EnableKothBball))
  {
    if (isValidClient(client))
    {
      char playername[64];
      GetClientName(client, playername, sizeof(playername));
      PrintToChatAll("%s - Left the game, Removed from queue.", playername);

      if(playerStatus[client] == TEAM_QUEUE)
      {
        leaveQueue(client);
      }
      else if(playerStatus[client] == TEAM_RED || playerStatus[client] == TEAM_BLU)
      {
        for(int i = 0; i < TEAM_SIZE; i++)
        {
          if(redTeam[i] == client)
          {
            redTeam[i] = 0;
            playerStatus[client] = TEAM_SPEC;
          }
          else if(bluTeam[i] == client)
          {
            bluTeam[i] = 0;
            playerStatus[client] = TEAM_SPEC;
          }
        }
      }
      fillTeams();
    }
  }
}

public OnClientPostAdminCheck(int client)
{
  if(GetConVarBool(cvar_EnableKothBball))
  {
    if (isValidClient(client))
    {
      playerStatus[client] = TEAM_SPEC;
      PrintCenterText(client, "Use !add to join the game, !remove to return to spectator");
      player_WelcomeTimer[client] = CreateTimer(15.0, Timer_Welcome, GetClientUserId(client));

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
}

public OnEnabledChange(ConVar convar, char[] oldValue, char[] newValue)
{
  if(StrEqual(newValue, oldValue))
  {
    return;
  }
  if(StringToInt(newValue) == 1)
  {
    HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);
    ServerCommand("sm_respawn_time_enabled 1");
    ServerCommand("sm_respawn_time_blue 2");
    ServerCommand("sm_respawn_time_red 2");

    ServerCommand("exec bball.cfg");
  }
  else if (StringToInt(newValue) == 0)
  {
    UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Pre);
    ServerCommand("sm_respawn_time_enabled 0");
  }
}


// ============================================================================
// Queue 
// ============================================================================
void joinQueue(int client)
{
  if(playerStatus[client] == TEAM_SPEC)
  {
    int queue_pos = 0;
    while(serverQueue[queue_pos])
      queue_pos++;

    serverQueue[queue_pos] = client;
    playerStatus[client] = TEAM_QUEUE;
  }
}

void leaveQueue(int client)
{
  if(playerStatus[client] == TEAM_QUEUE)
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


// ============================================================================
// Team Balance Logic
// ============================================================================

void assignPlayer(int player, bool toQueue=false)
{
  if(toQueue)
  {
    changePlayerTeam(player, TEAM_SPEC);
    joinQueue(player);
    return;
  }
  if(getRedTeamSize() > getBluTeamSize())
  {
    changePlayerTeam(player, TEAM_BLU);
  } else {
    changePlayerTeam(player, TEAM_RED);
  }
}

void fillTeams()
{
  int redTeamSize = getRedTeamSize();
  int bluTeamSize = getBluTeamSize();
  int queueSize = getQueueSize();
  for(int i = 0; i < 2; i++)
  {
    redTeamSize = getRedTeamSize();
    bluTeamSize = getBluTeamSize();
    queueSize = getQueueSize();

    if (redTeamSize == 2 && bluTeamSize == 2)
    {
      return;
    }

    if(queueSize == 0 || (redTeamSize == 2 && bluTeamSize == 2))
    {
      if(redTeamSize - bluTeamSize > 1)
      {
        assignPlayer(redTeam[1]);
      } else if(bluTeamSize - redTeamSize > 1) {
        assignPlayer(bluTeam[1]);
      } else if(redTeamSize - bluTeamSize == 1) {
        assignPlayer(redTeam[1], true);
      } else if (bluTeamSize - redTeamSize == 1) {
        assignPlayer(bluTeam[1], true);
      }
    }  

    if (redTeamSize == 1 && bluTeamSize == 1 && queueSize <= 1)
    {
      break;
    }
    else
    {
      assignPlayer(popQueue());
    }
  }
}

bool changePlayerTeam(player, team)
{
  if(!isValidClient(player))
  {
    return false;
  }

  if(playerStatus[player] == TEAM_RED)
  {
    if(redTeam[0] == player)
      redTeam[0] = 0;
    if(redTeam[1] == player)
      redTeam[1] = 0;
  }
  else if(playerStatus[player] == TEAM_BLU)
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
        playerStatus[player] = TEAM_RED;
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
        playerStatus[player] = TEAM_BLU;
        return true;
      }
    }
  }

  ForcePlayerSuicide(player);
  ChangeClientTeam(player, team);
  playerStatus[player] = TEAM_SPEC
  return true;
}


// ============================================================================
// Helpers
// ============================================================================
bool isValidClient(int client)
{
  if(client < 1 || client > MaxClients)
    return false;
  if(!IsClientConnected(client))
    return false;
  if(IsClientInKickQueue(client))
    return false;
  if(IsClientSourceTV(client))
    return false;
  return IsClientInGame(client);
}

int getRedTeamSize()
{
  int index = 0;
  int size = 0;
  while(index < MAXPLAYERS)
  {
    if(playerStatus[index] == TEAM_RED)
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
    if(playerStatus[index] == TEAM_BLU)
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
    if(playerStatus[index] == TEAM_QUEUE) 
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


// ============================================================================
// Events
// ============================================================================
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

  int winners[TEAM_SIZE];
  int losers[TEAM_SIZE];
  int winner = GetEventInt(event, "team");
  if(winner == TEAM_RED)
  {
    winners = redTeam;
    losers = bluTeam;
  }
  else if(winner == TEAM_BLU)
  {
    winners = bluTeam;
    losers = redTeam;
  } else {
    for(int i = 0; i < TEAM_SIZE; i++)
    {
      if(player_Streak[redTeam[i]] > 1)
        PrintToChatAll("%s just lost their %d game winning streak!", player_Name[redTeam[i]], player_Streak[redTeam[i]]);
      if(player_Streak[bluTeam[i]] > 1)
        PrintToChatAll("%s just lost their %d game winning streak!", player_Name[bluTeam[i]], player_Streak[bluTeam[i]]);
      player_Streak[redTeam[i]] = 0;
      player_Streak[bluTeam[i]] = 0;
      assignPlayer(redTeam[i], true);
      assignPlayer(bluTeam[i], true);
      return Plugin_Continue;
    }
  }


  CreateTimer(5.0, Timer_ShuffleTeams, winner);

  for(int i = 0; i < TEAM_SIZE; i++)
  {
    player_Streak[winners[i]]++;
    if(player_Streak[losers[i]] > 1)
      PrintToChatAll("%s just lost their %d game winning streak!", player_Name[losers[i]], player_Streak[losers[i]]);
    if(player_Streak[winners[i]] > 1)
      PrintToChatAll("%s is on a %d game winning streak!", player_Name[winners[i]], player_Streak[winners[i]]);
    player_Streak[losers[i]] = 0;
    if(player_Streak[winners[i]] > player_TopStreak[winners[i]])
    {
      player_TopStreak[winners[i]] = player_Streak[winners[i]];
      SQL_updateTopStreak(winners[i], player_TopStreak[winners[i]]);
    }
  }

  PrintCenterTextAll(">>>>>| GAME END - SHUFFLING TEAMS |<<<<<");
  SetEventInt(event, "silent", true);
  return Plugin_Continue;
}


// ============================================================================
// Commands
// ============================================================================
public Action:Command_JoinTeam(int client, int args)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

  if (!isValidClient(client))
    return Plugin_Continue;

  if(playerStatus[client] == TEAM_SPEC)
  {
    changePlayerTeam(client, TEAM_SPEC);
  }
  else if(playerStatus[client] == TEAM_RED)
  {
    changePlayerTeam(client, TEAM_RED);
  }
  else if(playerStatus[client] == TEAM_BLU)
  {
    changePlayerTeam(client, TEAM_BLU);
  }

  fillTeams();
  return Plugin_Handled;
}

public Action:Command_Add(int client, int args)
{
  if (!isValidClient(client))
    return Plugin_Continue;

  char playername[64];
  GetClientName(client, playername, sizeof(playername));
  TF2_SetPlayerClass(client, TFClass_Soldier);

  if(playerStatus[client] == TEAM_SPEC)
  {
    joinQueue(client);
    PrintToChatAll("%s added to queue. Current position: %d", playername, getQueuePosition(client)+1);
  }
  else if(playerStatus[client] == TEAM_QUEUE)
  {
    PrintToChatAll("%s is already in queue!", playername);
  }
  else if(playerStatus[client] == TEAM_RED || playerStatus[client] == TEAM_BLU)
  {
    PrintToChatAll("%s is already in game!", playername);
  }

  fillTeams();
  return Plugin_Handled;
}

public Action:Command_Punt(int client, int args)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

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

  if(playerStatus[targ] == TEAM_QUEUE)
  {
    leaveQueue(targ);
    PrintToChatAll("%s removed from queue", playername);
  }
  else if(playerStatus[targ] == TEAM_RED || playerStatus[targ] == TEAM_BLU)
  {
    changePlayerTeam(targ, TEAM_SPEC);
  }

  fillTeams();
  return Plugin_Handled;
}

public Action:Command_Streaks(int client, int args)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

  char query[256];
  Format(query, sizeof(query), "SELECT topstreak,name FROM kothbball_stats ORDER BY topstreak DESC LIMIT 5");
  SQL_TQuery(db, SQL_TopStreaks, query);
  return Plugin_Handled;
}

public Action:Command_ResetStreaks(int client, int args)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

  char query[256]
  Format(query, sizeof(query), "UPDATE kothbball_stats SET topstreak=%d", 0);
  SQL_TQuery(db, SQL_ErrorCheckCallback, query);
  PrintToChatAll("Win Streaks Reset!");
  return Plugin_Handled;
}

public Action:Command_Remove(int client, int args)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

  if (!isValidClient(client))
    return Plugin_Continue;

  char playername[64];
  GetClientName(client, playername, sizeof(playername));

  if(playerStatus[client] == TEAM_QUEUE)
  {
    leaveQueue(client);
    PrintToChatAll("%s removed from queue", playername);
  }
  else if(playerStatus[client] == TEAM_RED || playerStatus[client] == TEAM_BLU)
  {
    changePlayerTeam(client, TEAM_SPEC);
  }

  fillTeams();
  return Plugin_Handled;
}

public Action:Command_MyStatus(int client, int args)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

  if (!isValidClient(client))
    return Plugin_Continue;

  char playername[64];
  GetClientName(client, playername, sizeof(playername));

  if(playerStatus[client] == TEAM_QUEUE)
  {
    PrintToChatAll("%s is in QUEUE at position: %d", playername, getQueuePosition(client));
  }
  else if(playerStatus[client] == TEAM_SPEC)
  {
    PrintToChatAll("%s is in SPEC", playername);
  }
  else if(playerStatus[client] == TEAM_RED)
  {
    PrintToChatAll("%s is on RED TEAM", playername);
  }
  else if(playerStatus[client] == TEAM_BLU)
  {
    PrintToChatAll("%s is on BLU TEAM", playername);
  } else {
    PrintToChatAll("%s is UNKNOWN", playername);
  }
  return Plugin_Handled;
}

public Action:Command_UpNext(int client, int args)
{
  if(!GetConVarBool(cvar_EnableKothBball))
    return Plugin_Continue;

  if (!isValidClient(client))
    return Plugin_Continue;

  char playername[64];
  int playerid;
  if(getQueueSize > 0)
  {
    PrintToChatAll("UP NEXT");
    PrintToChatAll("-------");
    for(int i = 0; i < MAXPLAYERS+1)
    {
      if(serverQueue[i] != 0)
      {
        GetClientName(serverQueue[i], playername, sizeof(playername));
        PrintToChatAll("%d -- %s", i+1, playername);
      }
    }
  }
  else
  {
    PrintToChatAll("No players in queue.");
  }
  return Plugin_Handled;
}

// ============================================================================
// Timers
// ============================================================================
public Action:Timer_Welcome(Handle timer, any userid)
{
  int client = GetClientOfUserId(userid);
  if(!isValidClient(client))
    return;

  PrintToChat(client, "Welcome to KOTH BBALL, type !add in chat to join the game, !remove to return to spectator.");
}

public Action:Timer_ShuffleTeams(Handle timer, any winner)
{
  if(winner == TEAM_RED)
  {
    assignPlayer(bluTeam[0], true);
    assignPlayer(bluTeam[1], true);
    assignPlayer(redTeam[1]);
  }
  else if(winner == TEAM_BLU)
  {
    assignPlayer(redTeam[0], true);
    assignPlayer(redTeam[1], true);
    assignPlayer(bluTeam[1]);
  }
  fillTeams();
}


// ============================================================================
// SQL
// ============================================================================
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