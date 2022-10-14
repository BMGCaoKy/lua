require "common.compat.compat"

print("Start loader script!", World.GameName)
local rootpath = Root.Instance():getRootPath()
package.path = rootpath .. "lua/libraries/?.lua;" .. rootpath .. "lua/libraries/luasocket/?.lua;" .. package.path

World.isClient = true
require "common.win_debug"
require "common.preload"
require "common.expressionCalculation"
require "common.data_cache_container"
require "common.lib"
require "common.math.math"
require "common.define"
require "common.os_locale"
require "common.zipfile"
if not IS_EDITOR then
	require "common.vfs2"
end

Blockman.instance = Blockman.Instance()
CGame.instance = CGame.Instance()
GUISystem.instance = GUISystem:Instance()
GUIWindowManager.instance = GUIWindowManager:Instance()
TextureAtlasRegister.instance = TextureAtlasRegister.Instance()
SoundSystem.instance = SoundSystem.Instance()

World.isClient = true

require "input_system"
require "event"
require "event.event"
require "lang"
require "ui.ui_def"
require "ui.cegui_window_init"
require "ui.gui_lib"
require "ui.ui_handler"
require "ui.ui_udim"
require "ui.ui_udim2"
require "ui.init"
require "ui.ui_manager"
require "ui.ui_schedule"
require "ui.ui_event"
require "ui.windows.win_base"
require "touchscreen_handler"

local document_path = Root.Instance():getRootPath() .. "document"
if lfs.attributes(document_path, "mode") ~= "directory" then
    lfs.mkdir(document_path)
end

local log_path = document_path .. "/Log"
if lfs.attributes(log_path, "mode") ~= "directory" then
	lfs.mkdir(log_path)
end

Lang:init()
UIMgr:init()

--local debugport = require "common.debugport"
--debugport.Init("debug_history_client.txt", 6661, 6666)


if Blockman.instance.singleGame then
	-- 尝试开启单机模式
	World.gameCfg = Lib.read_json_file("gameconfig.json")
	require "single"
end


local timerCalls = L("timerCalls", {})
local gameTick = L("gameTick", 0)
local function _doreg(time, call)
	if time<1 then
		time = 1
	else
		time = math.tointeger(time)
	end
	call.time = time
	local endTime = gameTick + time
	local calls = timerCalls[endTime]
	if not calls then
		calls = {}
		timerCalls[endTime] = calls
	end
	calls[#calls+1] = call
end

function Loader.Timer(time, func, ...)
	local call = {
		func = func,
		args = table.pack(...),
		--stack = traceback_only("register timer"),
		stack ="test",
		func_name = "test2"
	}
	_doreg(time, call)
	return function()
		call.func = nil
	end
end

local function _docall(call)
	if not call.func then
		return
	end
	local ok, ret = xpcall(call.func, traceback, table.unpack(call.args, 1, call.args.n))
	if not ok then
		print("SCRIPT_EXCEPTION----------------\nError call timer:", ret)
		if call.stack then
			print(call.stack)
		end
		return
	end
	if ret==true then
		_doreg(call.time, call)
	elseif type(ret)=="number" then
		_doreg(ret, call)
	end
end

local function Tick()
	gameTick = gameTick + 1
	local calls = timerCalls[gameTick]
	if calls then
		timerCalls[gameTick] = nil
		for _, call in ipairs(calls) do
			_docall(call)
		end
	end
end

function handle_tick()
    Tick()
end
