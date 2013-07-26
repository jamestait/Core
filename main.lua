---- Some settings -----
SHOW_PLUGIN_NAMES = true	-- If true, plugin name will be shown before commands
							-- This is overwritten in the Initialize() function

-- Global variables
PLUGIN = {}	-- Reference to own plugin object
BannedPlayersIni = {}
WhiteListIni = {}
BackCoords = {}
Messages = {}
LimitWorldsCuboid = {}


function Initialize(Plugin)
	PLUGIN = Plugin
	
	Plugin:SetName("Core")
	Plugin:SetVersion(13)
	
	PluginManager = cRoot:Get():GetPluginManager()
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_PLAYER_JOINED)
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_PLAYER_BREAKING_BLOCK)
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_PLAYER_PLACING_BLOCK)
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_LOGIN)
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_KILLING)
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_CRAFTING_NO_RECIPE)
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_CHAT) -- used in web_chat.lua
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_CHUNK_GENERATING)
	PluginManager:AddHook(Plugin, cPluginManager.HOOK_PLAYER_MOVING)
	
	PluginManager:BindCommand("/worlds",          "core.worlds",          HandleWorldsCommand,          " - Shows a list of all the worlds");
	PluginManager:BindCommand("/listgroups",      "core.listgroups",      HandleListGroupsCommand,      " - Shows a list of all the groups");
	PluginManager:BindCommand("/toggledownfall",  "core.toggledownfall",  HandleToggleDownfallCommand,  " - Toggles the weather");
	PluginManager:BindCommand("/back",            "core.back",            HandleBackCommand,            " - Return to your last position");
	PluginManager:BindCommand("/save-all",        "core.save-all",        HandleSaveAllCommand,         " - Saves all your worlds");
	PluginManager:BindCommand("/help",            "core.help",            HandleHelpCommand,            " ~ Show available commands");
	PluginManager:BindCommand("/rank",            "core.rank",            HandleRankCommand,            " ~ Add someone to a group");
	PluginManager:BindCommand("/plugins",         "core.plugins",         HandlePluginsCommand,         " - Show list of plugins");
	PluginManager:BindCommand("/tp",              "core.teleport",        HandleTPCommand,              " ~ Teleport yourself to a player");
	PluginManager:BindCommand("/give",            "core.give",            HandleGiveCommand,            " ~ Give yourself an item");
	PluginManager:BindCommand("/list",            "core.playerlist",      HandlePlayerListCommand,      " - Shows list of connected players");
	PluginManager:BindCommand("/who",             "core.playerlist",      HandlePlayerListCommand,      " - Shows list of connected players");
	PluginManager:BindCommand("/playerlist",      "core.playerlist",      HandlePlayerListCommand,      " - Shows list of connected players");
	PluginManager:BindCommand("/motd",            "core.motd",            HandleMOTDCommand,            " - Show message of the day");
	PluginManager:BindCommand("/reload",          "core.reload",          HandleReloadCommand,          " - Reload all plugins");
	PluginManager:BindCommand("/stop",            "core.stop",            HandleStopCommand,            " - Stops the server");
	PluginManager:BindCommand("/time",            "core.time",            HandleTimeCommand,            " ~ Sets the time of day");
	PluginManager:BindCommand("/spawn",           "core.spawn",           HandleSpawnCommand,           " - Return to the spawn");
	PluginManager:BindCommand("/kick",            "core.kick",            HandleKickCommand,            " ~ Kick a player");
	PluginManager:BindCommand("/ban",             "core.ban",             HandleBanCommand,             " ~ Ban a player");
	PluginManager:BindCommand("/unban",           "core.unban",           HandleUnbanCommand,           " ~ Unban a player");
	PluginManager:BindCommand("/top",             "core.top",             HandleTopCommand,             " - Teleport yourself to the top most block");
	PluginManager:BindCommand("/gm",              "core.changegm",        HandleChangeGMCommand,        " ~ Change your gamemode");
	PluginManager:BindCommand("/portal",          "core.portal",          HandlePortalCommand,          " ~ Move to a different world");  
	PluginManager:BindCommand("/coords",          "core.coords",          HandleCoordsCommand,          " - Show your current server coordinates");
	PluginManager:BindCommand("/regen",           "core.regen",           HandleRegenCommand,           " ~ Regenerates a chunk, current or specified");
	PluginManager:BindCommand("/viewdistance",    "core.viewdistance",    HandleViewDistanceCommand,    " [".. cClientHandle.MIN_VIEW_DISTANCE .."-".. cClientHandle.MAX_VIEW_DISTANCE .."] - Change your view distance")
	
	InitConsoleCommands();
		
	-- Load the settings
	IniFile = cIniFile("Settings.ini")
	if ( IniFile:ReadFile() == true ) then
		HardCore = IniFile:GetValueSet("GameMode", "Hardcore", "false")
		LimitWorld = IniFile:GetValueSetB("Worlds", "LimitWorld", true)
		LimitWorldWidth = IniFile:GetValueSetI("Worlds", "LimitWorldWidth", 10)
		SHOW_PLUGIN_NAMES = IniFile:GetValueSetB("HelpPlugin", "ShowPluginNames", true )
		IniFile:WriteFile()
	end
	
    if LimitWorldWidth ~= nil then
	    cRoot:Get():ForEachWorld(
		    function( World )            
                LimitWorldsCuboid[World:GetName()] = cCuboid()
			    LimitWorldsCuboid[World:GetName()].p1 = Vector3i( math.floor(World:GetSpawnX() / 16) + LimitWorldWidth, 0, math.floor(World:GetSpawnZ() / 16) +  LimitWorldWidth)
			    LimitWorldsCuboid[World:GetName()].p2 = Vector3i( math.floor(World:GetSpawnX() / 16) - LimitWorldWidth, 256, math.floor(World:GetSpawnZ() / 16) -  LimitWorldWidth)
			    LimitWorldsCuboid[World:GetName()]:Sort()
		    end
	    )
    end
	-- Load whitelist, and add default values and stuff
	WhiteListIni = cIniFile( Plugin:GetLocalDirectory() .. "/whitelist.ini" )
	if ( WhiteListIni:ReadFile() == true ) then
		if( WhiteListIni:GetValueB("WhiteListSettings", "WhiteListOn", false) == true ) then
			if( WhiteListIni:GetNumValues("WhiteList") > 0 ) then
				LOGINFO("Core: loaded "  .. WhiteListIni:GetNumValues('WhiteList') .. " whitelisted players.")
			else
				LOGWARN("WARNING: WhiteList is on, but there are no people in the whitelist!")
			end
		end
	else
		WhiteListIni:SetValueB("WhiteListSettings", "WhiteListOn", false )
		WhiteListIni:SetValue("WhiteList", "", "")	-- So it adds an empty header
		WhiteListIni:DeleteValue("WhiteList", "") -- And remove the value
		WhiteListIni:KeyComment("WhiteList", "PlayerName=1")
		if( WhiteListIni:WriteFile() == false ) then
			LOGWARN("WARNING: Could not write to whitelist.ini")
		end
	end
	
	-- Load banned players, and add default values and stuff
	BannedPlayersIni = cIniFile( Plugin:GetLocalDirectory() .. "/banned.ini" )
	if ( BannedPlayersIni:ReadFile() == true ) then
		if( BannedPlayersIni:GetNumValues("Banned") > 0 ) then
			LOGINFO("Core: loaded "  .. BannedPlayersIni:GetNumValues("Banned") .. " banned players.")
		end
	else
		BannedPlayersIni:SetValue("Banned", "", "")	-- So it adds an empty header
		BannedPlayersIni:DeleteValue("Banned", "") -- And remove the value
		BannedPlayersIni:KeyComment("Banned", "PlayerName=1")
		if( BannedPlayersIni:WriteFile() == false ) then
			LOGWARN("WARNING: Could not write to banned.ini")
		end
	end
	
	Plugin:AddWebTab("Manage Server",   HandleRequest_ManageServer);
	Plugin:AddWebTab("Server Settings", HandleRequest_ServerSettings);
	Plugin:AddWebTab("Chat",            HandleRequest_Chat);
	Plugin:AddWebTab("Playerlist",      HandleRequest_PlayerList);
	Plugin:AddWebTab("Whitelist",       HandleRequest_WhiteList);
	Plugin:AddWebTab("Permissions",     HandleRequest_Permissions);
	Plugin:AddWebTab("Manage Plugins",  HandleRequest_ManagePlugins);
	
	LoadMotd()
	LOG( "Initialized " .. Plugin:GetName() .. " v." .. Plugin:GetVersion() )
	return true
end