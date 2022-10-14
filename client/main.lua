local misc = require "misc"

print("Start client script!", World.GameName)



World.isClient = true

require "common.profiler"
require "common.profiler_lib"

--if CGame.Instance():isDebuging() then
--	Profiler:init()
--end
require "common.api.api_proxy"

require "common.data_cache_container"
require "common.lib"
require "common.zipfile"
require "common.os_locale"
require "common.math.math"
require "common.define"
require "client.define"
require "instance"
require "common.object"
if IS_EDITOR then
	require "common.data_link"
end

if not DataLink.useDataLink or not DataLink:useDataLink() then
  require "common.vfs"
  VFS:start()
end
require "common.execuserscript"
require "input_system"
require "stage"
require "debug_draw"
require "draw_render"
require "grid_render"

-- 已在common.os_locale处理
--os.setlocale(".UTF-8")

---@type LuaTimer
local LuaTimer = T(Lib, "LuaTimer")
LuaTimer:cancelAll()

Blockman.instance = Blockman.Instance()
CGame.instance = CGame.Instance()
GUISystem.instance = GUISystem:Instance()
GUIWindowManager.instance = GUIWindowManager:Instance()
TextureAtlasRegister.instance = TextureAtlasRegister.Instance()
SoundSystem.instance = SoundSystem.Instance()
CGame.instance:setInstanceRenderingFilterList({ "SM-J7008" })

---@type setting
local setting = require "common.setting"
require "ui.cegui_window_init"
require "resloader"
ResLoader:loadCoreResources()

GameReport = require "common.game_report"

require "common.packet_convert"
require "common.vars"
require "event"
require "event.event"
require "common.trigger"
require "world.world"
ResLoader:addGame(World.GameName)
ResourceGroupManager:Instance():setSearchLowerCase(not (World.cfg.resSearchLowerCase == false))
ResourceGroupManager:Instance():setSearchPureName(not (World.cfg.resSearchPureName == false))
FileResourceManager:Instance():setSearchPureName(not (World.cfg.resSearchPureName == false))

require "object.object"
require "entity.entity"
require "player.player"
require "player.player_move"
require "game_team"
require "common.item"
require "common.tray"
require "item.dropitem"
require "missile.missile_client"
require "common.block"
require "skill.skill"
require "lang"
require "coin"
require "shop"
require "game"
require "common.game"
require "commodity"
require "ui.init"
require "common.cache.user_info_cache"
require "rank"
require "clientsetting"
require "client"
require "shader"
require "common.physics"

require "ui.ui_def"
require "ui.gui_lib"
require "ui.ui_handler"
require "ui.ui_udim"
require "ui.ui_udim2"
require	"ui.ui_manager"
require "ui.ui_schedule"
require "ui.ui_event"
require "ui.ui_lib"
require "ui.ui_show_manage"
require "ui.ui_sound"
require "ui.ui_stack_manager"
require "ui.windows.win_base"
require "ui.ui_animation.ui_animation_manager"
require "frontsight"
require "composition"
require "store"
require "friend_manager"
require "world.scene_ui_manager"
require "gm"
require "shell_interface"
require "function_setting"
require "world.map_event"
require "common.map_patch_mgr"
require "common.singleShop"
require "game_analytics"
require "game.game_over"
require "package_handlers"
require "audio_engine_event"
require "audio_engine_mgr"
require "common.scene_handler"
require "autotest.autotest"
require "common.scene_lib"
require "view_bobbing_mgr"

--[[if CGame.instance:getIsEditorEnvironment() then
	require "editor.module.editorModule"
end]]--
require "voice.voice_manager"
require "voice.fmod_dsp"
require "common.combination_block"
require "common.plugins"
require "common.check_assistant"
require "shop.player_shop"
require "shop.shop"
require "ui.ui_queue"
require "cinemachine"
require "world.scene.scene_lib"
require "recorder.recorder"

local guiMgr = L("guiMgr", GUIManager:Instance())

require "common.actions.actions_game"
require "common.actions.actions_lib"
require "common.actions.actions_var"
require "actions.actions"
if guiMgr and guiMgr:isEnabled() then 
	require "actions.actions_event"
	require "actions.actions_ui"
	require "actions.actions_actorWindow"
	require "actions.actions_button"
	require "actions.actions_checkBox"
	require "actions.actions_editBox"
	require "actions.actions_effectWindow"
	require "actions.actions_image"
	require "actions.actions_progressBar"
	require "actions.actions_radioButton"
	require "actions.actions_scrollableView"
	require "actions.actions_slider"
	require "actions.actions_text"
	require "actions.actions_var"
	require "actions.actions_UDim2"
end
require "common.actions.actions_trigger"


local guide = require "guide.guide"
local lfs = require "lfs"
local quality = require "world.quality"
require "common.util.file_util"

local document_path = Root.Instance():getRootPath() .. "document"
if lfs.attributes(document_path, "mode") ~= "directory" then
	lfs.mkdir(document_path)
end

if IS_EDITOR then
	local PartStorage = require "common.service.part_storage"
	PartStorage.Init()
end

MapPatchMgr.CheckDealWithMapPatch()
Lang:init()
Clientsetting:init()
FunctionSetting:init()
UIMgr.UIShowManage:init()

Game.InitTeamCfg()

if World.cfg.enableUIAnimation then
	local UIAnimationManager = T(UILib, "UIAnimationManager")
	UIAnimationManager:init()
