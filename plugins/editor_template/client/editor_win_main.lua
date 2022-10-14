
local M = UI:getWnd("main")
if not M then
    return
end

local bag = M:child("Main-ToggleInventoryButton")
bag:SetProperty("SoundName", "70")
M:unsubscribe(bag)
M:subscribe(bag, UIEvent.EventButtonClick, function()
    Lib.emitEvent(Event.EVENT_MAIN_ROLE, true)
end)

Lib.subscribeEvent(Event.EVENT_HAND_ITEM_CHANGE, function(item)
    UI:closeWnd("itemDetail")
    if item then
        UI:openWnd("itemDetail", item)
    end
end)

local function onClick(cell, isClick)
    local image = cell:child("widget_cell-img_frame")
	image:SetImage(isClick and "set:bottom_bar.json image:bar_item_sel.png" or "set:bottom_bar.json image:bar_item_nor.png")
    image:SetYPosition(isClick and {0, -9} or {0, -3})
    cell:child("widget_cell-Light"):SetVisible(isClick)
end

function M:setSelectSlot(slot)
    self.selectSlot = slot
end

function M:getSelectSlot()
    return self.selectSlot
end

function M:getSelectCell()
    return self._select_cell
end

function M:setSelectCell(cell)
    if self._select_cell then
        onClick(self._select_cell, false)
    end
    self._select_cell = cell
    if cell then
        onClick(cell, true)
    end
end

function M:reloadItemBar()
    local cap = World.cfg.handBagCap or 9
    self.gridview:RemoveAllItems()
    self.gridview:InitConfig(5, 0, cap)
    self.gridview:HasItemHidden(false)
    self.gridview:SetMoveAble(false)
    for slot = 1, cap do
        local cell = UIMgr:new_widget("cell", "widget_cell_bar.json")
        cell:invoke("UPDATE_NEED_RESET_ITEM_SIZE", false)
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            local item = cell:data("item")
            UI:closeWnd("itemDetail")
            if item then
                UI:openWnd("itemDetail", item)
            end
            if item and item:cfg().fastUse then
                Skill.Cast("/useitem", {slot = item:slot(), tid = item:tid()})
            else
                Me:setHandItem(item)
                self:setSelectCell(cell)
                self.selectSlot = slot
                Lib.emitEvent(Event.CHECK_SWAP, "main")
            end
        end)
        cell:setEnableLongTouchRecursivly(true)
        self:subscribe(cell, UIEvent.EventWindowLongTouchStart, function()
            cell:setData("abandonTimer",  World.Timer(World.cfg.abandonTouchTime or 8, function()
                local item = cell:data("item")
                local canAbandon = item and item:cfg().canAbandon
                if item and item:is_block() then
                    canAbandon = item:block_cfg().canAbandon
                end
                if item and not item:null() and (canAbandon or World.cfg.allCanAbandon) then
                    Me:sendPacket({pid = "AbandonItem", tid = item:tid(), slot = item:slot()})
                end
            end))
        end)
        self:subscribe(cell, UIEvent.EventWindowLongTouchEnd, function()
            local stopTimer = cell:data("abandonTimer")
            if stopTimer then
                stopTimer()
            end
        end)
        self.itemCdMaskArr[slot] = {cell = cell, lastCdEndTick = 0}
        self.gridview:AddItem(cell)
    end
end