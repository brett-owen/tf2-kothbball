tf2-kothbball
=============

**tf2-kothbball** is a SourceMod plugin for Team Fortress 2, enabling a king of the hill style gameplay mode for Team Fortress 2 Basketball.

You can set the cvar `kothbball_enabled` to `1` to enable the mod, by default it's disabled.
To enable the mod add `kothbball_enabled 1` to your `server.cfg` or to a `<mapname>.cfg` file.

When the mod is running, it attempts to execute `bball.cfg` on map load, I've provided a sample `bball.cfg` with some appropriate settings.

In-game, use `!add` in chat to join the game, `!remove` in chat to return to spectator. 

Using `!mystatus` in chat will show your current status as well.

Players can use `!streaks` to show the top win streaks for the server.

Admins can use `!punt <PLAYERID>` to remove players from the queue or the game.

Admins can use `!resetstreaks` to reset the top win streaks for the server.

Note that this plugin **requires** the [TF2 Respawn System by WoZeR](https://forums.alliedmods.net/showthread.php?p=611953) plugin in order to properly set the respawn times to 2 seconds.

Note that this plugin **recommends** the [TFTrue](http://tftrue.esport-tools.net/) plugin in order to properly set bball whitelists.
