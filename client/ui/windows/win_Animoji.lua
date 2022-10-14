local function getActionList()
    local actions = Me:data("animoji") or {}
    local actionPriceList = Me:data("actionPriceList") or {}
    if #actionPriceList == 0 then
        for actionId = 1, 26 do
            table.insert(actionPriceList, {
                actionId = tostring(actionId),
                price = 0,
                currency = 0,
                buyId = 0,
            })
        end
    end
    local actionList = {}
    for actionId, _ in pairs(actions) do
        table.insert(actionList, {
            actionId = actionId,
            price = 0,
            currency = 0,
            buyId = 0,
        })
    end
    for _, actionPrice in pairs(actionPriceList) do
        if not actions[tostring(actionPrice.actionId)] then
            table.insert(actionList, actionPrice)
        end
    end
    table.sort(actionList, function(a, b)
        return tonumber(a.actionId) < tonumber(b.actionId)
    end)

    return actionList
end

function M:init()
    WinBase.init(self, "actionTable.json", true)

    self:child("actionTable-mask"):setMask(1, 1, 0.5)
    self.gridView = self:child("actionTable-gridView")
    self.gridView:InitConfig(5, 5, 4)
    self.actions = Me:data("animoji")

    local actionList = getActionList()
    self.itemList = {}
    for _, actionItem in pairs(actionList) do
        self.itemList[actionItem.actionId] = self:createItem(actionItem.actionId)
    end

    Lib.subscribeEvent(Event.EVENT_UPDATE_ANIMOJI, function()
        self:updateItem()
    end)
end

function M:onOpen()
    self:updateItem()
end

function M:createItem(actionId)
    local item = GUIWindowManager.instance:LoadWindowFromJSON("actionItem.json")
    item:child("actionItem-clock"):SetImage("set:selectable_action_img.json image:action_img_0")
    item:child("actionItem-actionImg"):SetImage("set:selectable_action_img.json image:action_img_" .. actionId)
    self:subscribe(item, UIEvent.EventWindowClick, function()
        if Me.isMoving then
            return
        end

        self.actions = Me:data("animoji")
        if not self.actions[tostring(actionId)] then
            self:buyAction(actionId)
            return
        end

        Lib.emitEvent(Event.EVENT_ANIMOJI_CLICK, actionId)
        UI:closeWnd("Animoji")
        Me:sendPacket({
            pid = "PlayAnimoji",
            actionId = actionId
        })
    end)
    self.gridView:AddItem(item)
    item:child("actionItem-clock"):SetVisible(not self.actions[tostring(actionId)])
    return item
end

function M:buyAction(actionId)
    local actionPriceList = Me:data("actionPriceList") or {}
    local actionPrice
    for _, itemPrice in pairs(actionPriceList) do
        if itemPrice.actionId == actionId then
            actionPrice = itemPrice
        end
    end
    if not actionPrice then
        Lib.logError(string.format("Error: actionPriceList[%d] == nil!!", actionId))
        return
    end
    if actionPrice.currency == 1 then
        local buyId = actionPrice.buyId or 0
        local wnd = UI:openWnd("onlineConsumeRemind")
        wnd:setCallBack(function()
            print("Player buy action:", Me.platformUserId, actionId, buyId)
            CGame.instance:getShellInterface():buyAction(buyId)
        end)
        wnd:setPrice(actionPrice.price or 1)
    end
end

function M:updateItem()
    self.actions = Me:data("animoji")
    for actionId, item in pairs(self.itemList) do
        item:child("actionItem-clock"):SetVisible(not self.actions[tostring(actionId)])
    end
end

return M