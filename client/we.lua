require "common.compat.compat"
local Platform = require "common.platform"
LogUtil.setMaxMessageSize(65535)
print("Start Editor Script!", World.GameName)

IS_EDITOR = true
--require "debug_editor"

require "common.os_locale"
ActorEditor = require "we.gamedata.actor_editor"
local rootpath = Root.Instance():getRootPath()
package.path = rootpath .. [[lua/client/editor/3rd/lanes/?.lua;]] .. rootpath .. [[lua/client/editor/3rd/luasec/?.lua;]] .. rootpath .. [[lua/client/editor/3rd/?.lua;]] .. package.path

require "common.preload"
require "main"

local Lfs = require "lfs"
local Setting = require "common.setting"

local Def = require "we.def"

local Signal = require "we.signal"
local Meta = require "we.gamedata.meta.meta"
local TreeSet = require "we.gamedata.vtree"

local Mapping = require "we.gamedata.module.mapping"
local Lang = require "we.gamedata.lang"
local Module = require "we.gamedata.module.module"
local GameConfig = require "we.gameconfig"

local GameRequest = require "we.proto.request_game"

local ActorMain = require "we.sub_editors.actor_main"

local Recorder = require "we.gamedata.recorder"
local misc = require "misc"
local Scene = require "we.view.scene.scene"

local Engine = require "we.engine"
local UserData = require "we.user_data"
local Coin = require "we.gamedata.coin"
local Map = require "we.map"

-- init base
Signal:init()
Meta:init()
TreeSet:init()

-- init data
Mapping:init()
Lang:init()
Module:init()
GameConfig:init()

-- run register custom meta plugin (before Module:preprocess)
do
	local file = Lib.combinePath(Def.PATH_GAME, "plugin", Def.DEFAULT_PLUGIN, "custom_meta.lua")
	if Lib.fileExists(file) then
		dofile(file)
	end
end

Module:preprocess()

if DataLink:useDataLink() then
	GameRequest.request_original_data_preprocess()
end

Mapping:load()
Lang:load()
Module:load()
Map:init()
Map:load()

Recorder:init()

Scene:init()

-- 时间静止
local world = World.CurWorld
world:setTimeStopped(false)
world:setWorldTime(1)

-- control
local bm = Blockman.Instance()
bm:setPersonView(0)
bm:setReachDistance(65)
if bm:control() then
	bm:control().enable = false
end
bm.gameSettings:setFovSetting(UserData:get_value("camera_fov") or 1)

CGame.instance:setGetServerInfo(true);

if not CGame.instance:getIsMobileEditor() then
	require "common.data_link"
end

if not DataLink:useDataLink() then
	VFS:start()
end

-- tmp
require "we.proto"


local lastKeyState = {}

local function checkNewState(key, new)
	if lastKeyState[key] == new then
		return false
	end
	lastKeyState[key] = new
	return true
end

local function isKeyNewDown(key)
	local state = bm:isKeyPressing(key)
	return checkNewState(key, state) and state
end

local function modify_save()
	if DataLink:useDataLink() then
		Module:save()
		Lang:save()
		Mapping:save()
		Engine:save_all_map()
		UserData:save()
		Coin:save()
	end
end

-- override
PlayerControl.UpdateControl = function(frame_time)
	-- 通知编辑器切换OpenGL上下文
	--GameEnv:Instance():LeaveGame()
	Scene:update(frame_time)
	Signal:clean()
	-- 通知编辑器还原OpenGL上下文
	--GameEnv:Instance():EnterGame()
end

-- override
World.Map.loadSingle = function()
end

-- override
start_single = function()

end

local cjson = require "cjson"
-- override
Lib.read_file = function(path, raw)
	local file, errmsg = io.open(path, "rb", raw)
	if not file then
		--print("[Error]", errmsg)
		return nil
	end
	local content = file:read("a")
	file:close()

	-- remove BOM
	local c1, c2, c3 = string.byte(content, 1, 3)
	if (c1 == 0xEF and c2 == 0xBB and c3 == 0xBF) then	-- UTF-8
		content = string.sub(content, 4)
	elseif (c1 == 0xFF and c2 == 0xFE) then	-- UTF-16(LE)
		content = string.sub(content, 3)
	end

	return content
end

Lib.read_json_file = function(path, raw)
	local content = Lib.read_file(path, raw)
	if content then
		local ok, ret = pcall(cjson.decode, content)
		assert(ok, path)
		return ret
	end
end

Lib.read_lang_file = function(path, raw)
	local file, errmsg = io.open(path, raw)
	if not file then
		print(errmsg)
		return false
	end
	local content = file:read("a")
	file:close()
	local strs = Lib.splitString(content, "\n")
	local res = {}
	for _, i in pairs(strs) do
		if i:sub(-1) == "\r" then
			i = i:sub(1,-2)
		end
		local k, v = string.match(i,"^([^=%s]*)%s*=%s*(.*)$")
		if k and v then
			res[k] = v:gsub("\\n", "\n")
		end
	end
	return res
end

Lib.readGameJson = function(path)
	return Lib.read_json_file(Root.Instance():getGamePath() .. path)
end

Lib.read_csv_file = function(path, ignore_line, raw)
	local csvLine = {}
	local file = io.open(path, "rb", raw)
	if not file then
		return nil
	end

	local content = file:read("a")
	file:close()
	content = misc.read_text(content)
	local key, pos = misc.csv_decode(content)
	local line = {}
	local line_number = 1
	while pos do
        line, pos = misc.csv_decode(content, pos)
		line_number = line_number + 1
		if not ignore_line or line_number > ignore_line then
			local t = {}
			if line then
				for k,v in pairs(line) do
					t[tostring(key[k])] = v
				end
				table.insert(csvLine, t)
			end
		end
	end
	return csvLine, key
end

World.Timer(1, function()
	local guiMgr = GUIManager:Instance()
	guiMgr:getRootWindow():hide()

	-- plugin
	local lua_name = "editor_plugin.lua"
	local list = {}
	local dir = Lib.combinePath(Def.PATH_GAME, "plugin")
	for name in Lfs.dir(dir) do
		if name ~= "." and name ~= ".." then
			local path = Lib.combinePath(dir, name)
			local attr = Lfs.attributes(path)
			if attr.mode == "directory" then
				local file = Lib.combinePath(path, lua_name)
				if Lib.fileExists(file) then
					table.insert(list, file)
				end
			end
		end
	end

	for _,v in ipairs(list) do
		dofile(v)
	end
	--pcall(require, "we.plugin.init")
end)

World.Timer(20 * 60 * 5, function()
	if ( Root.platform() == Platform.WINDOWS ) then
    	local mi = misc.win_memory_info()
    	Lib.pv(mi)
  	end
	return true
end)

Lib.subscribeEvent(Event.EVENT_SINGLE_START_FINISH, function()
	Lib.emitEvent(Event.EVENT_CLOSE_ALL_WND)
	UI.openWnd = function()
	end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_DATA_MODIFIED, function(module, item)
	modify_save()
	GameRequest.request_modify_flag(true, module, item)
end)

-- 用于搜索 conf 中的资源
ResourceGroupManager:Instance():addResourceLocation(
	"./",
	"conf/asset",
	"FileSystemIndexByPath"
)

ActorMain:init()
Blockman.instance.gameSettings:setBlockSectionDealwithDirtyRadiusToView(1024)

DebugDraw.instance:setEnabled(true)
DebugDraw.instance:setDrawSelectedPartAABBEnabled(true)
