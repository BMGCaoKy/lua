local resPoint = L("resPoint", {})
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local state = require "editor.state"
local data_state = require "editor.dataState"
local globalSetting = require "editor.setting.global_setting"
local Timer

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

function resPoint.add(entity_obj, id, derive, pos, _table)
    local entity = entity_obj:getEntityById(id)
    local data = {
		delayProductTime = 200,
		maxLevel = 1,
		levelInfos = {
			{speed = 500, upLevelTime = 10}
		},
		autoUpLevel = false
    }
    derive.resourcePoint = data
    --setting(entity_obj, id)
end

function resPoint.click(entity_obj, id)
	setting(entity_obj, id)
end

function resPoint.set(entity_obj, id, key, value)
    local derive_obj = entity_obj:getDataById(id)
    derive_obj[key] = value
end

function resPoint.load(entity_obj, id, pos)
    -- local derive = entity_obj:getDataById(id)
    -- local entity = entity_obj:getEntityById(id)
    -- entity:SetEntityToBlock(derive.fillBlock)
    local derive = entity_obj:getDataById(id)
    resPoint.cehckTeamCorrelation(entity_obj, id, derive)
    resPoint.showTeamPic(entity_obj, id, derive, true)
end

function resPoint.del(entity_obj, id)
    local entity = entity_obj:getEntityById(id)
	SceneUIManager.RemoveEntityHeadUI(entity.objID)
end

function resPoint.setRotation(entity_obj, id, derive)
    if not derive or not derive.fillBlock then
        return
    end
    local entity = entity_obj:getEntityById(id)
    entity:clearBlock()
    local data = derive.fillBlock 
    derive.fillBlock = {
        xSize = data.zSize,
        zSize = data.xSize,
        ySize = data.ySize,
        blockId = data.blockId
    }
    entity:SetEntityToBlock(derive.fillBlock)
end

function resPoint.getType()
    return "resPoint"
end

function resPoint.changeEntity(entity_obj, id, derive, cfg)
    -- local blockID = Block.GetNameCfgId(cfg)
    -- local blockInfo = derive.fillBlock
    -- local entity = entity_obj:getEntityById(id)
    -- blockInfo.blockId = blockID
    -- entity:SetEntityToBlock(blockInfo)
    -- setting(entity_obj, id)
end

