require "common.compat.compat"

--(require "common.util.mobdebug").loop()
print("Start server script!", World.GameName)
require "common.win_debug"

require "common.preload"
require "common.expressionCalculation"
require "common.profiler"
local roomGameConfig = Server.CurServer:getConfig()
require "common.profiler_lib"
if roomGameConfig:isDebug() then
	--Profiler:init()
end

require "common.api.api_proxy"

require "common.data_cache_container"
require "common.lib"
require "common.zipfile"
require "common.os_locale"
require "common.vfs2"
require "common.math.math"
require "common.define"
require "instance"
require "common.object"
if not DataLink then
	require "common.vfs"
end
require "common.execuserscript"
require "common.check_assistant"
require "common.util.file_util"

local setting = require "common.setting"

World.serverType = World.CurWorld:getServerType()
World.isGameServer = World.serverType=="gameserver"
World.isGameCenter = World.serverType=="gamecenter"
require "common.packet_convert"

World.isEditorServer = Server.CurServer:getConfig():IsEditorServer()
World.IsLibServer = Server.CurServer:getConfig():IsLibServer()

require "common.vars"
require "common.trigger"
require "stage"
require "server"
require "world.world"

require "resloader"
ResLoader:addGame(World.GameName)
ResourceGroupManager:Instance():setSearchLowerCase(not (World.cfg.resSearchLowerCase == false))
ResourceGroupManager:Instance():setSearchPureName(not (World.cfg.resSearchPureName == false))
FileResourceManager:Instance():setSearchPureName(not (World.cfg.resSearchPureName == false))
require "event"
require "event.event"
require "trade"
require "object.object"
require "entity.entity"
require "player.player"
require "common.item"
require "common.tray"
require "tray.tray"
require "item.dropitem"
require "missile.missile_server"
require "common.water_manager"
require "common.lava_manager"
require "common.map_chunk_mgr"
require "common.actions.actions_game"
require "common.actions.actions_lib"
require "common.actions.actions_var"
require "block.block"
require "actions.actions"
require "actions.actions_ai"
require "actions.actions_block"
require "actions.actions_buff"
require "actions.actions_entity"
require "actions.actions_part"
require "actions.actions_game"
require "actions.actions_item"
require "actions.actions_lib"
require "actions.actions_time"
require "actions.actions_map"
require "actions.actions_object"
require "actions.actions_pet"
require "actions.actions_player"
require "actions.actions_rank"
require "actions.actions_team"
require "actions.actions_var"
require "actions.actions_ui"
require "actions.actions_stage"
require "actions.actions_store"
require "actions.actions_http"
require "actions.actions_camera"
require "actions.actions_center"
require "actions.actions_friendFollow"
require "common.actions.actions_trigger"
require "skill.skill"
require "game.game"
require "coin"
require "shop"
require "commodity"
require "singleShop"
require "common.cache.user_info_cache"
require "rank"
require "game_analytics"
require "composition"
require "reward_manager"
require "report_manager"
require "party_manager"
require "world.scene_ui_manager"
require "gm"
require "store"
require "building.building"
require "common.combination_block"
require "atproxy.atproxy"
require "world.map_event"
require "common.map_patch_mgr"
require "common.plugins"
require "package_handlers"
require "player.player_report"
require "shop.player_shop"
require "shop.shop"
require "common.scene_handler"
require "common.physics"
require "common.scene_lib"
local Platform = require "common.platform"
GameReport = require "common.game_report"

-- 已在common.os_locale处理
--os.setlocale(".UTF-8")

local PartStorage = require "common.service.part_storage"
PartStorage.Init()

local DBHandler = require "dbhandler" ---@type DBHandler
DBHandler:init()

local PlayerDBMgr = require "player_db_mgr" ---@type PlayerDBMgr
PlayerDBMgr:init()

local RedisHandler = require "redishandler"
RedisHandler:init()

require "data.data_service"

require "server.api.manager"

UserInfoCache.Init()
AsyncProcess.Init()
PartyManager.Init()
Plugins.LoadPlugin("new_platform_chat")
Plugins.LoadAllPlugins()
Plugins.LoadPlugin("tween")

local pluginManager = require "common.plugin_manager"
pluginManager:loadGamePlugins()

World.CurWorld:load()
GameAnalytics.Init()

local debugport = require "common.debugport"
debugport.Init("debug_history_server.txt", 6600, 6666)

local lockfile = L("lockfile")
if not lockfile then
	lockfile = io.open("server.lock", "w")
end

function handle_tick(frameTime)
	CPUTimer.StartForLua("lua:handleTick:world.tick")
	World.Tick(frameTime)
	CPUTimer.Stop()
	local LuaTimer = T(Lib, "LuaTimer")

	CPUTimer.StartForLua("lua:handleTick:LuaTimer.onTick")
	LuaTimer:onTick(frameTime)
	CPUTimer.Stop()

	CPUTimer.StartForLua("lua:handleTick:debugport.onTick")
	debugport.Tick()
	CPUTimer.Stop()
end

function release_game()
	debugport.Uninit()
	Profiler:reset()
	lockfile = lockfile	-- 防止自动释放
end


local t0 = os.time()
collectgarbage()
print("collectgarbage cost", os.time() - t0)

--tell pc editor
local  editor_env = os.getenv("startFromWorldEditor")
if editor_env then
	local function sendTCP(msg)
		local host, port = "127.0.0.1", 60051
		local socket
		if ( Root.platform() == Platform.WINDOWS ) then
			socket = require("bin.zbstudio.lualibs.socket")
		else
			local ZBS = os.getenv("ZBS") or Platform.ZBStudioPath()
			package.cpath = package.path ..';'..ZBS..'/bin/?.dylib;'..ZBS..'/bin/clibs/?.dylib;' .. ZBS .. '/bin/clibs/?/?.dylib'
			package.path = package.path .. ';' .. ZBS .. '/?.lua;'
			socket = require("lualibs.socket")
		end
		local tcp = assert(socket.tcp())
		tcp:connect(host, port);
		tcp:send(msg);
		-- TODO: tcp不能立刻关闭，要确保连接已经建立后才能关闭.
		-- tcp:close()
	end
	print("sendTCP")
	sendTCP("Hi,I m Ready, Now you can start WinShell(服务器已就绪)")
end
