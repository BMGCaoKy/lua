-- 所有全局变量在此定义
-- 注1：非独立模块一般不应该建立自己的全局变量
-- 注2：c++导出的对象会产生一些全局变量，不受限制
--print(":::::::::::::::::::::::::::::::::::startFromWorldEditor:::::::::::::::: ",os.getenv("startFromWorldEditor") )
local searchPath = Root.Instance():getGamePath():gsub("\\", "/") .. "lua/?.lua"
local searchGamePath = Root.Instance():getGamePath():gsub("\\", "/") .. "?.lua"
package.path = package.path .. ";" .. searchPath .. ";" .. searchGamePath
local mobdebug
-- macOS增加lua调试功能
if os.getenv("luadbg") or os.getenv("startFromWorldEditor") and not IS_EDITOR  then
	mobdebug = require "common.luaidedebug"
end

Enum = {}
Lang = {}
UIMgr = {}
UI = {}
UIEvent = {}
Color3 = {}
UDim = {}
UDim2 = {}
Me = {} ---@type EntityClientMainPlayer
WinBase = {}
UILib = {} ---@class UILib
GUILib = {}
Loader = {}
Loadersetting = {}

loadingUiPage = false
IS_EDITOR = IS_EDITOR or false

ResLoader ={}
Clientsetting = {}
FunctionSetting = {}
Client = {}
FrontSight = {}
VoiceManager = {}
SceneLib = {}
ActionsLib = {}
FileUtil = {}
FmodDsp = {}

Sound3DRollOffType = {
	INVERSE        = 0x00100000,
	LINEAR         = 0x00200000,
	LINEARSQUARE   = 0x00400000,
	INVERSETAPERED = 0x00800000,
	CUSTOM         = 0x04000000,
}

Packet = {}
emmy = {}
Config = {}
---@class BigInteger
BigInteger = {}
Profiler = {}
ProfilerLib = {}
---@class Lib
Lib = {}
Block = {}
Skill = {}
Event = {}
DataCacheContainer = {}
Game = {}
Item = {}
Tray = {}
Define = {}
Shop = {}
Coin = {}
Commodity = {}
SingleShop = {}
Session = {}
Rank = {}
AsyncProcess = {}
UserInfoCache = {}
GameAnalytics = {}
Vars = {}
Player = {}
Composition = {}
RewardManager = {}
ReportManager = {}
FriendManager = {}
PartyManager = {}
SceneUIManager = {}
Stage = {}
GM = {}
VFS = {}
VFS2 = {}
DataLink = {}
ItemDataUtils = {}
ExecUserScript = {}
Store = {}
Trade = {}
Interface = {}
Building = {}
CombinationBlock = {}
WaterMgr = {}
LavaMgr = {}
MapPatchMgr = {}
AudioEngineMgr = {}
EditorModule = {}
PackageHandlers = {}
Plugins = {}
UDim = {}
UDim2 = {}
Region = {}
GameReport = {}

SceneHandler = {}

MoveNode = {}

MapChunkMgr = {}


AT = {}

ViewBobbingMgr = {}
ResLoader ={}

CollidableType = {}

-- foreign
Engine = {}
Global = {}

Enum = {}

MobileEditor = {}

APIProxy = {}
Debug = {}

IS_UGC_ENGINE = false
IS_TESTCLIENT = IS_TESTCLIENT or false
if not IS_TESTCLIENT then
	ENGINE_VERSION = EngineVersionSetting.getEngineVersion()
	IS_UGC_ENGINE = (math.floor(ENGINE_VERSION / 10000) == 3) or (math.floor(ENGINE_VERSION / 10000) == 7)
end

globalValue = false
asyncLoadLayoutDone = false

handle_packet = false
handle_trigger = false
handle_input = false
handle_tick = false
handle_render_tick = false
on_exit_game = false
server_event = false
client_event = false
map_event = false
block_event = false
object_call = false
entity_event = false
player_event = false
interaction_event = false
missile_event = false
start_single = false
on_init_game = false
ui_event = false
window_event = false
ui_global_event = false
scene_event = false
part_operation_event = false

audio_engine_event = false
loadingPage = false
key_event = false
on_quality_level_change = function() end
handle_createplayer = false
player_touchdown = false
release_manor = false
handle_editor_command = function()
	error("not in edtior mode")
end
handle_mp_editor_command = false

scene_ui_load_layout = false
scene_ui_unload_layout = false
get_collision_data_path_by_key = false
initializeFastTable = false

local on_error_table = {}

trigger_exec_type = {}

--[[
function destroy_object(obj)
	print("destroy", obj)
	obj:destroy()
end
--]]

function mark_remove_instance(instance)
	instance.removed = true
end

