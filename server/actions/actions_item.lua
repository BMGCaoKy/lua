local setting = require "common.setting"
local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"

function Actions.GetItemClass(data, params, context)
    local item_class = Item.CreateItem(params.item)
    return item_class
end

function Actions.GetItemCfgByItemClass(data, params, context)
    local item = params.item
    if not item or item:null() then
        return false

    end
    local cfg = params.item:cfg()
    if cfg and params.key then
        cfg = cfg[params.key]
    end
    return cfg
end

function Actions.GetItemCfg(data, params, context)
    local cfg = setting:fetch("item", params.fullName)
    if cfg and params.key then
        cfg = cfg[params.key]
    end
    return cfg
end

function Actions.GetItemUseBuffCfg(data, params, context)
    local cfg = setting:fetch("item", params.fullName)
    if not cfg then
        return nil
    end
    local useBuff = cfg.useBuff
    if useBuff and params.key then
        useBuff = useBuff[params.key]
    end
    return useBuff
end

function Actions.GetDropItemInitPos(data, params, context)
    return params.dropItem.iniPos
end

function Actions.GetDropItemInitMap(data, params, context)
    return params.dropItem.iniMap
end

function Actions.CreateDropItem(data, params, context)
    local function doCreate(params)
        local item = Item.CreateItem(params.item, params.count or 1)
        local map = params.map or params.entity and params.entity.map
        if map then 
            DropItemServer.Create({
                map = map, pos = params.pos, item = item, lifeTime = item:cfg().droplifetime
            })
        end
    end
    if params.delay then 
        World.Timer(params.delay, doCreate, params)
    else
        doCreate(params)
    end
end

function Actions.CreateDropBlock(data, params, context)
    local item = Item.CreateItem("/block", params.count or 1, function(dropItem)
        if params.blockName then
            dropItem:set_block(params.blockName)
        else
            dropItem:set_block_id(params.blockId)
        end
    end)
    local map = params.map or params.entity and params.entity.map
    DropItemServer.Create({
        map = map, pos = params.pos, item = item, lifeTime = item:cfg().droplifetime
    })
end

function Actions.CreateRandomDropItemsInRegion(data, params, context)
    local map = World.CurWorld:getMap(params.map)
    local posCount = math.random(params.minCount, params.maxCount)
    local posArray = map:getRandomPosInRegion(posCount, not params.isIncludeCollision, params.regionKey, params.region)
    if not next(posArray) then
        return
    end
    local lifeTime = params.lifeTime or params.time
    for i = 1, posCount do
        local blockPos = posArray[i % #posArray + 1]
        local pos = Lib.v3(0.5, 0.1, 0.5) + blockPos --line up with the block
        local item = Item.CreateItem(params.fullName, 1)
        DropItemServer.Create({
            map = map, pos = pos, item = item, lifeTime = lifeTime, pitch = params.pitch, yaw = params.yaw
        })
    end
end

function Actions.SpawnItemToWorld(node, params, context)
    local itemCfg = params.fullName
    if ActionsLib.isEmptyString(itemCfg, "Item") or ActionsLib.isInvalidMap(params.map) then
        return
    end
    local count = params.count or 1
    count = (count > 0) and count or 1
    local item
    if params.createType == "block" then
        item = Item.CreateItem("/block", count, function(dropItem)
            dropItem:set_block(itemCfg)
        end)
    else
        item = Item.CreateItem(itemCfg, count)
    end
    local moveDistance = params.moveDistance or {x = 0, y = 0, z = 0}
    local moveTime = params.moveTime or 1
    local moveSpeed = {
        x = moveDistance.x / moveTime,
        y = moveDistance.y / moveTime,
        z = moveDistance.z / moveTime
    }
    local pos = params.pos or {x = 0, y = 0, z = 0}
    local targetPos = Lib.v3add(pos, moveDistance)
    local dropItem = DropItemServer.Create({
        map = params.map,
        pos = targetPos,
        item = item,
        lifeTime = params.time,
        pitch = params.pitch,
        yaw = params.yaw,
        moveSpeed = moveSpeed,
        moveTime = moveTime,
        guardTime = params.guardTime
    })
    if params.from and item:cfg().dropOwn then
        dropItem:setData("ownerId", params.from.objID)
    end
    if params.dropItemType then
        dropItem.dropItemType = params.dropItemType
        dropItem.fromId = params.from.objID
    end
    return dropItem
end

function Actions.SetItemVar(data, params, context)
    local item = params.item
    local entity = params.entity
    if not item or not entity then
        return
    end
    local tray_item = Item.CreateSlotItem(entity, item:tid(), item:slot())
    if not tray_item:null() then
        tray_item:set_var(params.key, params.value)
    end
end

function Actions.GetItemVar(data, params, context)
    local item = params.item
    if not item then
        return
    end
    local ret = item:getVar(params.key)
    if ret then
        return ret
    end
end

function Actions.RemoveItemByFullName(data, params, context)
    local tray = params.entity:tray():fetch_tray(params.tid)
    if tray then 
        tray:remove_item_by_fullname(params.fullName)
    end
end

function Actions.GetItemTid(data, params, context)
	local item = params.item
	if not item or item:null() then
		return
	end
	return item:tid()
end

function Actions.GetItemSlot(data, params, context)
	local item = params.item
	if not item or item:null() then
		return
	end
	return item:slot()
end

function Actions.GetItemByEntityTray(data, params, context)
    if not params.entity or not params.tid or not params.slot then
        return nil
    end
    return Item.CreateSlotItem(params.entity, params.tid, params.slot)
end