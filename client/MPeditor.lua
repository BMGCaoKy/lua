require "single"
require "editor.proto"
local input = require "editor.input"
local view = require "editor.view"
local map_setting = require "editor.map_setting"
local region_obj = require "editor.obj"
local blockVector_obj = require "editor.blockVector_obj"
local entity_obj = require "editor.entity_obj"
local item_obj = require "editor.item_obj"
local engine = require "editor.engine"
local memoryfile = require "memoryfile"
local data_state = require "editor.dataState"
local network_mgr = require "network_mgr"
local globalSetting = require "editor.setting.global_setting"

local bm = Blockman.Instance()

local ticks = 0 
function PlayerControl.UpdateControl()
	ticks = ticks + 1
	if ticks == 1 then
		input:update()
		EditorModule:emitEvent("BOUND_CHANGE", {x = 0, y = 0, z = 0})
		view:mpUpdate()
		local viewControl = EditorModule:getViewControl() 
		if viewControl then
			viewControl:tick()
		end
		ticks = 0
	end
end

World.CurWorld.canPushable = false

--bm.gameSettings.cameraYaw = Player.CurPlayer:getBodyYaw() - 90
bm:control().enable = false

Lib.emitEvent(Event.EVENT_CHANGE_MAP_MODE)

map_setting:load()
map_setting:set_pos()
region_obj:load()
entity_obj:load()
item_obj:load()

bm.gameSettings.hideFog = true
bm:setRenderBoxEnable(true)



local function switchPlayerView()
	local isThirdView = globalSetting:getIsThirdView()
	if isThirdView then
		EditorModule:getMoveControl():switchThirdMoveWay(true)
	else
		EditorModule:getMoveControl():switchFristMoveWay(true)
	end
end

World.Timer(1,function()
	switchPlayerView()
end)

World.Timer(20,function()
	for i = 0, -1 do
		EditorModule:getViewControl():changeViewCfg(i, {
			lockViewPos = true	
		})
		
	end
	switchPlayerView()
end)

--CGame.instance:onEditorDataReport("enter_editor_success", "")
--local guideInfo = Clientsetting.getGuideInfo()
--if not guideInfo then 
--	local res = network_mgr:get_client_cache({"isNewAcc", "isGuideStage", "isGuideTools", "isRemind", "isPathRemind", "isAreaRemind", "isOpenGuide"})
--	if res.ok then
--		Clientsetting.setGuideInfo("isNewAcc", not(res.ret.list[1] and (tonumber(res.ret.list[1]) or 0) == 1), true)
--		Clientsetting.setGuideInfo("isGuideStage", not(res.ret.list[2] and (tonumber(res.ret.list[2]) or 0) == 1), true)
--		Clientsetting.setGuideInfo("isGuideTools", not(res.ret.list[3] and (tonumber(res.ret.list[3]) or 0) == 1), true)
--		Clientsetting.setGuideInfo("isRemind", not(res.ret.list[4] and (tonumber(res.ret.list[4]) or 0) == 1), true)
--		Clientsetting.setGuideInfo("isPathRemind", not(res.ret.list[5] and (tonumber(res.ret.list[5]) or 0) == 1), true)
--		Clientsetting.setGuideInfo("isAreaRemind", not(res.ret.list[6] and (tonumber(res.ret.list[6]) or 0) == 1), true)
--		Clientsetting.setGuideInfo("isOpenGuide", not(res.ret.list[7] and (tonumber(res.ret.list[7]) or 0) == 1))
--		CGame.instance:setNetworkState(true)
--	else
--		CGame.instance:setNetworkState(false)
--	end
--end

if Clientsetting.isKeyGuide("isNewAcc") then
    Lib.emitEvent(Event.EVENT_EDIT_OPEN_GUIDE_WND, 1)
    Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,9) 
end

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

local io_open = io.open
io.open = function(path, mod)
path = string.gsub(string.gsub(path, "\\", "/"), "(/+)", "/")
	repeat
		if mod and string.sub(mod, 1, 1) ~= 'r' then
			break
		end

		if not engine:check_mem_file(path) then
			break
		end

		local ret = memoryfile.open(path, "r")
		if  not ret then
			break
		end

		return ret
	until(true)
	
	return io_open(path, mod)
end

RETURN()