function resPoint.replaceTable(entity_obj, id, derive, obj)
    local replaceObj = (obj and obj.dropItem) or (obj and #obj > 0 and obj or nil)
	derive.dropItem = replaceObj
end

function resPoint.getCurrentyType(entity_obj, id, derive)
	return derive.resourcePoint.coinFullName
end

function resPoint.setCurrentyType(entity_obj, id, derive, fullName)
	derive.resourcePoint.coinFullName = fullName
end

function resPoint.setResPointItemType(entity_obj, id, derive, type)
    derive.resourcePoint.itemType = type
end

function resPoint.getResPointItemType(entity_obj, id, derive)
    return derive.resourcePoint.itemType
end

function resPoint.getCurrentyIcon(entity_obj, id, derive)
	return derive.resourcePoint.itemIcon
end

function resPoint.setCurrentyIcon(entity_obj, id, derive, icon)
	derive.resourcePoint.itemIcon = icon
end

function resPoint.getStartTime(entity_obj, id, derive)
	return derive.resourcePoint.delayProductTime
end

function resPoint.setStartTime(entity_obj, id, derive, value)
	derive.resourcePoint.delayProductTime = value
end

function resPoint.getInitSpeed(entity_obj, id, derive)
	return derive.resourcePoint.levelInfos[1].speed
end

function resPoint.setProductNumMax(entity_obj, id, derive, value)
    for _, data in pairs(derive.resourcePoint.levelInfos or {}) do
        data.productNumMax = value
    end
	-- derive.resourcePoint.levelInfos[1].productNumMax = value
end

function resPoint.getProductNumMaxSwitch(entity_obj, id, derive)
	return derive.resourcePoint.levelInfos[1].productNumMaxSwitch
end

function resPoint.setProductNumMaxSwitch(entity_obj, id, derive, value)
    for _, data in pairs(derive.resourcePoint.levelInfos or {}) do
        data.productNumMaxSwitch = value
    end
	-- derive.resourcePoint.levelInfos[1].productNumMaxSwitch = value
end

function resPoint.getProductNumMax(entity_obj, id, derive)
	return derive.resourcePoint.levelInfos[1].productNumMax
end

function resPoint.setInitSpeed(entity_obj, id, derive, value)
	derive.resourcePoint.levelInfos[1].speed = value
end

function resPoint.getAutoLevel(entity_obj, id, derive, value)
	return derive.resourcePoint.autoUpLevel
end

function resPoint.setAutoLevel(entity_obj, id, derive, value)
	derive.resourcePoint.autoUpLevel = value
end

function resPoint.getMaxLevel(entity_obj, id, derive, value)
	return derive.resourcePoint.maxLevel
end

function resPoint.setMaxLevel(entity_obj, id, derive, value)
	derive.resourcePoint.maxLevel = value
end

function resPoint.getLevelList(entity_obj, id, derive, value)
	return derive.resourcePoint.levelInfos
end

function resPoint.setLevelList(entity_obj, id, derive, value)
	derive.resourcePoint.levelInfos = value
	derive.resourcePoint.maxLevel =  #value
end

function resPoint.setTeamID(entity_obj, id, derive, value)
	derive.resourcePoint.teamID = value
end

function resPoint.getTeamID(entity_obj, id, derive, value)
	return derive.resourcePoint.teamID
end

function resPoint.cehckTeamCorrelation(entity_obj, id, derive)
    local team = globalSetting:getTeamMsg() or {}
    local  resourcePoint = derive.resourcePoint
    local teamID = resourcePoint and resourcePoint.teamID
    local newID = team[teamID] and teamID or nil
    if not (newID and newID == teamID) then
        resPoint.setTeamID(entity_obj, id, derive, newID)
    end
    resPoint.setTeamPic(entity_obj, id, derive, newID)
    resPoint.showTeamPic(entity_obj, id, derive, newID)
end

function resPoint.openSettingUI(entity_obj, id, derive)
	UI:openMultiInstanceWnd("mapEditTabSetting", {
			labelName = {
			{
				leftName = "editor.ui.setCurrency",
				wndName = "CurrentySetting"
            },
            {
                leftName = "editor.ui.autoUpgrade",
                wndName = "CurrentyAutoUpLevel"
            }
		},
		data = id
	})
end

function resPoint.setTeamPic(entity_obj, id, derive, value)
    if not value then
        derive.teamPic = nil
        return
    end
    local team = globalSetting:getTeamMsg() or {}
    local color = team[value] and team[value].color
    local icons = {
        ["BLUE"] = "image/icon/team_blue.png",
        ["RED"] = "image/icon/team_red.png",
        ["YELLOW"] = "image/icon/team_yellow.png",
        ["GREEN"] = "image/icon/team_green.png",
    }
    if not color then
        derive.teamPic = nil
        return
    end
    local icon = icons[color]
    derive.teamPic = icon
end


local function setHeadText(entity, derive)
    local picPath = derive.teamPic
    if not picPath then
        picPath = "image/icon/bubbling.png"
    end
	entity:showHeadPic(picPath)
end

function resPoint.showTeamPic(entity_obj, id, derive, value)
    local entity = entity_obj:getEntityById(id)
    local haveTeam = derive.resourcePoint.teamID
    if not entity:cfg().hideHeadText and derive.teamPic and value and haveTeam then
        setHeadText(entity, derive)
    else
        UI:closeHeadWnd(entity.objID)
    end
end

RETURN(resPoint)