function remove_instance(instance)
	Instance.clearData(instance)
end

function on_error(...)
	for _, func in pairs(on_error_table) do
		func(...)
	end
end

function on_error_reg(name, func)
	on_error_table[name] = func
end

gizmo_event_begin = function() end
gizmo_event_move = function() end
light_gizmo_event_move = function() end
gizmo_event_end = function() end
scaler_event_begin = function() end
scaler_event_move = function() end
scaler_event_end = function() end

release_game = false
load_images = false

class = false
classof = false

debug_draw_lua_render = false
draw_lua_render = false
grid_lua_render = false

showErrorMessage = function()  end

onConnectorMsgHandler = function(...)  end

RETURN = coroutine.yield

if IS_EDITOR then
	ExecUserScript.IS_EDITOR = true
end
------------------------------ 全局变量定义 end

---在新引擎最开始意外开启了Lua 5.2库的支持，现已关闭。为保持兼容，提供常用的2个Lua 5.2函数
function math.pow(x, y)
	return x ^ y
end

math.atan2 = math.atan

---模块私有机制 begin
---运行时当前模块环境
RunTimeModule = ""
---开始某个table的模块私有定义
function BeginModulePrivateDefinition(tb,moduleName)
	tb.curDefinitionMod = moduleName
end
---设置某个table为模块私有模式
function MakeTbModulePrivate(tb)
	tb.modDefinitionDic = {}
	tb.curDefinitionMod = ""
	local mt = {
		__newindex = function(self,key,value)
			if type(value) == "function" then
				local func = function(...)
					local isExport = string.find(key,'export_')
					if RunTimeModule == "" or isExport or tb.modDefinitionDic[key]==RunTimeModule then
						RunTimeModule = tb.modDefinitionDic[key]
						return value(...)
					else
						perror("Module Function Only is Private!!")
					end
				end
				table.insert(tb.modDefinitionDic[key],tb.curDefinitionMod)
				rawset(self,key,func)
			else
				rawset(self,key,value)
			end
		end
	}
	setmetatable(tb,mt)
end
---模块私有机制 end
---@param tb table
---@param key string
---@param value table
---@return table
function T(tb, key, value)
	local ret = tb[key]
	if ret~=nil then
		return ret
	end
	if value==nil then
		value = {}
	end
	tb[key] = value
	return value
end

local oldLuaLoader = package.searchers[2]
local lfs = require("lfs")
local filelist = T(package, "filelist")
local localTable = nil

---@param key string
---@param value any
---@return any
function L(key, value)
	if key==nil then
		return localTable
	end
	if not localTable then
		return value
	end
	local v = localTable[key]
	if v==nil then
		return value
	end
	return v
end

local function luaLoader(mod)
	local func, path = oldLuaLoader(mod)
	if not path then
		return func
	end

	local func2 = function()
		if mobdebug then
			mobdebug.on()
		end
		local func3 = func()
		if mobdebug then
			mobdebug.off()
		end
		return func3
	end
	if string.sub(path, 1, 1) == "@" then
		path = string.sub(path, 2)
	end
	local ft = filelist[mod]
	local oldCo = ft and ft.load
	local oldLT = localTable
	if oldCo then
		localTable = {}
		for i = 1, 999 do
			local k, v = debug.getlocal(oldCo, 1, i)
			if not k then
				break
			end
			localTable[k] = v
		end
	else
		localTable = nil
	end
	local co = coroutine.create(func2)
	local ok1, ok2, ret = pcall(coroutine.resume, co, mod, path)
	localTable = oldLT
	if not ok1 then
		error(traceback(co, ok2), 0)
	end
	if not ok2 then
		error(traceback(co, ret), 0)
	end
	if coroutine.status(co)=="dead" then
		co = nil
	end
	filelist[mod] = {
		path = path,
		time = lfs.attributes(path, "modification"),
		load = co,
	}
	return function() return ret end, path
end

package.searchers[2] = luaLoader

local mt = {}
function mt:__index(name)
	local isok = true
	-- 使用插件调试，查询不存的全局变量，会导致程序崩溃
	-- 开启下方代码就可以避免
	-- if debug and debug.getinfo  then
	-- 	local  info = debug.getinfo(1)
	-- 	if "hook" == info.namewhat then
			-- isok = false
	-- 	end
	-- end
	if isok and Lib.logError then
		Lib.logError("GET_GLOBAL!!!", name)
	end
	error("attempt to get undefined global variable \"" .. name .. "\". wrong global value name?!", 2)
end
function mt:__newindex(name, value)
	if Lib.logError then
		Lib.logError("SET_GLOBAL!!!", name, value)
	end
	error("attempt to create global variable \"" .. name .. "\"", 2)
end

setmetatable(_G, mt)
