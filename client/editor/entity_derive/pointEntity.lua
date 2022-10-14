local pointEntity = L("pointEntity", {})
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local entity_obj = require "editor.entity_obj"
local global_setting = require "editor.setting.global_setting"
local entityDerive = nil
local Timer

local function emitEvent(event)  
    local pointEntity = entityDerive.pointEntity
    local opType = pointEntity.typePoint
    if UI:isOpen("mapEditPositionSetting") then
        UI:getWnd("mapEditPositionSetting"):onOpen(opType, pointEntity, false, true)
    else
         UI:openWnd("mapEditPositionSetting", opType, pointEntity, false, true)
    end
    UI:getWnd("mapEditPositionSetting"):emitEvent(event, entityDerive) 
end

local function rePlace()
    emitEvent("rePlace")
end

local function changeModel()
    --emitEvent("changeModel") --暂时还回页面
    emitEvent("openGlobal")
end

local function openGlobal()
    emitEvent("openGlobal")
end

local function del()
    emitEvent("del")
end

local uiShowList = 
            {
			    {
				    uiName = "setPosition", 
				    backFunc = rePlace
			    },
			    {
				    uiName = "changMonsterModle", 
				    backFunc = changeModel
			    },			
                {
				    uiName = "setting", 
				    backFunc = openGlobal
			    },			
                {
				    uiName = "delete", 
				    backFunc = del
			    }
		    }

local function setting(entity_obj, id)
    if Timer then
        Timer()
        Timer = nil
    end
    Blockman.Instance():saveMainPlayer(Player.CurPlayer)
    local entity = entity_obj:getEntityById(id)
	local pos = entity_obj:getPosById(id)
    entityDerive = entity_obj:getDataById(id)
    local showList = Lib.copy(uiShowList)
    local opType = entityDerive.pointEntity.typePoint
    if opType ~= 5 then
        table.remove(showList, 2)
    end
    Lib.emitEvent(Event.EVENT_ENTITY_SETTING_POINT, { 
		    objID = entity.objID, 
		    uiShowList = showList,
	    })
end

Lib.subscribeEvent(Event.EVENT_HIDE_GLOBAL_SETTING, function(isHide, opType, teamId)
        if isHide then
            UI:closeWnd("mapEditGlobalSetting")
            UI:closeWnd("mapEditTeamDetail")
            UI:closeWnd("mapEditteamDetailItemTop")
            UI:closeWnd("mapEditteamDetailItemBottom")
            for key, wnd in pairs(UI:getMultiInstanceWnds("mapEditTabSetting")) do
                UI:closeWnd(wnd)
            end
        else
            UI:closeWnd("mapEditEntityPosUI")
            if opType == 1 or opType == 2 then
                UI:openWnd("mapEditGlobalSetting", 3)
            elseif opType == 7 then
                UI:openWnd("mapEditGlobalSetting", 2)
            elseif opType == 8 then
                UI:openWnd("mapEditGlobalSetting", 4)
            else
                local team = global_setting:getTeamMsg() or {}
                UI:openWnd("mapEditGlobalSetting", 3, true)
                UI:openWnd("mapEditTeamDetail", #team, teamId)
            end
        end
    end)

Lib.subscribeEvent(Event.EVENT_CHANGE_TEAM_COLOR, function(color, teamId)
    local entitys = entity_obj:getEntitysByDeriveTypeAndTeamID({1, 2, 3, 4, 7}, teamId)
    local icons = {
        ["BLUE"] = "image/icon/team_blue.png",
        ["RED"] = "image/icon/team_red.png",
        ["YELLOW"] = "image/icon/team_yellow.png",
        ["GREEN"] = "image/icon/team_green.png",
    }
    local icon = icons[string.upper(color)] or ""
    for i, entity in pairs(entitys) do
        entity:showHeadPic(icon)
    end
end)

function pointEntity.add(entity_obj, id, derive, pos, _table)
    pointEntity.showTeamPic(entity_obj, id, derive, true)
end

function pointEntity.settingWnd(entity_obj, id, derive)

end

function pointEntity:del(id)
	
end

function pointEntity.getType()
    return "pointEntity"
end

function pointEntity.click(entity_obj, id)
    setting(entity_obj, id)
end

function pointEntity:load(id, pos)
	local entity = entity_obj:getEntityById(id)
	local derive = entity_obj:getDataById(id)
    --setHeadText(entity, derive)
    pointEntity.showTeamPic(entity_obj, id, derive, true)
end

function pointEntity.setTeamPic(entity, derive)
	local data = derive.pointEntity or {}
	local teamId = data.teamId
	if not teamId then
		return
	end
    local team = global_setting:getTeamMsg() or {}
    local color = team[teamId] and team[teamId].color
    local icons = {
        ["BLUE"] = "image/icon/team_blue.png",
        ["RED"] = "image/icon/team_red.png",
        ["YELLOW"] = "image/icon/team_yellow.png",
        ["GREEN"] = "image/icon/team_green.png",
    }
    local picPath = icons[color]
    if not picPath then
		picPath = "image/icon/bubbling.png"
	end
	entity:showHeadPic(picPath)
end

function pointEntity.showTeamPic(entity_obj, id, derive, value)
    local entity = entity_obj:getEntityById(id)
	local data = derive.pointEntity or {}
    local haveTeam = data.teamId
	local type = data.typePoint or -1
    if not entity:cfg().hideHeadText and value and haveTeam and (type == 3 or type == 4) then
        pointEntity.setTeamPic(entity, derive)
    else
        UI:closeHeadWnd(entity.objID)
    end
end

RETURN(pointEntity)
