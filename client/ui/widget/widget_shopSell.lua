
local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)
local Items = {"gold", "silver", "diamond", "gem", "banknote", "cube"}
local global_setting = require "editor.setting.global_setting"

local nameMapIndex = {
	gold_ingot = 1,
	iron_ingot = 2,
	diamond = 3,
	emerald = 4,
	green_currency = 5,
	gDiamonds = 6
}

function M:init(type)
    if type == "color" then
        self.Items = global_setting:getTeamColorList()
        self.nameMapIndex = {
        }
        for index, key in pairs(self.Items) do
            self.nameMapIndex[key] = index
        end
        self.pullCount = #self.Items
        self.imagesetfmt = "set:setting_global.json image:icon_"
        self.iconSize = {width = 40, height = 40}
    else
        self.Items = {"gold", "silver", "diamond", "gem", "banknote", "cube"}
        self.nameMapIndex = {
            gold_ingot = 1,
            iron_ingot = 2,
            diamond = 3,
            emerald = 4,
            green_currency = 5,
            gDiamonds = 6
        }
        self.pullCount = 6
        self.imagesetfmt = "set:shop_sell.json image:icon_"
    end
    widget_base.init(self, "shopSell_edit.json")
    self.pullfront = 0
    self.extendfront = 0
    self.now = 0

    self.pull = self:child("ShopSell-pull")
    self.pullGrid = self:child("ShopSell-PullGrid")
    self.current = self:child("ShopSell-current")
    self.selectFrom = self:child("ShopSell-current-select")
    self.pullGrid:InitConfig(0, 0, 1)
    self.pullGrid:SethScorllMoveAble(false)

    self:initGrid("pull")

	self:subscribe(self.current, UIEvent.EventWindowTouchDown, function()
		self._mask:SetVisible(true)
        local pullis = self.pull:IsVisible()
		if not pullis then
            self.pull:SetVisible(true)
            self:updateSelect(self.now+1, true)
            self.selectFrom:SetVisible(true)
		elseif pullis then
            self.pull:SetVisible(false)
            self.selectFrom:SetVisible(false)
        end
    end)

end

function M:initGrid(typ)
    local size = 0
    if typ == "pull" then
        size = self.pullCount
    else
        return
    end
    for i=1, size do
        local item = self:getItem(i, typ)
        if (i == 1) and (typ == "pull") then
            item:child("Select"):SetVisible(true)
        end
        if i>1 and i < size then
            item:child("Select"):SetImage("set:shop_sell.json image:bg_drag_mid.png")
        elseif i == size then
            item:child("Select"):SetImage("set:shop_sell.json image:bg_drag_bot.png")
        end
        if typ == "pull" then
            self.pullGrid:AddItem(item, i-1)
        end
    end
    if typ == "pull" then       --add drag
        local bot = self:child("ShopSell-PullBot")
        bot:SetNormalImage("set:shop_sell.json image:bg_drag_drag.png")
        bot:SetPushedImage("set:shop_sell.json image:bg_drag_drag.png")
        local tri = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "PullTri")
        tri:SetArea({0, 0}, {0, 0}, {0, 20}, {0, 13})
        tri:SetVerticalAlignment(1)
	    tri:SetHorizontalAlignment(1)
        tri:SetImage("set:shop_sell.json image:icon_drag_tri.png")
        bot:AddChildWindow(tri)
        self:subscribe(bot, UIEvent.EventButtonClick, function()
            if self.pullGrid:GetVScrollOffset() >= -100 then
                self.pullGrid:AddPosOffset(-30)
            end
        end)
    end
    self.now = 0
end

function M:getSelectImage(index)
    local imageName = self.Items[index]
    if self.Items[index] == "blue" then
        imageName = "bule"
    end
    return self.imagesetfmt .. imageName .. ".png"
end

function M:getItem(index, typ)
    local ret = GUIWindowManager.instance:LoadWindowFromJSON("shopSellItem_edit.json")
    -- 图集打错

    ret:child("Items"):SetImage(self:getSelectImage(index))
    if self.iconSize then
        ret:child("Items"):SetWidth({0, self.iconSize.width})
        ret:child("Items"):SetHeight({0, self.iconSize.height})
    end
    ret:SetArea({0, 0}, {0, 60*(index-1)}, {0, 150}, {0, 60})
    ret:SetName(typ .. self.Items[index])
    self:subscribe(ret, UIEvent.EventWindowClick, function()
        self:updateSelect(index)
    end)
    return ret
end

function M:transformIndex(coinName)
	return self.nameMapIndex[coinName]
end

function M:transformName(index)
	for k, v in pairs(self.nameMapIndex) do
		if v == index then
			return k
		end
	end
end

function M:updateSelect(index, isShow)
	self.selectName = self:transformName(index)
	local backFunc = self.backFunc
	if backFunc then
		backFunc(self.selectName, index)
	end
    if self.pull:IsVisible() then
        self.pullGrid:GetItem(self.pullfront):child("Select"):SetVisible(false)
        self.pullGrid:GetItem(index-1):child("Select"):SetVisible(true)
        self.pullfront = index - 1
    end
    if self.iconSize then
        self:child("ShopSell-items"):SetWidth({0, self.iconSize.width})
        self:child("ShopSell-items"):SetHeight({0, self.iconSize.height})
    end
    self:child("ShopSell-items"):SetImage(self:getSelectImage(index))
    self.now = index - 1
	if not isShow then
        self.pull:SetVisible(false)
        self._mask:SetVisible(false)
        self.selectFrom:SetVisible(false)
	end
end

function M:fillData(params)
	local index = params.index or self:transformIndex(params.coinName)
	self.backFunc = params.backFunc
	self:SetMask(function()
		self.pull:SetVisible(false)
		self._mask:SetVisible(false)
        self.selectFrom:SetVisible(false)
    end)
    self:updateSelect(index)
    self._mask:SetVisible(false)
end

return M