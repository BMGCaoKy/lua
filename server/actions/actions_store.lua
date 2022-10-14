local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions

function Actions.GetStoreById(data, params, context)
    local store = Store:getStoreById(params.storeId)
    return store.items
end

function Actions.GetStoreItem(data, params, context)
    local item = Store:getStoreItem(params.storeId, params.index)
    return item
end

function Actions.GetStoreItemName(data, params, context)
    local item = Store:getStoreItem(params.storeId, params.index)
    return item.itemName
end

function Actions.ChangeStoreItemStatus(data, params, context)
    local key = tostring(Bitwise64.Or(Bitwise64.Sl(params.storeId, 16), params.index))
    params.player:data("store")[key] = params.status
end

function Actions.SyncStore(data, params, context)
    params.player:syncStore()
end

function Actions.StoreOperation(data, params, context)
    local entity = params.entity
    if not entity or not entity.isPlayer then
        return
    end
    Store:operation(entity, params.storeId, params.itemIndex, params.targetIndex)
end

function Actions.GetStoreItemStatus(data, params, context)
    return params.player:getStoreItemStatus(params.storeId, params.index)
end

function Actions.ChangeStoreItemRemainTime(data, params, context)
    local item = Store:getStoreItem(params.storeId, params.index)
    local key = tostring(Bitwise64.Or(Bitwise64.Sl(params.storeId, 16), params.index))
    local status = item.status
    if params.remainTime <= 0 then
        params.player:data("store")[key] = item.status
    else
        status = params.player:getStoreItemStatus(params.storeId, params.index)
        if status ~= Store.itemStatus.IN_USE then
            params.player:data("store")[key] = Store.itemStatus.NOT_USE
            status = Store.itemStatus.NOT_USE
        end
    end
    params.player:syncStoreItemInfo(params.storeId, params.index, status, params.remainTime)
end

function Actions.SyncStoreItemStatus(data, params, context)
    local key = tostring(Bitwise64.Or(Bitwise64.Sl(params.storeId, 16), params.index))
    params.player:data("store")[key] = params.status
    params.player:syncStoreItemInfo(params.storeId, params.index, params.status)
end