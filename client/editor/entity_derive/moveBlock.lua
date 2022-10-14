local moveBlock = L("moveBlock", {})
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local state = require "editor.state"
local data_state = require "editor.dataState"
local Timer

local function setAiRoute(entity_obj, entityId, derive)
	if not derive or not derive.tmpAiData then
		return
	end
	local route = derive.tmpAiData.route
	if #route <= 1 then
		route = nil
	end
	entity_obj:deriveSetData(entityId, "aiData", {
		route = route 
	})
	local tmpAiData =  derive.tmpAiData
	if tmpAiData and tmpAiData.route and #tmpAiData.route <= 1 then
		tmpAiData.route = nil
	end
	entity_obj:deriveSetData(entityId, "tmpAiData", derive.tmpAiData)
end

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
    if Clientsetting.isKeyGuide("isNewAcc") then
        Lib.emitEvent(Event.EVENT_NOVICE_GUIDE, 4)
        Lib.emitEvent(Event.EVENT_EDIT_OPEN_GUIDE_WND, 2)
    end
    
end

function moveBlock.add(entity_obj, id, derive, pos, _table)
    local entity = entity_obj:getEntityById(id)
    local moveBlockSize = _table.moveBlockSize
    local newPos = pos
    local data = {pos = newPos}
    entity_obj:setPosById(id, data)

    local blockId = _table.blockId
    local data = {
        xSize = moveBlockSize[1],
        ySize = moveBlockSize[2],
        zSize = moveBlockSize[3],
        blockId = blockId
    }
    derive.fillBlock = data
    entity:SetEntityToBlock(data)
    setting(entity_obj, id)
end

function moveBlock.click(entity_obj, id)
	setting(entity_obj, id)
end

function moveBlock.set(entity_obj, id, key, value)
    local derive_obj = entity_obj:getDataById(id)
    derive_obj[key] = value
end

function moveBlock.load(entity_obj, id, pos)
    local derive = entity_obj:getDataById(id)
    local entity = entity_obj:getEntityById(id)
    entity:SetEntityToBlock(derive.fillBlock)
end

function moveBlock.setRotation(entity_obj, id, derive)
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

function moveBlock.setPos(entity_obj, id, derive, data)
    local route = derive.aiData and derive.aiData.route
    if route and #route > 0 then
        route[1] = data.pos
    end
end

function moveBlock.getType()
    return "moveBlock"
end

function moveBlock.getBrushObj(entity_obj, id, derive, cfg)
    local entity = entity_obj:getEntityById(id)
    local data = derive.fillBlock
    return {
        cfg = cfg,
        moveBlockSize = {
            data.xSize,
            data.ySize,
            data.zSize
        },
        blockId = data.blockId
    }
end

function moveBlock.changeEntity(entity_obj, id, derive, cfg)
    local blockID = Block.GetNameCfgId(cfg)
    local blockInfo = derive.fillBlock
    local entity = entity_obj:getEntityById(id)
    blockInfo.blockId = blockID
    entity:SetEntityToBlock(blockInfo)
    setting(entity_obj, id)
end

function moveBlock.replaceTable(entity_obj, id, derive, obj)
    local replaceObj = (obj and obj.dropItem) or (obj and #obj > 0 and obj or nil)
	derive.dropItem = replaceObj
	setAiRoute(entity_obj, id, obj)
end

RETURN(moveBlock)
