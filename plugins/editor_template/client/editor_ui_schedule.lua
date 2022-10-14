local setting = require "common.setting"

Lib.subscribeEvent(Event.EVENT_GAME_RESULT, function (packet)
    local uiType = packet.result and packet.result.uiType or "Default"
    --UI:openSystemWindowAsync(function(window) end,"GameResultRank", "gameResultType" .. uiType, packet, uiType)
    UI:openSystemWindow("GameResultRank", "gameResultType" .. uiType, packet, uiType)
end)

local maxCount = 4
local imc = 0.07
local bm = Blockman.Instance()
Lib.subscribeEvent(Event.BEGIN_SPRINT, function(forward, left)
    if not Me.BeginMoveSprintFOVTimerCount then
        Me.BeginMoveSprintFOVTimerCount = 0
    end
    if forward ~= 1 then
        return
    end
    if Me.EndMoveSprintFOVTimer then
        Me.EndMoveSprintFOVTimer()
        Me.EndMoveSprintFOVTimer = nil
    end 
    local bmGameSettings = bm.gameSettings
    local count = Me.BeginMoveSprintFOVTimerCount >= 0 and Me.BeginMoveSprintFOVTimerCount or 0
    Me.BeginMoveSprintFOVTimer = World.Timer(1, function()
        count = count + 1
        Me.BeginMoveSprintFOVTimerCount = count
        bmGameSettings:setFovSetting(bmGameSettings:getFovSetting() - imc)
        if count >= maxCount then
            return false
        end
        return true
    end)
end)

Lib.subscribeEvent(Event.END_SPRINT, function(forward, left)
    if not Me.BeginMoveSprintFOVTimerCount or Me.BeginMoveSprintFOVTimerCount <= 0 then
        return
    end
    if Me.BeginMoveSprintFOVTimer then
        Me.BeginMoveSprintFOVTimer()
        Me.BeginMoveSprintFOVTimer = nil
    end 
    local bmGameSettings = bm.gameSettings
    Me.EndMoveSprintFOVTimer = World.Timer(1, function()
        Me.BeginMoveSprintFOVTimerCount = Me.BeginMoveSprintFOVTimerCount - 1
        bmGameSettings:setFovSetting(bmGameSettings:getFovSetting() + (Me.BeginMoveSprintFOVTimerCount >= 0 and imc or 0))
        if Me.BeginMoveSprintFOVTimerCount <= 0 then
            return false
        end
        return true
    end)
    -- bm.gameSettings:setFovSetting(bm.gameSettings:getFovSetting() + Me.BeginMoveSprintFOVTimerCount * imc)
    -- Me.BeginMoveSprintFOVTimerCount = 0
    
end)

local function resetCell()
    local bagUI = UI:getWnd("bag")
    local unlimitUI = UI:getWnd("unlimitedResources")
    local mainUI = UI:getWnd("main")
    unlimitUI:selectedCell()
    bagUI:resetSelectedCell()
    mainUI:setSelectCell()
    mainUI:setSelectSlot()
end 

local function fetchCell()
    return UIMgr:new_widget("cell","widget_cell_2.json","widget_cell_2")
end

local function swapCell(cell1, data1, cell2, data2)
    local pos1 = cell1 and cell1:GetRenderArea() or data1
    local pos2 = cell2 and cell2:GetRenderArea() or data2
    
    local uimove = UI:openWnd("uimove")
    if cell1 and data1 then
        uimove:douiTweenByName(data1, pos1, {X = {0, pos2[1]}, Y = {0, pos2[2]} })
    end
    if cell2 and data2 then
        uimove:douiTweenByName(data2, pos2, {X = {0, pos1[1]}, Y = {0, pos1[2]} })
    end
end

local function getItemData(item)
    if not item or item:null() then
        return
    end
    local type, name = "item", item:full_name()
    if item:is_block() then
        type = "block"
        name = setting:id2name("block", item:block_id())
    end
    return {type = type, name = name}
end

