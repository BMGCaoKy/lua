print("Start Editor Script!", World.GameName)

IS_EDITOR = true

require "common.preload"
require "main"
local rootpath = Root.Instance():getRootPath()
package.path = rootpath .. [[lua/client/editor/3rd/lanes/?.lua;]] .. rootpath .. [[lua/client/editor/3rd/luasec/?.lua;]] .. rootpath .. [[lua/client/editor/3rd/?.lua;]] .. package.path

local Lfs = require "lfs"
local Setting = require "common.setting"

local Def = require "editor.def"

local Signal = require "editor.signal"
local Meta = require "editor.gamedata.meta.meta"
local TreeSet = require "editor.gamedata.vtree"

local Mapping = require "editor.gamedata.module.mapping"
local Lang = require "editor.gamedata.lang"
local Module = require "editor.gamedata.module.module"

local GameRequest = require "editor.proto.request_game"

-- init base
Signal:init()
Meta:init()
TreeSet:init()

-- init data
Mapping:init()
Lang:init()
Module:init()

Module:preprocess()

Mapping:load()
Lang:load()
Module:load()


-- ʱ�侲ֹ
local world = World.CurWorld
world:setTimeStopped(false)
world:setWorldTime(1)

-- control
local bm = Blockman.Instance()
bm:setPersonView(0)
bm:setReachDistance(65)
bm:control().enable = false

CGame.instance:setGetServerInfo(true);

if not DataLink:useDataLink() then
	VFS:start()
end

-- tmp
require "editor.proto"


	Lang:init()
	Clientsetting:init()
	UIMgr:init()

	Rank.Init()
	AsyncProcess.Init()

	ResLoader:loadGameResources()

	local debugport = require "common.debugport"
	debugport.Init(Root.Instance():getWriteablePath() .. "debug_history.txt", 6661, 6666)

	function handle_input()
		PlayerControl.UpdateControl()
	end

	function handle_tick(frameTime)
		World.Tick()
		debugport.Tick()
		guide.Tick()
		if Worker then
			Worker:Tick()
		end
	end

	function release_game()
		debugport.Uninit()
	end

	require "editor.proto"
-- override
PlayerControl.UpdateControl = function(frame_time)
	local input = require "editor.input"
	local view = require "editor.view"

	input:update(frame_time)
	view:update()
end

-- override
World.Map.loadSingle = function()
end

-- override
start_single = function()

end

World.Timer(1, function()
	local Map = require "editor.map"
	Map:init()
	Map:load()
end)

Lib.subscribeEvent(Event.EVENT_SINGLE_START_FINISH, function()
	Lib.emitEvent(Event.EVENT_CLOSE_ALL_WND)
	UI.openWnd = function()
	end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_DATA_MODIFIED, function(module, item)
	GameRequest.request_modify_flag(true, module, item)
end)


-- tmp need move to 
function gizmo_event_begin()
	Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_START)
	print("EVENT_EDITOR_GIZMO_DRAG_START")
end

function gizmo_event_move(originalPos, offset)
	--originalPos.x = math.ceil(originalPos.x - 0.5)
	--originalPos.y = math.ceil(originalPos.y - 0.5)
	--originalPos.z = math.ceil(originalPos.z - 0.5)
	offset.x = math.ceil(offset.x - 0.5)
	offset.y = math.ceil(offset.y - 0.5)
	offset.z = math.ceil(offset.z - 0.5)
	Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_MOVE, originalPos, offset)
	print("EVENT_EDITOR_GIZMO_DRAG_MOVE")
end

function gizmo_event_end(originalPos, offset)
	--originalPos.x = math.ceil(originalPos.x - 0.5)
	--originalPos.y = math.ceil(originalPos.y - 0.5)
	--originalPos.z = math.ceil(originalPos.z - 0.5)
	offset.x = math.ceil(offset.x - 0.5)
	offset.y = math.ceil(offset.y - 0.5)
	offset.z = math.ceil(offset.z - 0.5)
	Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_END, originalPos, offset)
	print("EVENT_EDITOR_GIZMO_DRAG_END")
end


function scaler_event_begin()
	Lib.emitEvent(Event.EVENT_EDITOR_SCALER_DRAG_START)
	print("EVENT_EDITOR_SCALER_DRAG_START")
end

function scaler_event_move(positive, reverse)
	Lib.emitEvent(Event.EVENT_EDITOR_SCALER_DRAG_MOVE, positive, reverse)
	print("EVENT_EDITOR_SCALER_DRAG_MOVE")
end

function scaler_event_end(positive, reverse)
	Lib.emitEvent(Event.EVENT_EDITOR_SCALER_DRAG_END, positive, reverse)
	print("EVENT_EDITOR_SCALER_DRAG_END")
end
