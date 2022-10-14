local box = L("box", {})
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local state = require "editor.state"
local data_state = require "editor.dataState"
local globalSetting = require "editor.setting.global_setting"
local Timer
local showSetting = true
local function setting(entity_obj, id)
    if Timer then
        Timer()
        Timer = nil
    end
    Blockman.Instance():saveMainPlayer(Player.CurPlayer)
    local entity = entity_obj:getEntityById(id)
	local pos = entity_obj:getPosById(id)
	Lib.emitEvent(Event.EVENT_ENTITY_SETTING, id, pos)
    Timer = UILib.uiFollowObject(UI:getWnd("mapEditEntitySetting"):root(), entity.objID, {
        anchor = {
            x = -0.4,
            y = 0.5
        },
    	offset = {
    		x = 0,
    		y = 0,
    		z = 0
    	},
        minScale = 0.7,
        maxScale = 1.2,
        autoScale = true,
        canAroundYaw = false
    })
    
end

local function changeActor(entity_obj, id, actorName, openUI)
	local pos = entity_obj:getPosById(id)
	local entity = entity_obj:getEntityById(id)
	if not entity then
		return
	end
	local entityObject = EntityClient.CreateClientEntity({cfgName = actorName, pos = {
		x = pos.x,
		y = pos.y,
		z = pos.z
	}})
	entity_obj:setEntityById(id, entityObject)
	if openUI == true then
		if showSetting then
			World.Timer(1, function()
				setting(entity_obj, id)
			end)
		end
	end
end


function box.click(entity_obj, id)
	setting(entity_obj, id)
end

function box.getType(entity_obj, id)
	return "box"
end

function box.add(entity_obj, id, derive)
	local teamID = derive.teamID
	if teamID then
		changeActor(entity_obj, id, "myplugin/npc_chest_team", true)
	end
end

function box.load(entity_obj, id)
	showSetting = false
	local derive = entity_obj:getDataById(id)
	box.changeTeamId(entity_obj, id, derive, true)
	showSetting = true
end

function box.changeTeamId(entity_obj, id, derive, openUI)
	local findID = false
	local teamInfo = globalSetting:getTeamMsg()
	local teamID = derive.teamID
	for _, info in pairs(teamInfo or {}) do
		if info.id == teamID then
			findID = true
		end
	end
	if not findID then
		derive.teamID = nil
		changeActor(entity_obj, id, "myplugin/npc_chest", openUI)
	end
end

function box.replaceTable(entity_obj, id, derive, obj)
	entity_obj:setDataById(id, obj)
	local teamID = obj.teamID
	if teamID then
		changeActor(entity_obj, id, "myplugin/npc_chest", true)
	end
end

function box.setTeamID(entity_obj, id, derive, value)
	local lastTeamID = derive.teamID
	derive.teamID = value
	if (lastTeamID and not value ) or (not lastTeamID and value ) then
		local actorName = value and "myplugin/npc_chest_team" or "myplugin/npc_chest"
		changeActor(entity_obj, id, actorName, true)
	end
end

function box.getTeamID(entity_obj, id, derive, value)
	return derive.teamID
end

function box.openSettingUI(entity_obj, id, derive)
	UI:openMultiInstanceWnd("mapEditTabSetting", {
			labelName = {
			{
                leftName = "editor.ui.bindTeam",
                wndName = "CurrentyTeam"
            }
		},
		data = id
	})
end

RETURN(box)