local function doSwapHandBag(origin)
    local bagUI = UI:getWnd("bag")
    local unlimitUI = UI:getWnd("unlimitedResources")
    local mainUI = UI:getWnd("main")
    if not origin or origin == "nulimit" or origin == "nulimitGrive" or not UI:isOpen("appMainRole") then
        return
    end
    local mainCell = mainUI._select_cell
    local bagCell = bagUI._selectedCell
    local handSlot = mainUI:getSelectSlot()
    if not handSlot or not bagCell then
        return
    end
    local desTrays = Me:tray():query_trays(Define.TRAY_TYPE.HAND_BAG)[1]
    local handTid = desTrays.tid
    local desTray = desTrays.tray

    local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)
    local bagTid, bag = trayArray[1].tid,  trayArray[1].tray

    local bagSlot = bagCell:data("slot")
    local bagSloter = bagCell:data("sloter")
    local handSloter = desTray:fetch_item_generator(handSlot)
    if not bagSlot and not handSloter and not handSloter:null() then
        return
    end

    swapCell(bagCell, getItemData(bagSloter), mainCell, getItemData(handSloter))
    resetCell()
    Me:combineItem(handTid,  handSlot, bagTid, bagSlot)
    UI:closeWnd("popups_property")
end

local function doSwapBagUnmilit(origin, dx, dy)
    local bagUI = UI:getWnd("bag")
    local unlimitUI = UI:getWnd("unlimitedResources")
    local mainUI = UI:getWnd("main")
    if not origin or origin == "main" then
        return
    end
    local bagCell = bagUI._selectedCell
    local unCell = unlimitUI:getSelectedCell()
    if not bagCell or (origin ~= "nulimitGrive" and not unCell) then
        return
    end
    local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)
    local bagTid, bag = trayArray[1].tid,  trayArray[1].tray
    local ret = false
    local bagItem = bagCell:data("sloter")
    local bagSlot = bagCell:data("slot")
    local unItem = unCell and unCell:data("item")
    local data1 = getItemData(unItem)
    local data2 = getItemData(bagItem)
    if origin == "bag" and unItem then --资源库到背包
        Me:sendPacket({
            pid = "AddUnmilitRes",
            name = data1.name,
            type = data1.type,
            targetTid = bagTid,
            targetSlot = bagSlot
        })

        swapCell(unCell, data1, bagCell, data2)
        resetCell()
        return true
    end
    if not bagSlot or not bagItem then
        bagUI:resetSelectedCell()
        return
    end
    if origin == "nulimit" or origin == "nulimitGrive" then --背包到资源库直接删除item
        Me:sendPacket({ 
            pid = "DeleteItem", 
            objID = Me.objID,
            bag = bagTid,
            slot =  bagSlot
        })

        swapCell(bagCell, data2, unCell, {dx, dy})
        resetCell()
        return true
    end
end

local function doSwapHandUmilit(origin, dx, dy)
    local bagUI = UI:getWnd("bag")
    local unlimitUI = UI:getWnd("unlimitedResources")
    local mainUI = UI:getWnd("main")
    if not origin or origin == "bag" then
        return
    end
    local handCell = mainUI:getSelectCell()
    local handSlot = mainUI:getSelectSlot()
    local unCell = unlimitUI:getSelectedCell()
    if not handSlot or (origin ~= "nulimitGrive" and not unCell)  then
        return
    end
    local desTrays = Me:tray():query_trays(Define.TRAY_TYPE.HAND_BAG)[1]
    local handTid = desTrays.tid
    local ret = false
    local unItem = unCell and unCell:data("item")
    local handItem = handCell and handCell:data("item")
    local data1 = getItemData(unItem)
    local data2 = getItemData(handItem)
    if origin == "main" and unItem then --资源库到快捷栏
        Me:sendPacket({
            pid = "AddUnmilitRes",
            name = data1.name,
            type = data1.type,
            targetTid = handTid,
            targetSlot = handSlot
        })

        swapCell(unCell, data1, handCell, data2)
        resetCell()
        return true
    end
    if origin == "nulimit" or origin == "nulimitGrive" then --快捷栏到资源库直接删除item
        Me:sendPacket({ 
            pid = "DeleteItem", 
            objID = Me.objID,
            bag = handTid,
            slot =  handSlot
        })
        swapCell(handCell, data2, unCell, {dx, dy})
        resetCell()
        ret = true
    end
    return ret
end

local uiExist = {}
do
    for _, data in pairs(World.cfg.bagMainUi or {}) do
        uiExist[data.openWindow] = true
    end
end

Lib.subscribeEvent(Event.CHECK_SWAP, function(origin, dx, dy)
    if not UI:isOpen("appMainRole") then
        return
    end
    doSwapHandBag(origin, dx, dy)
    if uiExist["unlimitedResources"] then
        doSwapBagUnmilit(origin, dx, dy)
    end
    if uiExist["unlimitedResources"] then
        doSwapHandUmilit(origin, dx, dy)
    end
end)