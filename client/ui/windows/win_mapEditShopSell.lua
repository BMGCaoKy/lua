
local Items = {"gold", "silver", "diamond", "gem", "banknote", "cube"}

function M:init()
    WinBase.init(self, "shopSell_edit.json")

    self.pullfront = 0
    self.extendfront = 0
    self.now = 0

    self.pull = self:child("ShopSell-pull")
    self.pullGrid = self:child("ShopSell-PullGrid")
    self.extend = self:child("ShopSell-extend")
    self.extendGrid = self:child("ShopSell-ExtendGrid")
    self.current = self:child("ShopSell-current")

    self.pullGrid:InitConfig(0, 0, 1)
    self.pullGrid:SethScorllMoveAble(false)
    self.pullGrid:SetvScorllMoveAble(false)
    self.extendGrid:InitConfig(0, 0, 1)
    self.extendGrid:SethScorllMoveAble(false)
    self.extendGrid:SetvScorllMoveAble(false)

    self:initGrid("pull")
    self:initGrid("extend")

    self:subscribe(self.current, UIEvent.EventWindowTouchDown, function()
        local pullis = self.pull:IsVisible()
        local extendis = self.extend:IsVisible()
        if (not pullis) and (not extendis) then
            if self.now < 4 then
                self.pull:SetVisible(true)
            else
                self.extend:SetVisible(true)
            end
            self:updateSelect(self.now+1)
            self:child("ShopSell-current-select"):SetVisible(true)
        elseif pullis then
            self.pull:SetVisible(false)
            self:child("ShopSell-current-select"):SetVisible(false)
        else
            self.extend:SetVisible(false)
            self:child("ShopSell-current-select"):SetVisible(false)
        end
    end)

end

function M:initGrid(typ)
    size = 0
    if typ == "pull" then
        size = 4
    elseif typ == "extend" then
        size = 6
    else
        return
    end
    for i=1,size do
        item = self:getItem(i, typ)
        if (i == 1) and (typ == "pull") then
            item:child("Select"):SetVisible(true)
        end
        if i>1 and i<6 then
            item:child("Select"):SetImage("set:shop_sell.json image:bg_drag_mid.png")
        elseif i == 6 then
            item:child("Select"):SetImage("set:shop_sell.json image:bg_drag_bot.png")
        end
        if typ == "pull" then
            self.pullGrid:AddItem(item, i-1)
        else
            self.extendGrid:AddItem(item, i-1)
        end
    end
    if typ == "pull" then       --add drag
        local bot = GUIWindowManager.instance:CreateGUIWindow1("Button", "PullBot")
	    bot:SetArea({0, 0}, {0, 240}, {0, 150}, {0, 40})
	    bot:SetNormalImage("set:shop_sell.json image:bg_drag_drag.png")
        bot:SetPushedImage("set:shop_sell.json image:bg_drag_drag.png")
	    self.pullGrid:AddItem(bot, 4)
        local tri = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "PullTri")
        tri:SetArea({0, 0}, {0, 0}, {0, 20}, {0, 13})
        tri:SetVerticalAlignment(1)
	    tri:SetHorizontalAlignment(1)
        tri:SetImage("set:shop_sell.json image:icon_drag_tri.png")
        bot:AddChildWindow(tri)
        self:subscribe(bot, UIEvent.EventButtonClick, function()
            self.pull:SetVisible(false)
            self.extend:SetVisible(true)
            self:updateSelect(self.now+1)
        end)
    end
    self.now = 0
end

function M:getItem(index, typ)
    local ret = GUIWindowManager.instance:LoadWindowFromJSON("shopSellItem_edit.json")
    ret:child("Items"):SetImage("set:shop_sell.json image:icon_" .. Items[index] .. ".png")
    ret:SetArea({0, 0}, {0, 60*(index-1)}, {0, 150}, {0, 60})
    ret:SetName(typ .. Items[index])
    self:subscribe(ret, UIEvent.EventWindowTouchDown, function()
        self:updateSelect(index)
    end)
    return ret
end

function M:updateSelect(index)
    if self.pull:IsVisible() then
        self.pullGrid:GetItem(self.pullfront):child("Select"):SetVisible(false)
        self.pullGrid:GetItem(index-1):child("Select"):SetVisible(true)
        self.pullfront = index - 1
    elseif self.extend:IsVisible() then
        self.extendGrid:GetItem(self.extendfront):child("Select"):SetVisible(false)
        self.extendGrid:GetItem(index-1):child("Select"):SetVisible(true)
        self.extendfront = index - 1
    end
    self:child("ShopSell-items"):SetImage("set:shop_sell.json image:icon_" .. Items[index] .. ".png")
    self.now = index - 1
end

function M:onOpen()

end

function M:onClose()

end

return M