end

UserInfoCache.Init()
FriendManager.Init()
Rank.Init()
AsyncProcess.Init()

ResLoader:loadGameResources()
if getmetatable(Blockman.Instance())["initGameAnalyticsSecretKey"] and
		getmetatable(Blockman.Instance())["postGameAnalyticsRequest"] then
	GameAnalytics.Init()
end

local debugport = require "common.debugport"
debugport.Init(Root.Instance():getWriteablePath() .. "debug_history.txt", 6661, 6666)

require "client.api.manger"

function on_init_game()
		if World.cfg.cameraDistanceMax then
				Blockman.instance:setCameraViewDistanceMax(tonumber(World.cfg.cameraDistanceMax))
		end
		if World.cfg.cameraDistanceMin then
				Blockman.instance:setCameraViewDistanceMin(tonumber(World.cfg.cameraDistanceMin))
		end
end

function handle_input(frameTime)
	CPUTimer.StartForLua("handle_input")
	PlayerControl.UpdateControl(frameTime)
	Instance.runAllMoveNodeTick()
	CPUTimer.Stop()
end

function key_event(name, state)
	if state then
		Lib.emitEvent(Event.EVENT_WIN_KEY_DOWN, name)
	else
		Lib.emitEvent(Event.EVENT_WIN_KEY_UP, name)
	end
end

function on_quality_level_change(level)
	Lib.emitEvent(Event.EVENT_QUALITY_LEVEL_CHANGE, level)
end

function handle_tick(frameTime)
	CPUTimer.StartForLua("handle_tick")

		CPUTimer.StartForLua("World.Tick()")
			World.Tick()
		CPUTimer.Stop()

		if Me and Me.onTick then
			CPUTimer.StartForLua("Me:onTick(frameTime)")
				Me:onTick(frameTime)
			CPUTimer.Stop()
		end
		local LuaTimer = T(Lib, "LuaTimer")

		CPUTimer.StartForLua("LuaTimer:onTick(frameTime)")
			LuaTimer:onTick(frameTime)
		CPUTimer.Stop()

		CPUTimer.StartForLua("debugport.Tick()")
			debugport.Tick()
		CPUTimer.Stop()

		CPUTimer.StartForLua("guide.Tick()")
			guide.Tick()
		CPUTimer.Stop()

		CPUTimer.StartForLua("quality.Tick()")
			quality.Tick()
		CPUTimer.Stop()

		CPUTimer.StartForLua("UIMgr.Tick()")
			UIMgr.Tick()
		CPUTimer.Stop()

	CPUTimer.Stop()
end

function handle_render_tick(frameTime, interpolationFraction)
	if Me and Me.handleCameraTick then
		Me:handleCameraTick(frameTime)
	end
end

function on_exit_game(isNetConnected)
	if isNetConnected then
		quality:PerformanceReport()
	end
end

if Blockman.instance.singleGame then
	-- 尝试开启单机模式
	if not IS_EDITOR then
        package.loaded["single"] = nil
		require "single"
	end
end

function release_game()
	debugport.Uninit()
	Profiler:reset()
end

--临时方案 之后用图集导出
local function load_images()
	if not CEGUIImageManager:getSingleton() or World.cfg.disableInitImagesets then	-- 判断是否是旧UI系统
		return
	end

	local PATH_GAME = Root.Instance():getGamePath()
	local Lfs = require "lfs"

	local block_texture_dir = Lib.combinePath(PATH_GAME,"asset/")
	local ret = Lfs.attributes(block_texture_dir,"mode")
	if not ret or ret ~= "directory" then
		return
	end
	for item in Lfs.dir(block_texture_dir) do
		if item ~= "." and item ~= ".." then
			local strs = Lib.splitString(item,".")
			if strs[2] == "png" then
				local filePath = "asset/"..item
				local resGroup = "gameres"
				GUILib.loadSingleImage(filePath, resGroup)
			end
		end
	end
	local asset_dir = Lib.combinePath(PATH_GAME, "asset") .. '/'
	local dir_list = {}
	Lib.getSubDirs(asset_dir, dir_list)
	for _, dir in pairs(dir_list) do
		for item in Lfs.dir(asset_dir..dir) do
			if item ~= "." and item ~= ".." then
				local strs = Lib.splitString(item,".")
				if strs[2] == "png" then
					--local path = string.sub(dir,#asset_dir + 1,#dir)
					local filePath = "asset/"..dir.."/"..item
					local resGroup = "gameres"
					GUILib.loadSingleImage(filePath, resGroup)
				end
			end
		end
	end
end

if not World.cfg.disLoadAssetImage then
	load_images()
end


--请求是否是国内版标志
Interface.onAppActionTrigger(15)
Plugins.LoadAllPlugins()
Plugins.LoadPlugin("tween")

if not IS_EDITOR then
	local pluginManager = require "common.plugin_manager"
	pluginManager:loadGamePlugins()
end

local t0 = os.time()
collectgarbage()
print("collectgarbage cost", os.time() - t0)


if CGame.instance:getIsEditorEnvironment() then
	--local manager = require "editor.edit_record.manager"
	--manager:init()
end

-- World.Timer(1000, function()
-- 	local obj = GizmoTransformMove:create()
-- 	local manager = World.CurWorld:getSceneManager()
-- 	manager:setGizmo(obj)
-- 	obj:setPosition({x = 26, y = 52, z = 59})
--   end)